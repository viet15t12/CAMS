# Quy hoạch IP, cổng, VLAN và cấu hình mạng lab

## 1. Thiết bị

| Thiết bị | Hostname | Loopback0 | IP quản lý (Gi0/0) | Mạng quản lý |
|---|---|---|---|---|
| R1 | Router1 | 1.1.1.1/32 | 192.168.122.11/24 | Manager1 (mạng trái) |
| R2 | Router2 | 2.2.2.2/32 | 192.168.122.12/24 | Manager2 (mạng phải) |
| R3 | Router3 | 3.3.3.3/32 | 192.168.122.13/24 | Manager1 (mạng trái) |
| R4 | Router4 | 4.4.4.4/32 | 192.168.122.14/24 | Manager2 (mạng phải) |
| SW5 | Switch5 | 5.5.5.5/32 | 192.168.122.15/24 (routed port) | Manager1 (mạng trái) |
| SW6 | Switch6 | 6.6.6.6/32 | 192.168.122.16/24 (routed port) | Manager2 (mạng phải) |

Default gateway quản lý: 192.168.122.1 (SW5 có thêm default route 0.0.0.0/0 qua 192.168.122.1).

## 2. Liên kết point-to-point giữa router (/30)

| Liên kết | Subnet | Đầu A | Đầu B |
|---|---|---|---|
| R1 – R2 | 10.0.12.0/30 | R1 Gi0/1: 10.0.12.1 | R2 Gi0/1: 10.0.12.2 |
| R1 – R3 | 10.0.13.0/30 | R1 Gi0/3: 10.0.13.1 | R3 Gi0/2: 10.0.13.2 |
| R1 – R4 | 10.0.14.0/30 | R1 Gi0/2: 10.0.14.1 | R4 Gi0/1: 10.0.14.2 |
| R2 – R3 | 10.0.23.0/30 | R2 Gi0/2: 10.0.23.1 | R3 Gi0/1: 10.0.23.2 |
| R2 – R4 | 10.0.24.0/30 | R2 Gi0/3: 10.0.24.1 | R4 Gi0/2: 10.0.24.2 |

## 3. Quy hoạch cổng từng thiết bị

### Router1
| Cổng | Mô tả | IP | Nối tới |
|---|---|---|---|
| Gi0/0 | MANAGER1 | 192.168.122.11/24 | Mạng quản lý (Net trái) |
| Gi0/1 | TO_ROUTER2 | 10.0.12.1/30 | R2 Gi0/1 |
| Gi0/2 | TO_ROUTER4 | 10.0.14.1/30 | R4 Gi0/1 |
| Gi0/3 | TO_ROUTER3 | 10.0.13.1/30 | R3 Gi0/2 |

### Router2
| Cổng | Mô tả | IP | Nối tới |
|---|---|---|---|
| Gi0/0 | MANAGER2 | 192.168.122.12/24 | Mạng quản lý (Net phải) |
| Gi0/1 | TO_ROUTER1 | 10.0.12.2/30 | R1 Gi0/1 |
| Gi0/2 | TO_ROUTER3 | 10.0.23.1/30 | R3 Gi0/1 |
| Gi0/3 | TO_ROUTER4 | 10.0.24.1/30 | R4 Gi0/2 |

### Router3
| Cổng | Mô tả | IP | Nối tới |
|---|---|---|---|
| Gi0/0 | MANAGER1 | 192.168.122.13/24 | Mạng quản lý (Net trái) |
| Gi0/1 | TO_ROUTER2 | 10.0.23.2/30 | R2 Gi0/2 |
| Gi0/2 | TO_ROUTER1 | 10.0.13.2/30 | R1 Gi0/3 |
| Gi0/3 | TO_SWITCH5_TRUNK | không IP | SW5 Gi0/1 (trunk dot1q) |
| Gi0/3.100 | EMPLOYEE_VLAN100 | 192.168.100.253/24 | Gateway VLAN 100 (dot1Q 100) |

### Router4
| Cổng | Mô tả | IP | Nối tới |
|---|---|---|---|
| Gi0/0 | MANAGER2 | 192.168.122.14/24 | Mạng quản lý (Net phải) |
| Gi0/1 | TO_ROUTER1 | 10.0.14.2/30 | R1 Gi0/2 |
| Gi0/2 | TO_ROUTER2 | 10.0.24.2/30 | R2 Gi0/3 |
| Gi0/3 | TO_SWITCH6_TRUNK | không IP | SW6 Gi0/1 (trunk dot1q) |
| Gi0/3.100 | EMPLOYEE_VLAN100 | 192.168.100.254/24 | Gateway VLAN 100, ACL DETECT-PING (in) |

### Switch5
| Cổng | Mô tả | Chế độ | Nối tới |
|---|---|---|---|
| Gi0/0 | MANAGER1 | Routed, 192.168.122.15/24 | Mạng quản lý (Net trái) |
| Gi0/1 | TO_ROUTER3_TRUNK | Trunk dot1q, allowed VLAN 100 | R3 Gi0/3 |
| Gi0/2 | TO_SWITCH6_Gi0/2_TRUNK | Trunk dot1q, allowed VLAN 100 | SW6 Gi0/2 |
| Gi0/3 | TO_SWITCH6_Gi1/0_TRUNK | Trunk dot1q, allowed VLAN 100 | SW6 Gi1/0 |
| Gi1/0 | (range) | Access VLAN 100, portfast | VPC7 |
| Gi1/1 | (range) | Access VLAN 100, portfast | VPC8 |
| Gi1/2 | (range) | Access VLAN 100, portfast | VPC9 |
| Gi1/3 | (range) | Access VLAN 100, portfast | VPC10 |

### Switch6
| Cổng | Mô tả | Chế độ | Nối tới |
|---|---|---|---|
| Gi0/0 | MANAGER2 | Routed, 192.168.122.16/24 | Mạng quản lý (Net phải) |
| Gi0/1 | TO_ROUTER4_TRUNK | Trunk dot1q, allowed VLAN 100 | R4 Gi0/3 |
| Gi0/2 | TO_SWITCH5_Gi0/2_TRUNK | Trunk dot1q, allowed VLAN 100 | SW5 Gi0/2 |
| Gi0/3 | EMPLOYEE_NETWORK | Access VLAN 100, portfast | Employee Network |
| Gi1/0 | TO_SWITCH5_Gi0/3_TRUNK | Trunk dot1q, allowed VLAN 100 | SW5 Gi0/3 |

## 4. VLAN

| VLAN | Tên | Subnet | Gateway | Ghi chú |
|---|---|---|---|---|
| 100 | EMPLOYEE | 192.168.100.0/24 | R3: 192.168.100.253, R4: 192.168.100.254 | Tạo trên SW5 và SW6, chỉ cho phép VLAN 100 trên các trunk |

## 5. Cấu hình chung

- Domain: `lab.local`, tắt `ip domain-lookup`
- Tài khoản: `admin` (privilege 15), secret `admin123`
- SSH v2 (RSA 2048), VTY 0-4 `login local`, `transport input ssh`
- Switch5: `enable secret admin123`, SSH timeout 60s, retries 3, `exec-timeout 30 0` trên VTY

## 6. Cấu hình phát hiện ICMP flood (Router4)

- ACL `DETECT-PING` (extended) áp dụng chiều **in** trên Gi0/3.100:
  - `permit icmp any any echo log-input`
  - `permit ip any any`
- `ip access-list log-update threshold 500`
- Ẩn log `IPACCESSLOGDP` khỏi console/monitor/buffer bằng `logging discriminator NOACLLOG`
- EEM applet `DETECT-DOS`: khi gặp từ 4 log ICMP trong 30 giây (ratelimit 60, maxrun 20) thì lấy IP nguồn và cổng, rồi phát syslog mức alerts: `NGHI DOS: ICMP flood vao R4 tu IP <srcip> tai cong <intf>`

## 7. Sơ đồ kết nối tóm tắt

```
   Net trái (Manager1)                              Net phải (Manager2)
   R1, R3, SW5 (Gi0/0)                              R2, R4, SW6 (Gi0/0)

        R1 ------------- 10.0.12.0/30 ------------- R2
        | \                                       / |
        |  \_______ 10.0.14.0/30 (R1-R4) ________/  |
        |   ______  10.0.23.0/30 (R2-R3) _______    |
 10.0.13.0/30 /                                  \ 10.0.24.0/30
        |                                           |
        R3                                          R4
        |                                           |
     Gi0/3 (trunk)                            Gi0/3 (trunk)
        |                                           |
       SW5 ===== 2 trunk (Gi0/2, Gi0/3) ========== SW6 --- Employee Network
      / | \ \
 VPC7 VPC8 VPC9 VPC10          (VLAN 100: 192.168.100.0/24)
```

(R3 và R4 không nối trực tiếp với nhau. R1–R4 và R2–R3 là hai liên kết chéo, xem sơ đồ SVG để theo dõi chính xác.)

## 8. Lưu ý

- R3 và R4 đều là gateway VLAN 100 trên cùng subnet 192.168.100.0/24 nhưng chưa có HSRP/VRRP; nếu cần dự phòng nên cân nhắc thêm.
- Chú thích trong cấu hình gốc ở R3 ghi "to Router2 Gi0/2" và "to Router1 Gi0/3", bảng trên đã đối chiếu theo IP và sơ đồ thực tế.
