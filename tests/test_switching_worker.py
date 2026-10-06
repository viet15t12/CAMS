from __future__ import annotations

import unittest

from features.switching.worker import apply_commands


class _Connection:
    def __init__(self, output: str) -> None:
        self.output = output

    def send_config_set(self, _commands, **_kwargs):
        return self.output


class _Connector:
    def __init__(self, output: str) -> None:
        self.connection = _Connection(output)


class _TimingConnection(_Connection):
    def __init__(self, output: str, exit_output: str, initial_prompt: str = "SW#") -> None:
        super().__init__(output)
        self.exit_output = exit_output
        self.initial_prompt = initial_prompt
        self.config_kwargs = None
        self.timing_calls = []

    def send_config_set(self, _commands, **kwargs):
        self.config_kwargs = kwargs
        if kwargs.get("enter_config_mode", True) or kwargs.get("exit_config_mode", True):
            raise RuntimeError("Pattern not detected: '[>#]' in output")
        return self.output

    def send_command_timing(self, command, **kwargs):
        self.timing_calls.append(command)
        assert kwargs["strip_prompt"] is False
        if command == "":
            return self.initial_prompt
        if command == "configure terminal":
            return "configure terminal\nSW(config)#"
        if command == "end":
            return self.exit_output
        raise AssertionError(command)


class SwitchingWorkerTests(unittest.TestCase):
    def test_virtual_ios_push_avoids_netmiko_prompt_probe(self) -> None:
        connection = _TimingConnection("SW(config-if)#exit\n", "end\nSW#")
        connector = _Connector("")
        connector.connection = connection

        self.assertEqual(apply_commands(connector, ["interface GigabitEthernet1/2"]),
                         "SW(config-if)#exit\nend\nSW#")
        self.assertFalse(connection.config_kwargs["enter_config_mode"])
        self.assertFalse(connection.config_kwargs["exit_config_mode"])
        self.assertEqual(connection.timing_calls, ["", "configure terminal", "end"])

    def test_existing_config_submode_is_exited_before_push(self) -> None:
        connection = _TimingConnection("ok\n", "end\nSW#", "SW(config-if)#")
        connector = _Connector("")
        connector.connection = connection

        apply_commands(connector, ["interface GigabitEthernet1/2"])

        self.assertEqual(connection.timing_calls, ["", "end", "configure terminal", "end"])

    def test_missing_initial_prompt_does_not_send_configuration(self) -> None:
        connection = _TimingConnection("ok\n", "end\nSW#", "")
        connector = _Connector("")
        connector.connection = connection

        with self.assertRaisesRegex(RuntimeError, "before Push"):
            apply_commands(connector, ["interface GigabitEthernet1/2"])

        self.assertIsNone(connection.config_kwargs)

    def test_missing_exec_prompt_does_not_confirm_push(self) -> None:
        connection = _TimingConnection("SW(config-if)#exit\n", "end\n")
        connector = _Connector("")
        connector.connection = connection

        with self.assertRaisesRegex(RuntimeError, "state is uncertain"):
            apply_commands(connector, ["interface GigabitEthernet1/2"])

    def test_timing_exit_still_rejects_invalid_ios_command(self) -> None:
        connection = _TimingConnection(
            "SW(config-if)#speed auto\n ^\n% Invalid input detected at '^' marker.\n",
            "end\nSW#",
        )
        connector = _Connector("")
        connector.connection = connection

        with self.assertRaisesRegex(RuntimeError, "speed auto"):
            apply_commands(connector, ["speed auto"])

    def test_fixed_dot1q_switch_can_reject_only_the_capability_command(self) -> None:
        output = """SW(config-if)#switchport trunk encapsulation dot1q
                                      ^
% Invalid input detected at '^' marker.
SW(config-if)#switchport mode trunk
SW(config-if)#"""

        self.assertEqual(apply_commands(_Connector(output), ["unused"]), output)

    def test_trunk_mode_rejection_is_fatal(self) -> None:
        output = """SW(config-if)#switchport mode trunk
Command rejected: An interface whose trunk encapsulation is Auto cannot be configured to trunk mode."""

        with self.assertRaisesRegex(RuntimeError, "Command rejected"):
            apply_commands(_Connector(output), ["unused"])

    def test_other_invalid_commands_remain_fatal(self) -> None:
        output = """SW(config-if)#speed auto
                         ^
% Invalid input detected at '^' marker."""

        with self.assertRaisesRegex(RuntimeError, "speed auto"):
            apply_commands(_Connector(output), ["unused"])

    def test_real_error_after_tolerated_dot1q_error_remains_fatal(self) -> None:
        output = """SW(config-if)#switchport trunk encapsulation dot1q
                                      ^
% Invalid input detected at '^' marker.
SW(config-if)#switchport mode trunk
                         ^
% Invalid input detected at '^' marker."""

        with self.assertRaisesRegex(RuntimeError, "switchport mode trunk"):
            apply_commands(_Connector(output), ["unused"])


if __name__ == "__main__":
    unittest.main()
