// Helper chèn hình.
// Ví dụ:
// #insert-image("/documentation_assets/ui/docshot/core/workspace-overview.png", caption: [Giao diện chính]) <fig-main>

#let insert-image(path, caption: none, width: 80%, alt: none) = figure(
  align(center, image(path, width: width, alt: alt)),
  kind: image,
  caption: caption,
)
