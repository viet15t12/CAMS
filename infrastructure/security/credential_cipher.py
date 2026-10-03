"""Symmetric authenticated encryption for device credentials stored in SQLite.

Implements Mechanism 2 (Project Passphrase / Workspace Key Encryption):
- Cipher: AES-256-GCM (NIST SP 800-38D) with 12-byte cryptographically secure random Nonce/IV and 16-byte Auth Tag.
- Key Derivation:
  * Argon2id (RFC 9106) when project passphrase is provided (e.g. protected .ntp package).
  * HKDF-SHA256 (RFC 5869) when running in open / unprotected project mode.
- Envelope format in DB: ENC$v1$<base64(nonce + ciphertext + auth_tag)>
- Transparent backward compatibility: Plaintext passwords without ENC$v1$ prefix are preserved and returned as-is.
- Multi-key fallback: Automatically handles subprocess boundaries (e.g. interactive_ssh, workers) by resolving keys from environment, session marker files, and manifest.json.
- Tamper detection: InvalidTag raises an error if ciphertext or tag is modified.
"""

from __future__ import annotations

import base64
import hashlib
import json
import os
import secrets
import sqlite3
import threading
from pathlib import Path
from typing import Any, Iterable

from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.argon2 import Argon2id
from cryptography.hazmat.primitives.kdf.hkdf import HKDF

PREFIX_V2 = "ENC$v2$"
PREFIX_V1 = "ENC$v1$"
PREFIX = PREFIX_V2
NONCE_SIZE = 12
TAG_SIZE = 16
MIN_PAYLOAD_SIZE = NONCE_SIZE + TAG_SIZE
LEGACY_ASSOCIATED_DATA = b"CAMS_DEVICE_CREDENTIAL_V1"
ASSOCIATED_DATA = LEGACY_ASSOCIATED_DATA
DEFAULT_SALT = b"CAMS_DEFAULT_PROJECT_CREDENTIAL_SALT_V1"
ENV_CREDENTIAL_KEY = "CAMS_CREDENTIAL_KEY"
TRANSIENT_KEY_FILE = ".credential_key"


def make_aad(context: str = "") -> bytes:
    """Generate Associated Authenticated Data (AAD) for AES-GCM record-binding."""
    if context:
        return f"CAMS_CRED_V2:{context}".encode("utf-8")
    return b"CAMS_DEVICE_CREDENTIAL_V2"


def _zero_memory(target: bytearray) -> None:
    """Overwrite sensitive byte arrays in memory with zeros."""
    for i in range(len(target)):
        target[i] = 0


def _derive_default_key() -> bytes:
    """Generate deterministic fallback key when no session/passphrase is configured."""
    hkdf = HKDF(
        algorithm=hashes.SHA256(),
        length=32,
        salt=DEFAULT_SALT,
        info=b"cams-default-credential-key",
    )
    return hkdf.derive(b"cams_default_key_seed")


class CredentialCipher:
    """AES-256-GCM authenticated cipher for device passwords."""

    def __init__(
        self,
        key: bytes | bytearray | None = None,
        fallback_keys: Iterable[bytes | bytearray] | None = None,
    ) -> None:
        if key is None:
            key = _derive_default_key()
        self._key = bytearray(key)
        self._fallback_keys: list[bytearray] = [
            bytearray(k) for k in (fallback_keys or ()) if k and bytes(k) != bytes(self._key)
        ]
        self._lock = threading.RLock()

    def add_fallback_key(self, key: bytes | bytearray | None) -> None:
        """Register a candidate key to try if primary decryption fails."""
        if not key or len(key) != 32:
            return
        with self._lock:
            key_bytes = bytes(key)
            if key_bytes != bytes(self._key) and not any(bytes(k) == key_bytes for k in self._fallback_keys):
                self._fallback_keys.append(bytearray(key))

    @classmethod
    def derive_from_passphrase(
        cls, passphrase: str, project_id: str = "", salt: bytes | None = None
    ) -> "CredentialCipher":
        """Derive a 256-bit AES key from the user-provided workspace passphrase using Argon2id (RFC 9106)."""
        if not passphrase:
            return cls.derive_from_project_id(project_id)

        # RFC 9106 recommended parameters: 64 MiB memory, 3 iterations, 4 lanes
        if salt is None or len(salt) < 16:
            salt_seed = f"CAMS_PASSPHRASE_V2:{project_id or 'default'}".encode("utf-8")
            actual_salt = hashlib.sha256(salt_seed).digest()[:16]
        else:
            actual_salt = salt[:16]

        derived = Argon2id(
            salt=actual_salt,
            length=32,
            iterations=3,
            lanes=4,
            memory_cost=64 * 1024,
        ).derive(passphrase.encode("utf-8"))
        cipher = cls(key=derived)

        # Add fallback candidate keys:
        # 1. Legacy Argon2id key (V1: 32 MiB, t=2, p=2 with legacy salt)
        legacy_salt = hashlib.sha256(f"CAMS_PASSPHRASE:{project_id or 'default'}".encode("utf-8")).digest()[:16]
        legacy_key = Argon2id(
            salt=legacy_salt,
            length=32,
            iterations=2,
            lanes=2,
            memory_cost=32 * 1024,
        ).derive(passphrase.encode("utf-8"))
        cipher.add_fallback_key(legacy_key)

        # 2. Project_id HKDF key
        if project_id:
            cipher.add_fallback_key(cls.derive_from_project_id(project_id)._key)

        # 3. Default fallback key
        cipher.add_fallback_key(_derive_default_key())
        return cipher

    @classmethod
    def derive_from_project_id(cls, project_id: str) -> "CredentialCipher":
        """Derive a 256-bit AES key for an open workspace without a passphrase using HKDF-SHA256."""
        hkdf = HKDF(
            algorithm=hashes.SHA256(),
            length=32,
            salt=DEFAULT_SALT,
            info=b"cams-unprotected-workspace-cipher",
        )
        derived = hkdf.derive((project_id or "default_project").encode("utf-8"))
        cipher = cls(key=derived)
        cipher.add_fallback_key(_derive_default_key())
        return cipher

    def encrypt(self, plaintext: str | None, context: str = "") -> str:
        """Encrypt plaintext password using AES-256-GCM with record-bound AAD.
        
        Returns ENC$v2$<base64_payload>.
        If plaintext is empty or None, returns ''.
        If plaintext is already encrypted with ENC$v2$, returns it directly (idempotent).
        """
        if not plaintext:
            return ""
        if plaintext.startswith(PREFIX_V2):
            return plaintext

        with self._lock:
            nonce = secrets.token_bytes(NONCE_SIZE)
            aesgcm = AESGCM(bytes(self._key))
            aad = make_aad(context)
            ciphertext_and_tag = aesgcm.encrypt(nonce, plaintext.encode("utf-8"), aad)
            payload = nonce + ciphertext_and_tag
            return PREFIX_V2 + base64.b64encode(payload).decode("ascii")

    def decrypt(self, ciphertext: str | None, context: str = "") -> str:
        """Decrypt AES-256-GCM ciphertext back to plaintext.
        
        If ciphertext is empty or None, returns ''.
        If ciphertext does NOT start with ENC$v1$ or ENC$v2$, returns ciphertext as-is (backward compatible).
        Tries primary key first, then candidate fallback keys if available.
        Raises InvalidTag on tampering, invalid key, or swapped ciphertext (AAD mismatch).
        """
        if not ciphertext:
            return ""
        if not (ciphertext.startswith(PREFIX_V2) or ciphertext.startswith(PREFIX_V1)):
            return ciphertext

        with self._lock:
            is_v2 = ciphertext.startswith(PREFIX_V2)
            prefix = PREFIX_V2 if is_v2 else PREFIX_V1
            raw_b64 = ciphertext[len(prefix):]
            try:
                raw = base64.b64decode(raw_b64, validate=True)
            except Exception as exc:
                raise ValueError("Malformed base64 in encrypted credential.") from exc

            if len(raw) < MIN_PAYLOAD_SIZE:
                raise ValueError("Encrypted credential payload is truncated.")

            nonce = raw[:NONCE_SIZE]
            ct_and_tag = raw[NONCE_SIZE:]

            aad = make_aad(context) if is_v2 else LEGACY_ASSOCIATED_DATA

            # Try primary key first, then fallback candidate keys
            keys_to_try = [bytes(self._key)] + [bytes(k) for k in self._fallback_keys]
            last_exc: InvalidTag | None = None

            for candidate in keys_to_try:
                try:
                    aesgcm = AESGCM(candidate)
                    decrypted_bytes = aesgcm.decrypt(nonce, ct_and_tag, aad)
                    # If a fallback key succeeded, promote it to primary key
                    if candidate != bytes(self._key):
                        self._key = bytearray(candidate)
                    return decrypted_bytes.decode("utf-8")
                except InvalidTag as exc:
                    last_exc = exc
                    continue

            if last_exc is not None:
                raise last_exc
            raise ValueError("Decryption failed with no valid candidate keys.")

    def is_encrypted(self, value: str | None) -> bool:
        """Return True if value has an ENC$v1$ or ENC$v2$ prefix."""
        return bool(value and (value.startswith(PREFIX_V2) or value.startswith(PREFIX_V1)))

    def clear(self) -> None:
        """Zero out key memory."""
        with self._lock:
            _zero_memory(self._key)
            for k in self._fallback_keys:
                _zero_memory(k)
            self._fallback_keys.clear()


_GLOBAL_LOCK = threading.RLock()
_ACTIVE_CIPHER: CredentialCipher | None = None


def get_active_cipher() -> CredentialCipher:
    """Return the active cipher instance, creating one from environment or default if needed."""
    global _ACTIVE_CIPHER
    with _GLOBAL_LOCK:
        if _ACTIVE_CIPHER is None:
            # Check if parent process passed active key via environment
            env_key = os.environ.get(ENV_CREDENTIAL_KEY)
            if env_key:
                try:
                    raw_key = base64.b64decode(env_key.strip(), validate=True)
                    if len(raw_key) == 32:
                        cipher = CredentialCipher(key=raw_key)
                        cipher.add_fallback_key(_derive_default_key())
                        _ACTIVE_CIPHER = cipher
                        return _ACTIVE_CIPHER
                except Exception:
                    pass
            _ACTIVE_CIPHER = CredentialCipher()
        return _ACTIVE_CIPHER


def set_active_cipher(cipher: CredentialCipher | None) -> None:
    """Set or replace the active credential cipher and synchronize environment variable."""
    global _ACTIVE_CIPHER
    with _GLOBAL_LOCK:
        if _ACTIVE_CIPHER is not None and _ACTIVE_CIPHER is not cipher:
            _ACTIVE_CIPHER.clear()
        _ACTIVE_CIPHER = cipher
        if cipher is not None and hasattr(cipher, "_key") and cipher._key:
            os.environ[ENV_CREDENTIAL_KEY] = base64.b64encode(bytes(cipher._key)).decode("ascii")
        else:
            os.environ.pop(ENV_CREDENTIAL_KEY, None)


def bind_session_credentials(session: Any) -> CredentialCipher:
    """Configure and activate credential cipher bound to the active WorkspaceSession."""
    if session is None:
        cipher = CredentialCipher()
        set_active_cipher(cipher)
        return cipher

    password = None
    if hasattr(session, "password") and callable(session.password):
        password = session.password()

    project_id = ""
    manifest = getattr(session, "manifest", None)
    if manifest is not None:
        project_id = getattr(manifest, "project_id", "") or ""

    if password:
        cipher = CredentialCipher.derive_from_passphrase(password, project_id)
    else:
        cipher = CredentialCipher.derive_from_project_id(project_id)

    set_active_cipher(cipher)

    # Persist transient key file in the workspace directory for child processes (e.g. interactive_ssh)
    working_dir = getattr(session, "working_directory", None)
    if working_dir is not None:
        try:
            key_path = Path(working_dir) / TRANSIENT_KEY_FILE
            descriptor = os.open(
                key_path,
                os.O_WRONLY | os.O_CREAT | os.O_TRUNC,
                0o600,
            )
            try:
                os.write(descriptor, bytes(cipher._key))
                os.fsync(descriptor)
            finally:
                os.close(descriptor)
        except Exception:
            pass

    return cipher


def clear_session_credentials() -> None:
    """Clear and release the active cipher."""
    set_active_cipher(None)


def ensure_database_credential_cipher(db_path: str | Path | None) -> CredentialCipher:
    """Ensure the process has an active cipher configured for the given database."""
    cipher = get_active_cipher()

    # 0. Check if parent process passed active key via environment
    env_key = os.environ.get(ENV_CREDENTIAL_KEY)
    if env_key:
        try:
            raw_key = base64.b64decode(env_key.strip(), validate=True)
            if len(raw_key) == 32:
                cipher.add_fallback_key(raw_key)
                if bytes(cipher._key) == _derive_default_key():
                    cipher._key = bytearray(raw_key)
        except Exception:
            pass

    if not db_path:
        return cipher

    path = Path(db_path).resolve()
    search_dirs = [path.parent]
    if path.parent.parent.is_dir():
        search_dirs.append(path.parent.parent)

    # 1. Try reading transient key file (.credential_key)
    for search_dir in search_dirs:
        key_file = search_dir / TRANSIENT_KEY_FILE
        if key_file.is_file():
            try:
                raw = key_file.read_bytes()
                if len(raw) == 32:
                    cipher.add_fallback_key(raw)
                    # If cipher was using default seed, switch to the session key
                    if bytes(cipher._key) == _derive_default_key():
                        cipher._key = bytearray(raw)
                        os.environ[ENV_CREDENTIAL_KEY] = base64.b64encode(raw).decode("ascii")
                    return cipher
            except Exception:
                pass

    # 2. Try reading manifest.json to derive key from project_id / projectId
    for search_dir in search_dirs:
        manifest_file = search_dir / "manifest.json"
        if manifest_file.is_file():
            try:
                data = json.loads(manifest_file.read_text(encoding="utf-8"))
                project_id = str(data.get("projectId") or data.get("project_id") or "")
                if project_id:
                    derived_cipher = CredentialCipher.derive_from_project_id(project_id)
                    cipher.add_fallback_key(derived_cipher._key)
                    if bytes(cipher._key) == _derive_default_key():
                        cipher._key = bytearray(derived_cipher._key)
                        os.environ[ENV_CREDENTIAL_KEY] = base64.b64encode(bytes(derived_cipher._key)).decode("ascii")
                    return cipher
            except Exception:
                pass

    return cipher


def encrypt_credential(plaintext: str | None, context: str = "") -> str:
    """Encrypt a credential string using the currently active cipher."""
    return get_active_cipher().encrypt(plaintext, context=context)


def decrypt_credential(ciphertext: str | None, context: str = "") -> str:
    """Decrypt a credential string using the currently active cipher."""
    return get_active_cipher().decrypt(ciphertext, context=context)


def migrate_database_passwords(conn: sqlite3.Connection, cipher: CredentialCipher | None = None) -> int:
    """Scan t01_devices for plaintext or legacy ENC$v1$ passwords and re-encrypt to ENC$v2$ with record-bound AAD.
    
    Returns the number of credential fields encrypted or upgraded.
    """
    active_cipher = cipher or get_active_cipher()
    cursor = conn.cursor()
    table_check = cursor.execute(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name='t01_devices' LIMIT 1;"
    ).fetchone()
    if not table_check:
        return 0

    cols = {row[1] for row in cursor.execute("PRAGMA table_info(t01_devices);").fetchall()}
    if "password" not in cols:
        return 0
    has_enable = "enable_password" in cols

    query = f"SELECT host, password{', enable_password' if has_enable else ''} FROM t01_devices;"
    rows = cursor.execute(query).fetchall()
    migrated_count = 0

    for row in rows:
        host = str(row[0] or "").strip()
        pw = row[1] or ""
        epw = (row[2] or "") if has_enable else ""

        updates = []
        params = []
        # If password is non-empty and not already ENC$v2$, migrate to ENC$v2$
        if pw and not pw.startswith(PREFIX_V2):
            decrypted_pw = active_cipher.decrypt(pw)  # Plaintext or ENC$v1$
            new_pw = active_cipher.encrypt(decrypted_pw, context=f"{host}:password")
            updates.append("password = ?")
            params.append(new_pw)
            migrated_count += 1
        # If enable_password is non-empty and not already ENC$v2$, migrate to ENC$v2$
        if has_enable and epw and not epw.startswith(PREFIX_V2):
            decrypted_epw = active_cipher.decrypt(epw)  # Plaintext or ENC$v1$
            new_epw = active_cipher.encrypt(decrypted_epw, context=f"{host}:enable_password")
            updates.append("enable_password = ?")
            params.append(new_epw)
            migrated_count += 1

        if updates:
            params.append(host)
            sql = f"UPDATE t01_devices SET {', '.join(updates)} WHERE host = ?;"
            cursor.execute(sql, tuple(params))

    if migrated_count > 0:
        conn.commit()
    return migrated_count


__all__ = [
    "ASSOCIATED_DATA",
    "CredentialCipher",
    "DEFAULT_SALT",
    "ENV_CREDENTIAL_KEY",
    "LEGACY_ASSOCIATED_DATA",
    "PREFIX",
    "PREFIX_V1",
    "PREFIX_V2",
    "TRANSIENT_KEY_FILE",
    "bind_session_credentials",
    "clear_session_credentials",
    "decrypt_credential",
    "encrypt_credential",
    "ensure_database_credential_cipher",
    "get_active_cipher",
    "make_aad",
    "migrate_database_passwords",
    "set_active_cipher",
]
