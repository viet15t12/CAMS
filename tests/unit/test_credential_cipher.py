"""Unit tests for CredentialCipher (Mechanism 2: Project Passphrase / AES-256-GCM)."""

from __future__ import annotations

import sqlite3
import unittest
from unittest.mock import MagicMock

from cryptography.exceptions import InvalidTag

from infrastructure.security.credential_cipher import (
    CredentialCipher,
    PREFIX,
    bind_session_credentials,
    clear_session_credentials,
    decrypt_credential,
    encrypt_credential,
    get_active_cipher,
    migrate_database_passwords,
    set_active_cipher,
)


class TestCredentialCipher(unittest.TestCase):
    """Verify cryptographic correctness, backward compatibility, and tampering detection."""

    def tearDown(self) -> None:
        clear_session_credentials()

    def test_encrypt_decrypt_roundtrip(self) -> None:
        cipher = CredentialCipher()
        test_passwords = [
            "cisco123",
            "Complex!P@ssw0rd#2026$",
            "MậtKhẩuTiếngViệtCóDấu@123",
            "   spaces and tabs \t\n  ",
            "a" * 256,
        ]
        for pwd in test_passwords:
            enc = cipher.encrypt(pwd)
            self.assertTrue(enc.startswith(PREFIX))
            self.assertNotEqual(enc, pwd)
            dec = cipher.decrypt(enc)
            self.assertEqual(dec, pwd)

    def test_empty_and_none_handling(self) -> None:
        cipher = CredentialCipher()
        self.assertEqual(cipher.encrypt(""), "")
        self.assertEqual(cipher.encrypt(None), "")
        self.assertEqual(cipher.decrypt(""), "")
        self.assertEqual(cipher.decrypt(None), "")

    def test_idempotence_encrypt(self) -> None:
        cipher = CredentialCipher()
        first_enc = cipher.encrypt("admin123")
        second_enc = cipher.encrypt(first_enc)
        self.assertEqual(first_enc, second_enc)
        self.assertEqual(cipher.decrypt(second_enc), "admin123")

    def test_backward_compatibility_plaintext(self) -> None:
        cipher = CredentialCipher()
        legacy_plaintext = "plaintext_password_from_old_db"
        dec = cipher.decrypt(legacy_plaintext)
        self.assertEqual(dec, legacy_plaintext)

    def test_tamper_detection(self) -> None:
        cipher = CredentialCipher()
        enc = cipher.encrypt("secret_device_pass")
        import base64
        payload = bytearray(base64.b64decode(enc[len(PREFIX):]))
        # Corrupt one byte of ciphertext
        payload[-1] ^= 0xFF
        tampered_enc = PREFIX + base64.b64encode(payload).decode("ascii")

        with self.assertRaises(InvalidTag):
            cipher.decrypt(tampered_enc)

    def test_derive_from_passphrase(self) -> None:
        passphrase = "UserProjectPassphrase!@#123"
        project_id = "test-proj-001"
        cipher = CredentialCipher.derive_from_passphrase(passphrase, project_id)
        enc = cipher.encrypt("my_cisco_enable_secret")
        self.assertEqual(cipher.decrypt(enc), "my_cisco_enable_secret")

        # Wrong passphrase cannot decrypt
        wrong_cipher = CredentialCipher.derive_from_passphrase("WrongPassphrase", project_id)
        with self.assertRaises(InvalidTag):
            wrong_cipher.decrypt(enc)

    def test_session_binding(self) -> None:
        mock_session = MagicMock()
        mock_session.password.return_value = "SessionMasterPassword"
        mock_session.manifest.project_id = "proj-xyz-789"

        bind_session_credentials(mock_session)
        enc = encrypt_credential("router_pass")
        self.assertEqual(decrypt_credential(enc), "router_pass")

        # Clear session restores default cipher
        clear_session_credentials()
        # Default cipher cannot decrypt session-encrypted credential
        with self.assertRaises(InvalidTag):
            decrypt_credential(enc)

    def test_migrate_database_passwords(self) -> None:
        conn = sqlite3.connect(":memory:")
        conn.execute("""
            CREATE TABLE t01_devices (
                host TEXT PRIMARY KEY,
                device_name TEXT,
                password TEXT,
                enable_password TEXT
            );
        """)
        conn.execute("""
            INSERT INTO t01_devices (host, device_name, password, enable_password)
            VALUES 
                ('10.0.0.1', 'R1', 'plain_pw_1', 'plain_enable_1'),
                ('10.0.0.2', 'R2', '', 'plain_enable_2'),
                ('10.0.0.3', 'SW1', 'plain_pw_3', '');
        """)
        conn.commit()

        migrated = migrate_database_passwords(conn)
        self.assertEqual(migrated, 4)  # 2 in R1, 1 in R2, 1 in SW1

        # Check that DB values now start with ENC$v1$
        rows = conn.execute("SELECT host, password, enable_password FROM t01_devices;").fetchall()
        for host, pw, epw in rows:
            if pw:
                self.assertTrue(pw.startswith(PREFIX))
                self.assertTrue(decrypt_credential(pw).startswith("plain_pw"))
            if epw:
                self.assertTrue(epw.startswith(PREFIX))
                self.assertTrue(decrypt_credential(epw).startswith("plain_enable"))

        # Second migration does nothing (already encrypted)
        second_migrated = migrate_database_passwords(conn)
        self.assertEqual(second_migrated, 0)
        conn.close()

    def test_device_repository_decrypts_credentials_on_get_login(self) -> None:
        import tempfile
        from pathlib import Path
        from features.devices.repository import DeviceRepository

        with tempfile.TemporaryDirectory() as tmpdir:
            db_path = Path(tmpdir) / "test_devices.db"
            conn = sqlite3.connect(db_path)
            conn.execute("""
                CREATE TABLE t01_devices (
                    host TEXT PRIMARY KEY,
                    device_name TEXT,
                    method TEXT,
                    portnumber INTEGER,
                    username TEXT,
                    password TEXT,
                    enable_password TEXT,
                    os TEXT,
                    role TEXT,
                    dev INTEGER,
                    connection_status TEXT DEFAULT 'waiting'
                );
            """)
            # Insert plaintext row
            conn.execute("""
                INSERT INTO t01_devices (host, device_name, method, portnumber, username, password, enable_password, os, role, dev)
                VALUES ('192.168.1.1', 'CoreRouter', 'SSH', 22, 'admin', 'PlainTextPass123', 'PlainTextSecret456', 'cisco', 'rou', 0);
            """)
            conn.commit()
            conn.close()

            repo = DeviceRepository(db_path)
            # activate_database triggers password migration
            repo.activate_database(db_path)

            # Direct SQLite check: values in DB must be encrypted with ENC$v1$
            conn = sqlite3.connect(db_path)
            raw_row = conn.execute("SELECT password, enable_password FROM t01_devices WHERE host = '192.168.1.1';").fetchone()
            conn.close()
            self.assertTrue(raw_row[0].startswith(PREFIX), f"Raw password is not encrypted: {raw_row[0]}")
            self.assertTrue(raw_row[1].startswith(PREFIX), f"Raw enable_password is not encrypted: {raw_row[1]}")

            # repo.get_login() must return decrypted plaintext
            login = repo.get_login("192.168.1.1")
            self.assertIsNotNone(login)
            self.assertEqual(login["password"], "PlainTextPass123")
            self.assertEqual(login["enable_password"], "PlainTextSecret456")

    def test_device_slots_mixin_encrypts_and_decrypts(self) -> None:
        import tempfile
        from pathlib import Path
        from core.database.device_slots import DeviceSlotsMixin

        class DummyBackend(DeviceSlotsMixin):
            def __init__(self, db_path: Path) -> None:
                self.db_path = db_path

        with tempfile.TemporaryDirectory() as tmpdir:
            db_path = Path(tmpdir) / "device_network.db"
            conn = sqlite3.connect(db_path)
            conn.execute("""
                CREATE TABLE t01_devices (
                    host TEXT PRIMARY KEY,
                    device_name TEXT,
                    method TEXT,
                    portnumber INTEGER,
                    username TEXT,
                    password TEXT,
                    enable_password TEXT,
                    os TEXT,
                    role TEXT,
                    connection_status TEXT DEFAULT 'waiting',
                    dev INTEGER DEFAULT 0,
                    device_type TEXT DEFAULT 'cisco_ios'
                );
            """)
            conn.commit()
            conn.close()

            backend = DummyBackend(db_path)
            # Add device via backend
            added = backend.addDevice(
                host="10.10.10.1",
                device_name="Switch1",
                method="SSH",
                port_text="22",
                username="netadmin",
                password="MyDevicePassword@999",
                enable_password="MyEnableSecret@888",
            )
            self.assertTrue(added)

            # Direct SQLite check: passwords in DB must start with ENC$v1$
            conn = sqlite3.connect(db_path)
            raw = conn.execute("SELECT password, enable_password FROM t01_devices WHERE host = '10.10.10.1';").fetchone()
            conn.close()
            self.assertTrue(raw[0].startswith(PREFIX))
            self.assertTrue(raw[1].startswith(PREFIX))

            # getDeviceByHost must return decrypted plaintext for UI binding
            dev_info = backend.getDeviceByHost("10.10.10.1")
            self.assertEqual(dev_info["pass"], "MyDevicePassword@999")
            self.assertEqual(dev_info["enable_pass"], "MyEnableSecret@888")

            # Update device
            updated = backend.updateDevice(
                host="10.10.10.1",
                device_name="Switch1-Updated",
                method="SSH",
                port_text="2222",
                username="superadmin",
                password="NewPassword#321",
                enable_password="NewSecret#654",
            )
            self.assertTrue(updated)

            # Direct DB check again
            conn = sqlite3.connect(db_path)
            raw_updated = conn.execute("SELECT password, enable_password FROM t01_devices WHERE host = '10.10.10.1';").fetchone()
            conn.close()
            self.assertTrue(raw_updated[0].startswith(PREFIX))
            self.assertTrue(raw_updated[1].startswith(PREFIX))

            # getDeviceByHost verifies updated credentials decrypted
            updated_info = backend.getDeviceByHost("10.10.10.1")
            self.assertEqual(updated_info["pass"], "NewPassword#321")
            self.assertEqual(updated_info["enable_pass"], "NewSecret#654")

    def test_subprocess_resolves_key_from_manifest_or_marker(self) -> None:
        """Simulate separate process (like interactive_ssh) loading credentials from workspace dir."""
        import json
        import tempfile
        from pathlib import Path
        from infrastructure.security.credential_cipher import (
            ensure_database_credential_cipher,
            TRANSIENT_KEY_FILE,
        )

        with tempfile.TemporaryDirectory() as tmpdir:
            workspace_dir = Path(tmpdir) / "workspace"
            workspace_dir.mkdir()
            db_path = workspace_dir / "device_network.db"

            # 1. Simulate Main GUI Process opening project with project_id
            project_id = "test-proj-uuid-5555"
            manifest_file = workspace_dir / "manifest.json"
            manifest_file.write_text(json.dumps({"project_id": project_id}), encoding="utf-8")

            mock_session = MagicMock()
            mock_session.password.return_value = None
            mock_session.manifest.project_id = project_id
            mock_session.working_directory = workspace_dir

            bind_session_credentials(mock_session)
            encrypted_val = encrypt_credential("switch_cisco_pass")
            self.assertTrue(encrypted_val.startswith(PREFIX))

            # 2. Simulate Subprocess Start: wipe all in-memory cipher state and env
            clear_session_credentials()
            import os
            os.environ.pop("CAMS_CREDENTIAL_KEY", None)

            # In this clean state, default cipher cannot decrypt directly
            default_cipher = get_active_cipher()
            # But calling ensure_database_credential_cipher resolves key from .credential_key or manifest.json!
            resolved_cipher = ensure_database_credential_cipher(db_path)
            self.assertIsNotNone(resolved_cipher)

            decrypted_val = decrypt_credential(encrypted_val)
            self.assertEqual(decrypted_val, "switch_cisco_pass")

    def test_subprocess_resolves_passphrase_key_via_transient_file(self) -> None:
        """Simulate subprocess resolving key when project is protected by passphrase."""
        import tempfile
        from pathlib import Path
        from infrastructure.security.credential_cipher import (
            ensure_database_credential_cipher,
        )

        with tempfile.TemporaryDirectory() as tmpdir:
            workspace_dir = Path(tmpdir) / "workspace"
            workspace_dir.mkdir()
            db_path = workspace_dir / "device_network.db"

            # 1. Main GUI Process with Passphrase
            passphrase = "UltraSecretPassphrase!2026"
            project_id = "protected-proj-999"
            mock_session = MagicMock()
            mock_session.password.return_value = passphrase
            mock_session.manifest.project_id = project_id
            mock_session.working_directory = workspace_dir

            bind_session_credentials(mock_session)
            encrypted_val = encrypt_credential("protected_router_secret")

            # 2. Subprocess wipes in-memory cipher and env
            clear_session_credentials()
            import os
            os.environ.pop("CAMS_CREDENTIAL_KEY", None)

            # Subprocess calls ensure_database_credential_cipher
            ensure_database_credential_cipher(db_path)
            decrypted_val = decrypt_credential(encrypted_val)
            self.assertEqual(decrypted_val, "protected_router_secret")


if __name__ == "__main__":
    unittest.main()
