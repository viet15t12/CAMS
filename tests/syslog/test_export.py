import tempfile
import unittest
import zipfile
from pathlib import Path
from xml.etree import ElementTree

from features.syslog.export import export_logs_xlsx


class SyslogExcelExportTests(unittest.TestCase):
    def test_exports_displayed_rows_with_filters_and_excel_structure(self) -> None:
        rows = [
            {
                "received_at": "2026-08-26T18:06:31.095+00:00",
                "device_time": "2026-08-26T18:06:31.095Z",
                "device_host": "192.0.2.10",
                "source_ip": "192.0.2.10",
                "protocol": "udp",
                "severity": 3,
                "cisco_facility": "LINK",
                "mnemonic": "UPDOWN",
                "message": "Interface Loopback99 changed state to down",
                "raw_message": "%LINK-3-UPDOWN: Interface Loopback99 changed state to down",
                "sequence_number": 10,
                "parse_status": "parsed",
            },
            {
                "received_at": "2026-08-26T18:05:00.000+00:00",
                "device_host": "192.0.2.11",
                "source_ip": "192.0.2.11",
                "protocol": "tcp",
                "severity": 5,
                "facility": "SYS",
                "mnemonic": "CONFIG_I",
                "message": "Configured from console",
                "raw_message": "Configured from console",
                "parse_status": "parsed",
            },
        ]
        filters = {
            "host": "",
            "per_host": 20,
            "smart_query": "last:20 severity:error,notice",
            "severities": [3, 5],
        }

        with tempfile.TemporaryDirectory() as temp_dir:
            result = export_logs_xlsx(Path(temp_dir) / "visible-logs", rows, filters)
            self.assertEqual(result.suffix, ".xlsx")
            self.assertTrue(result.is_file())

            with zipfile.ZipFile(result) as workbook:
                self.assertTrue({
                    "[Content_Types].xml",
                    "xl/workbook.xml",
                    "xl/styles.xml",
                    "xl/worksheets/sheet1.xml",
                }.issubset(workbook.namelist()))
                sheet = workbook.read("xl/worksheets/sheet1.xml")
                ElementTree.fromstring(sheet)
                text = sheet.decode("utf-8")
                self.assertIn("CAMS Syslog Export", text)
                self.assertIn("last:20 severity:error,notice", text)
                self.assertIn('autoFilter ref="A6:N8"', text)
                self.assertIn("Interface Loopback99 changed state to down", text)

    def test_exports_dai_permit_and_deny_labels_from_unannotated_rows(self) -> None:
        rows = [
            {"cisco_facility": "SW_DAI", "mnemonic": mnemonic,
             "severity": severity, "message": message}
            for mnemonic, severity, message in (
                ("DHCP_SNOOPING_PERMIT", 6, "1 ARPs (Req) on Gi0/1"),
                ("DHCP_SNOOPING_DENY", 4, "1 Invalid ARPs (Req) on Gi0/1"),
            )
        ]
        with tempfile.TemporaryDirectory() as temporary:
            result = export_logs_xlsx(Path(temporary) / "dai.xlsx", rows, {})
            with zipfile.ZipFile(result) as workbook:
                sheet = ElementTree.fromstring(workbook.read("xl/worksheets/sheet1.xml"))
                ns = {"s": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
                cells = {cell.attrib["r"]: cell.findtext("s:is/s:t", namespaces=ns)
                         for cell in sheet.findall(".//s:c", ns)}
                self.assertEqual(cells["M7"], "Dynamic ARP Inspection")
                self.assertEqual(cells["N7"], "Permitted")
                self.assertEqual(cells["N8"], "Denied")


if __name__ == "__main__":
    unittest.main()
