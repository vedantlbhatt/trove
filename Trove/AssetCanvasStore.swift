import SwiftUI
import UIKit

struct CanvasAsset: Identifiable {
    let id: String
    let url: URL
    let image: UIImage?
    let position: CGPoint
}

@MainActor
final class AssetCanvasStore: ObservableObject {
    @Published private(set) var assets: [CanvasAsset] = []

    func reload() {
        let saved = AppGroupStorage.fetchVisualAssets()
        assets = saved.enumerated().map { index, item in
            CanvasAsset(
                id: item.id,
                url: item.fileURL,
                image: UIImage(contentsOfFile: item.fileURL.path),
                position: Self.gridPosition(for: index)
            )
        }
    }

    private static func gridPosition(for index: Int) -> CGPoint {
        let columns = 4
        let spacing: CGFloat = 96
        let col = index % columns
        let row = index / columns
        return CGPoint(x: CGFloat(col) * spacing, y: CGFloat(row) * spacing)
    }
}
