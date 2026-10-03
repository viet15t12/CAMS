"""Privilege escalation helper for network device connections."""

from __future__ import annotations

import re
from typing import Any

PRIVILEGE_LEVEL_RE = re.compile(r"Current privilege level is\s+(\d+)", re.IGNORECASE)


def ensure_privileged_mode(connection: Any) -> bool:
    """Ensure an active connection is in privileged EXEC mode (privilege 15 on Cisco devices).

    Handles standard Cisco IOS enable escalation as well as intermediate
    privilege levels (2-14) where Cisco IOS provides a '#' prompt that
    causes Netmiko's default check_enable_mode() to falsely believe the
    session is already at privilege 15.
    """
    if connection is None:
        return False

    # 1. If currently in config mode, exit to EXEC mode first
    check_config = getattr(connection, "check_config_mode", None)
    exit_config = getattr(connection, "exit_config_mode", None)
    if callable(check_config) and check_config() and callable(exit_config):
        exit_config()

    # 2. Check standard Netmiko enable mode (detects '>' prompt on privilege 1)
    check_enable = getattr(connection, "check_enable_mode", None)
    enable_method = getattr(connection, "enable", None)

    if callable(check_enable) and not check_enable():
        if callable(enable_method):
            enable_method()
        return True

    # 3. For Cisco devices where prompt already ends in '#', verify the actual
    # privilege level is 15.
    device_type = str(getattr(connection, "device_type", "") or "").lower()
    is_cisco = "cisco" in device_type or not device_type

    if is_cisco and callable(enable_method) and hasattr(connection, "send_command"):
        try:
            priv_output = connection.send_command("show privilege")
            match = PRIVILEGE_LEVEL_RE.search(str(priv_output or ""))
            if match:
                current_level = int(match.group(1))
                if current_level < 15:
                    # Session has '#' prompt but privilege < 15. Force enable escalation.
                    enable_method(cmd="enable 15", check_state=False)
                    # Verify privilege elevation
                    verify_output = connection.send_command("show privilege")
                    verify_match = PRIVILEGE_LEVEL_RE.search(str(verify_output or ""))
                    if not verify_match or int(verify_match.group(1)) < 15:
                        lvl = verify_match.group(1) if verify_match else "unknown"
                        raise RuntimeError(
                            f"Failed to elevate to privilege 15 (strict fail-closed verification). "
                            f"Current level: {lvl}, output: {verify_output!r}"
                        )
        except Exception as exc:
            if "Failed to elevate" in str(exc) or "enable" in str(exc).lower() or "secret" in str(exc).lower():
                raise

    return True


def ensure_initial_privilege(connection: Any, secret: str = "", username: str = "") -> None:
    """Validate that the session reaches Privilege 15 during initial login.

    Strict 2-step verification:
    Step 1: Check if the account is directly at Privilege 15.
            If yes, allow in.
    Step 2: If privilege < 15:
            - If NO Enable Secret was configured -> DROP immediately to DISCONNECTED.
            - If Enable Secret was configured -> attempt elevation.
              If elevation fails (wrong secret) -> DROP immediately to DISCONNECTED.
              If elevation succeeds -> allow in at Privilege 15.
    """
    if connection is None:
        raise RuntimeError("No network connection created")

    device_type = str(getattr(connection, "device_type", "") or "").lower()
    is_cisco = "cisco" in device_type or not device_type

    check_enable = getattr(connection, "check_enable_mode", None)
    enable_method = getattr(connection, "enable", None)

    is_privilege_15 = False
    current_level = 1

    find_prompt = getattr(connection, "find_prompt", None)
    prompt_is_hash = bool(callable(check_enable) and check_enable())
    if not prompt_is_hash and callable(find_prompt):
        try:
            prompt_str = str(find_prompt() or "")
            prompt_is_hash = "#" in prompt_str
        except Exception:
            pass

    if is_cisco and hasattr(connection, "send_command"):
        try:
            priv_output = connection.send_command("show privilege")
            match = PRIVILEGE_LEVEL_RE.search(str(priv_output or ""))
            if match:
                current_level = int(match.group(1))
                is_privilege_15 = (current_level == 15)
            elif prompt_is_hash:
                # show privilege did not return level format; rely on prompt
                is_privilege_15 = True
        except Exception:
            if prompt_is_hash:
                is_privilege_15 = True
    elif prompt_is_hash:
        is_privilege_15 = True

    # Step 1: Already at Privilege 15 -> Allow in
    if is_privilege_15:
        return

    # Step 2: Account is < 15. Verify that Enable Secret was provided
    clean_secret = str(secret or "").strip()
    if not clean_secret:
        user_str = f"Account '{username}'" if username else "This account"
        raise PermissionError(
            f"Device requires Privilege 15 for CAMS management. "
            f"{user_str} has privilege {current_level} (< 15) and no Enable Secret was configured. "
            f"Connection dropped."
        )

    # Step 3: Enable Secret provided, attempt escalation
    if hasattr(connection, "secret"):
        connection.secret = clean_secret

    if not callable(enable_method):
        raise PermissionError("Connection does not support privilege escalation.")

    try:
        if callable(check_enable) and not check_enable():
            # Prompt ends in '>', standard enable
            enable_method()
        else:
            # Prompt ends in '#' but privilege < 15, force enable 15
            enable_method(cmd="enable 15", check_state=False)
    except Exception as exc:
        raise PermissionError(
            f"Privilege elevation failed: Invalid Enable Secret ({exc}). Connection dropped."
        ) from exc

    # Verify that session actually reached Privilege 15 (strict fail-closed)
    if is_cisco and hasattr(connection, "send_command"):
        try:
            verify_output = connection.send_command("show privilege")
            match = PRIVILEGE_LEVEL_RE.search(str(verify_output or ""))
            if not match or int(match.group(1)) < 15:
                current_lvl = match.group(1) if match else "unknown"
                raise PermissionError(
                    f"Privilege elevation rejected (strict fail-closed verification): "
                    f"Router remained at level {current_lvl} (< 15). Connection dropped."
                )
        except PermissionError:
            raise
        except Exception as exc:
            raise PermissionError(
                f"Privilege elevation verification failed ({exc}). Connection dropped."
            ) from exc
