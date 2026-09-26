#import "../config/commands.typ": appendix-heading, appendix-section
#import "../config/tables.typ": report-table, table-code

#counter(figure.where(kind: image)).update(0)
#counter(figure.where(kind: table)).update(0)
#show figure.where(kind: image): set figure(numbering: number => [A.#number])
#show figure.where(kind: table): set figure(numbering: number => [A.#number])

#appendix-heading[PHỤ LỤC A. CẤU TRÚC DỰ ÁN VÀ ÁNH XẠ MÃ NGUỒN]
#metadata("appendix-a-start") <appendix-a-start>

#appendix-section[A.1.][Sơ đồ cấu trúc thư mục mã nguồn runtime ứng dụng desktop]

Mã nguồn ứng dụng desktop CAMS được tổ chức tại thư mục gốc của kho mã nguồn theo kiến trúc phân lớp. Sơ đồ dưới đây thể hiện các lớp chính, nhóm mô-đun và trách nhiệm tương ứng.

#figure(
  image("/00_book/figures/report/appendix/project-structure.svg", width: 90%),
  caption: [Cấu trúc thư mục mã nguồn ứng dụng desktop CAMS],
) <fig-appendix-project-structure>

#pagebreak(weak: true)
#appendix-section[A.2.][Bảng ánh xạ luồng thành phần toàn hệ thống]

Bảng dưới đây mô tả chuỗi liên kết từ thành phần giao diện QML, qua lớp cầu nối PyQt6, đến tầng lưu trữ SQLite và các tác vụ hoặc mẫu Jinja2 dùng để thực thi cấu hình mạng.

#report-table(
  columns: (18%, 17%, 21%, 18%, 26%),
  text-size: 8.5pt,
  cell-inset: (x: 3pt, y: 4pt),
  header: ([Thành phần QML], [Bridge / Facade], [Dịch vụ & Repo], [Bảng SQLite], [Worker / Template]),
  rows: (
    ([#table-code("DeviceTabs.qml")], [#table-code("cli / dbManager")], [#table-code("DeviceRepository")], [#table-code("t01_devices")], [#table-code("DeviceSessionRegistry")]),
    ([#table-code("InterfacesView.qml")], [#table-code("dbManager")], [#table-code("InterfaceRepository")], [#table-code("t02_router_iface_*")], [#table-code("router_interface.j2")]),
    ([#table-code("DhcpView.qml")], [#table-code("dbManager")], [#table-code("DhcpRepository")], [#table-code("t03_dhcp_*")], [#table-code("dhcp_worker.py / dhcp.j2")]),
    ([#table-code("StaticRouting.qml")], [#table-code("dbManager")], [#table-code("RoutingRepository")], [#table-code("t04_static_routing")], [#table-code("routing_worker.py / static_route.j2")]),
    ([#table-code("OspfEditor.qml")], [#table-code("dbManager")], [#table-code("RoutingRepository")], [#table-code("t04_ospf_*")], [#table-code("routing_worker.py / ospf.j2")]),
    ([#table-code("EigrpEditor.qml")], [#table-code("dbManager")], [#table-code("RoutingRepository")], [#table-code("t04_eigrp_*")], [#table-code("routing_worker.py / eigrp.j2")]),
    ([#table-code("AclEditor.qml")], [#table-code("dbManager")], [#table-code("AclRepository")], [#table-code("t05_acl_*")], [#table-code("acl_worker.py / acl.j2")]),
    ([#table-code("NatEditor.qml")], [#table-code("dbManager")], [#table-code("NatRepository")], [#table-code("t05_nat_*")], [#table-code("nat_worker.py / nat.j2")]),
    ([#table-code("SwitchingView.qml")], [#table-code("dbManager")], [#table-code("SwitchingRepository")], [#table-code("t06_switch_*")], [#table-code("switching_worker.py / switching.j2")]),
    ([#table-code("FhrpEditor.qml")], [#table-code("dbManager")], [#table-code("FhrpRepository")], [#table-code("t08_fhrp_*")], [#table-code("fhrp.j2")]),
    ([#table-code("VtpEditor.qml")], [#table-code("dbManager")], [#table-code("SwitchingRepository")], [#table-code("t09_vtp_*")], [#table-code("vtp.j2")]),
    ([#table-code("SyslogView.qml")], [#table-code("syslogManager")], [#table-code("SyslogRepository")], [#table-code("t12_syslog_*")], [#table-code("SyslogListener (UDP/TCP)")]),
    ([#table-code("SftpView.qml")], [#table-code("sftpController")], [#table-code("SftpClientService")], [Hàng đợi bộ nhớ], [#table-code("ParamikoSFTPWorker")]),
    ([#table-code("TerminalHost.qml")], [#table-code("cli")], [#table-code("TerminalManager")], [Socket IPC NTTP/1], [#table-code("cams-terminal")]),
    ([#table-code("DatabaseBrowser.qml")], [#table-code("dbManager")], [#table-code("DatabaseBrowserService")], [Tất cả 93 bảng], [#table-code("sqlite3 query engine")]),
  ),
  caption: [Ánh xạ thành phần từ giao diện QML đến cơ sở dữ liệu và tác vụ thực thi],
) <tab-system-component-mapping>
