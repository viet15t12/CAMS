# Decisions — Phase 2

D001–D010 là các quyết định kiến trúc đã chốt trong yêu cầu. Implementation chưa thực hiện.

## D001 — One shared canonical asset repository

Một logical asset dùng chung book/report chỉ có một record/source file; staged copy không tạo logical ID mới.

## D002 — Canonical root outside 00_book/00_report

documentation_assets/ là source of truth; cả Typst book/report dùng project-root reference.

## D003 — MkDocs uses generated staging

00_book/assets/ generated từ canonical manifest, relative suffix giữ nguyên; không chỉnh tay. Khuyến nghị generated+gitignored+CI sync (A), chưa sửa .gitignore.

## D004 — SVG preferred for true vector sources

Ưu tiên SVG đúng source; different-content/uncertain pairs giữ độc lập; ptit wrapper không thành true vector.

## D005 — Preserve original experimental evidence

Lab CAMS UI vào evidence/ui-capture/original; terminal/log/external captures giữ bytes/provenance, cả orphan.

## D006 — Recreation can become presentation-preferred

New docshot có recreates_evidence_asset trỏ original ID, original_evidence=false; preference chỉ đổi sau review equivalence, không đổi provenance gốc.

## D007 — Terminal reconstruction is a derivative

derived_from + reconstruction_method + reconstruction_confidence bắt buộc; original retained; không giả định re-run tái lập thực nghiệm.

## D008 — Semantic kebab-case names

Không chapter/sequence prefix; dùng domain directory và state/device/meaningful data để phân biệt; ID ổn định không đổi theo path.

## D009 — No deletion during early phases

Không delete originals, orphan hay perceptual candidates. Archive-candidate/superseded không tự động theo ảnh giống nhau.

## D010 — Internally consistent atomic migration batches

Asset bytes + mọi reference + manifest + staging map + validation nằm trong cùng batch, không trì hoãn sửa links sang batch sau.

## D011 — Staging ownership recommendation

Chọn A: generated + gitignored + CI sync; không thấy blocker trong Phase 1. Cần script, CI ordering và local build instructions trước khi áp dụng. B (generated+tracked) giúp checkout preview trực tiếp/offline nhưng duplicate binary, stale/conflict noise; chỉ dùng nếu hosting không cho pre-build sync và có justification mới. Không sửa .gitignore trong Phase 2.

## D012 — Transitional manifest/helper

Bootstrap manifest records gồm legacy_path và proposed path, planned=true. Current source must exist/hash correctly; planned canonical path có thể chưa tồn tại. Sau từng atomic batch, current path=canonical, planned=false, legacy mapping chỉ còn history. Hai unresolved path rows không thành executable manifest entries trước review.

Book insert-image helper cần nhận /documentation_assets/... trực tiếp, đồng thời tiếp tục ../ + legacy relative path trong giai đoạn batch migration. Direct image(...) nhận absolute project-root path. Không sửa helper Phase 2.

## D013 — Preference is conditional

false trên lab original biểu thị policy ưu tiên recreation đã được review trong tương lai; không khiến pipeline tự thay current references bằng hypothetical assets. Chưa có recreation -> tiếp tục dùng original như hiện tại.

## D014 — Confidence split

Map confidence đánh giá domain/name/proposed role, không nâng provenance unknown thành high. Giữ provenance_confidence riêng từ audit; source_kind=unknown cho 148 documentation UI không xác định nguồn. Review_required không đồng nghĩa được phép block toàn bộ unrelated batches.

## Open reviews (không thay quyết định kiến trúc)

- U001: phân biệt/capture lineage cho switching 1_31.png và 1_6.png; giữ path rỗng, IDs provisional semantic, không move cho đến review.
- U002: xác nhận tên/heading và source order cho 12 raw LAB1 pages; không dùng số cũ làm ID.
- U003: ba uncertain topology/export pairs: giữ separate IDs/paths, không merge hoặc derivative claim.
- U004: 148 legacy UI historical provenance unknown; 73 lab UI original-capture probable. Evidence destinations ưu tiên preserve; chain of custody chưa verified.
- U005: training fixture chapter03 không tồn tại và destination tests legacy; infrastructure phase cần xử lý trước claim reproducible tests.
- U006: clip/state equivalence của 72 lab recreation candidates và 32 terminal reconstructions; đây không phải file đã có hoặc command đã support.
- U007: 110 orphan records/41 visual pairs cần disposition review; hiện không đề xuất deletion/superseded/archive để tránh kết luận từ similarity alone.
- U008: Phase 1 source context có caption chồng sang figure liền kề (feature-bar-switch, context-connected); giữ subject từ asset và review caption khi rewrite, không sửa audit history.
