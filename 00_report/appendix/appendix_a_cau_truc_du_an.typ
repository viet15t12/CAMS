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
#appendix-section[A.2.][Ánh xạ các thành phần đại diện theo mã nguồn]

Các bảng dưới đây sử dụng tên tệp và mô-đun có trong kho mã nguồn khi biên tập. Mỗi hàng liệt kê thành phần đại diện, không khẳng định một biểu mẫu chỉ dùng đúng một repository hoặc mọi bảng đều có trong tất cả workspace. Đường dẫn mô-đun được tính từ thư mục gốc dự án; tên mẫu Jinja2 được ghi ngắn để dễ đọc.

#report-table(
  columns: (23%, 26%, 25%, 26%),
  text-size: 9pt,
  cell-inset: (x: 3pt, y: 4pt),
  header: ([Thành phần QML], [Mô-đun nghiệp vụ / điều phối], [Bảng dữ liệu đại diện], [Tác vụ / mẫu lệnh]),
  rows: (
    ([#table-code("DeviceTabs.qml", size: 8.5pt)], [#table-code("features/devices/repository.py", size: 8.5pt)], [#table-code("t01_devices", size: 8.5pt)], [#table-code("infrastructure/network/session_registry.py", size: 8.5pt)]),
    ([#table-code("InterfaceView.qml", size: 8.5pt)], [#table-code("features/interfaces/repository.py", size: 8.5pt)], [#table-code("t02_interface_name; t02_router_iface_l3", size: 8.5pt)], [#table-code("features/interfaces/worker.py; commands.py", size: 8.5pt)]),
    ([#table-code("DhcpView.qml", size: 8.5pt)], [#table-code("features/dhcp/pool.py", size: 8.5pt)], [#table-code("t03_dhcp_pool; t03_excluded_address", size: 8.5pt)], [#table-code("features/dhcp/worker.py; dhcp_config.j2", size: 8.5pt)]),
    ([#table-code("StaticRoutingForm.qml", size: 8.5pt)], [#table-code("features/routing/static_route.py", size: 8.5pt)], [#table-code("t04_static_routes; t04_static_default_routes", size: 8.5pt)], [#table-code("features/routing/worker.py; static.j2", size: 8.5pt)]),
    ([#table-code("OspfRoutingForm.qml", size: 8.5pt)], [#table-code("features/routing/ospf/", size: 8.5pt)], [#table-code("t04_ospf_processes; t04_ospf_networks", size: 8.5pt)], [#table-code("features/routing/ospf/worker.py; ospf.j2", size: 8.5pt)]),
    ([#table-code("EigrpRoutingForm.qml", size: 8.5pt)], [#table-code("features/routing/", size: 8.5pt)], [#table-code("t04_eigrp_processes; t04_eigrp_networks", size: 8.5pt)], [#table-code("features/routing/worker.py; eigrp.j2", size: 8.5pt)]),
    ([#table-code("AclView.qml", size: 8.5pt)], [#table-code("features/acl/", size: 8.5pt)], [#table-code("t05_ACL_DB; t05_extended_acl_rules", size: 8.5pt)], [#table-code("features/acl/worker.py; standard.j2; extended.j2", size: 8.5pt)]),
  ),
  caption: [Ánh xạ giao diện, mô-đun và lưu trữ theo mã nguồn hiện tại],
) <tab-system-component-mapping>

#pagebreak(weak: true)

#report-table(
  columns: (23%, 26%, 25%, 26%),
  text-size: 9pt,
  cell-inset: (x: 3pt, y: 4pt),
  header: ([Thành phần QML], [Mô-đun nghiệp vụ / điều phối], [Bảng dữ liệu đại diện], [Tác vụ / mẫu lệnh]),
  rows: (
    ([#table-code("NatView.qml", size: 8.5pt)], [#table-code("features/nat/", size: 8.5pt)], [#table-code("t05_NAT_DB; t05_nat_interfaces", size: 8.5pt)], [#table-code("features/nat/worker.py; nat.j2", size: 8.5pt)]),
    ([#table-code("SwitchWorkspace.qml", size: 8.5pt)], [#table-code("features/switching/", size: 8.5pt)], [#table-code("t06_vlan_db; t06_interface_l2", size: 8.5pt)], [#table-code("features/switching/worker.py", size: 8.5pt)]),
    ([#table-code("FhrpView.qml", size: 8.5pt)], [#table-code("features/fhrp/repository.py", size: 8.5pt)], [#table-code("t08_fhrp_groups; t08_fhrp_members", size: 8.5pt)], [#table-code("features/fhrp/worker.py; fhrp.j2", size: 8.5pt)]),
    ([#table-code("VtpPage.qml", size: 8.5pt)], [#table-code("features/switching/", size: 8.5pt)], [#table-code("t09_vtp_domains; t09_vtp_switches", size: 8.5pt)], [#table-code("features/switching/worker.py", size: 8.5pt)]),
    ([#table-code("SyslogWorkspace.qml", size: 8.5pt)], [#table-code("features/syslog/qt/manager.py", size: 8.5pt)], [#table-code("t10_syslog_servers; t12_syslog_messages", size: 8.5pt)], [#table-code("features/syslog/transport/receiver.py", size: 8.5pt)]),
    ([#table-code("SftpView.qml", size: 8.5pt)], [#table-code("features/sftp/controller.py", size: 8.5pt)], [#table-code("Hàng đợi phiên, không phải bảng cấu hình mạng", size: 8.5pt)], [#table-code("features/sftp/sftp_service.py", size: 8.5pt)]),
    ([#table-code("DatabaseBrowserView.qml", size: 8.5pt)], [#table-code("core/external_tools.py", size: 8.5pt)], [#table-code("Các bảng có trong workspace được mở", size: 8.5pt)], [#table-code("infrastructure/database/browser/", size: 8.5pt)]),
  ),
  caption: [Ánh xạ giao diện, mô-đun và lưu trữ theo mã nguồn hiện tại],
) <tab-system-component-mapping-continued>

Terminal đồng hành được tổ chức trong `features/terminal/`, gồm `launcher.py`, `ipc_server.py` và `managed_manager.py`. Terminal giao tiếp với ứng dụng chính qua IPC. Bộ duyệt dữ liệu được mở qua `core/external_tools.py`; bảng dữ liệu khả dụng phụ thuộc workspace, không mặc định luôn có 93 bảng.
