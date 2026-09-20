// ==========================================================
// CAMS MANUAL BOOK
// ==========================================================

#import "config/settings.typ": report-style, report-figure-outline-entry
#import "config/commands.typ": *
#import "config/info.typ": *
#import "config/images.typ": *
#import "config/listings.typ": *
#import "config/diagrams.typ": *

#show: report-style

// ----------------------------------------------------------
// PHẦN ĐẦU
// ----------------------------------------------------------
#set page(numbering: "i")
#counter(page).update(1)

#include "contents/00_loi_mo_dau.typ"

#pagebreak()
#outline(title: upper[Mục lục], depth: 4)

#pagebreak()
#{
  show outline.entry: it => report-figure-outline-entry(image, [Hình], it)
  outline(
    title: upper[Danh mục hình],
    target: figure.where(kind: image),
  )
}

#pagebreak()
#{
  show outline.entry: it => report-figure-outline-entry(table, [Bảng], it)
  outline(
    title: upper[Danh mục bảng],
    target: figure.where(kind: table),
  )
}

// ----------------------------------------------------------
// NỘI DUNG CHÍNH
// ----------------------------------------------------------
#pagebreak()
#set page(numbering: "1")
#counter(page).update(1)

#include "contents/01_tong_quan.typ"
#include "contents/02_cai_dat_su_dung.typ"
#include "contents/03_giao_dien_dieu_huong.typ"
#include "contents/04_quan_ly_thiet_bi.typ"
#include "contents/05_cau_hinh_interface_router.typ"
#include "contents/06_cau_hinh_routing.typ"
#include "contents/07_cau_hinh_dhcp.typ"
#include "contents/08_cau_hinh_acl.typ"
#include "contents/09_cau_hinh_fhrp.typ"
#include "contents/10_cau_hinh_syslog_server.typ"
#include "contents/11_cau_hinh_nat.typ"
#include "contents/12_truyen_tep_sftp.typ"
#include "contents/13_xem_system_logs.typ"
#include "contents/14_interface_switch_l2.typ"
#include "contents/15_vlan_etherchannel_stp_vtp.typ"
#include "contents/16_bao_mat_switch_l2.typ"
#include "contents/17_giam_sat_switch_l2.typ"
#include "contents/18_interface_switch_l3.typ"
#include "contents/19_dhcp_acl_switch_l3.typ"
