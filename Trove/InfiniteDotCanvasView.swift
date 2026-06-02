import SwiftUI

struct InfiniteDotCanvasView: View {
    let assets: [CanvasAsset]
    @Binding var panOffset: CGSize

    @GestureState private var dragOffset: CGSize = .zero

    private let dotSpacing: CGFloat = 28
    private let dotRadius: CGFloat = 1.2

    var body: some View {
        GeometryReader { geo in
            let totalOffset = CGSize(
                width: panOffset.width + dragOffset.width,
                height: panOffset.height + dragOffset.height
            )

            ZStack {
                Color.black

                Canvas { context, size in
                    let remainderX = totalOffset.width.truncatingRemainder(dividingBy: dotSpacing)
                    let remainderY = totalOffset.height.truncatingRemainder(dividingBy: dotSpacing)
                    let startX = remainderX - dotSpacing
                    let startY = remainderY - dotSpacing

                    var x = startX
                    while x < size.width + dotSpacing {
                        var y = startY
                        while y < size.height + dotSpacing {
                            let rect = CGRect(
                                x: x - dotRadius,
                                y: y - dotRadius,
                                width: dotRadius * 2,
                                height: dotRadius * 2
                            )
                            context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.2)))
                            y += dotSpacing
                        }
                        x += dotSpacing
                    }
                }
                .ignoresSafeArea()

                ForEach(assets) { asset in
                    AssetThumbnailView(image: asset.image)
                        .position(
                            x: asset.position.x + totalOffset.width,
                            y: asset.position.y + totalOffset.height
                        )
                }

                if assets.isEmpty {
                    Text("Share to Trove from Safari or Photos")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.35))
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation
                    }
                    .onEnded { value in
                        panOffset.width += value.translation.width
                        panOffset.height += value.translation.height
                    }
            )
            .onAppear {
                guard panOffset == .zero else { return }
                panOffset = CGSize(width: geo.size.width / 2, height: geo.size.height / 2)
            }
        }
        .ignoresSafeArea()
    }
}

private struct AssetThumbnailView: View {
    let image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.08))
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.white.opacity(0.35))
                    }
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.45), radius: 6, y: 3)
    }
}
