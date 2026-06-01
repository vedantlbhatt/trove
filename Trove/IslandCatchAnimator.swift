import UIKit

/// Fake Dynamic Island — slightly expand, then contract.
final class IslandCatchAnimator {

    private let onFinish: () -> Void
    private let island = UIView()

    private static let size = CGSize(width: 126, height: 37)

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    func start(in container: UIView) {
        let topY = max(container.safeAreaInsets.top - 6, 11)
        island.frame = CGRect(
            x: (container.bounds.width - Self.size.width) / 2,
            y: topY,
            width: Self.size.width,
            height: Self.size.height
        )
        island.backgroundColor = .black
        island.layer.cornerRadius = Self.size.height / 2
        island.layer.borderWidth = 1.5
        island.layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
        container.addSubview(island)

        UIView.animate(withDuration: 0.22, delay: 0, options: .curveEaseOut) {
            self.island.transform = CGAffineTransform(scaleX: 1.28, y: 1.22)
        } completion: { _ in
            UIView.animate(withDuration: 0.28, delay: 0, usingSpringWithDamping: 0.72, initialSpringVelocity: 0) {
                self.island.transform = .identity
            } completion: { _ in
                self.island.removeFromSuperview()
                self.onFinish()
            }
        }
    }
}
