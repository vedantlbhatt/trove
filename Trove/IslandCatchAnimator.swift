import UIKit

/// Pure-UIKit fly-to-island animation.
final class IslandCatchAnimator {

    private let image: UIImage
    private let onSave: () -> Void
    private let onFinish: () -> Void

    private weak var container: UIView?
    private let islandPill = UIView()
    private let islandGlow = UIView()
    private let thumbView = UIImageView()

    private static let islandTopY: CGFloat = 11

    init(image: UIImage, onSave: @escaping () -> Void, onFinish: @escaping () -> Void) {
        self.image = image
        self.onSave = onSave
        self.onFinish = onFinish
    }

    func start(in container: UIView) {
        self.container = container
        layoutIsland(in: container)
        layoutThumb(in: container)
        runFlight(in: container)
    }

    private func layoutIsland(in container: UIView) {
        let w: CGFloat = 110
        let h: CGFloat = 36
        let x = (container.bounds.width - w) / 2
        let y = Self.islandTopY

        islandGlow.frame = CGRect(x: x - 6, y: y - 6, width: w + 12, height: h + 12)
        islandGlow.backgroundColor = UIColor.cyan.withAlphaComponent(0.55)
        islandGlow.layer.cornerRadius = (h + 12) / 2
        islandGlow.alpha = 0
        container.addSubview(islandGlow)

        islandPill.frame = CGRect(x: x, y: y, width: w, height: h)
        islandPill.backgroundColor = .black
        islandPill.layer.cornerRadius = h / 2
        container.addSubview(islandPill)
    }

    private func layoutThumb(in container: UIView) {
        let size: CGFloat = 120
        thumbView.image = image
        thumbView.contentMode = .scaleAspectFill
        thumbView.clipsToBounds = true
        thumbView.layer.cornerRadius = 20
        thumbView.layer.borderWidth = 1
        thumbView.layer.borderColor = UIColor.white.withAlphaComponent(0.25).cgColor
        thumbView.layer.shadowColor = UIColor.black.cgColor
        thumbView.layer.shadowOpacity = 0.3
        thumbView.layer.shadowRadius = 14
        thumbView.layer.shadowOffset = CGSize(width: 0, height: 6)
        thumbView.bounds = CGRect(x: 0, y: 0, width: size, height: size)
        thumbView.center = CGPoint(x: container.bounds.midX, y: container.bounds.height * 0.52)
        thumbView.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
        container.addSubview(thumbView)
    }

    private func runFlight(in container: UIView) {
        let start = thumbView.center
        let end = CGPoint(x: container.bounds.midX, y: Self.islandTopY + islandPill.bounds.height / 2)
        let control = CGPoint(x: (start.x + end.x) / 2 + 50, y: (start.y + end.y) / 2 - 80)

        #if !targetEnvironment(simulator)
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.5)
        #endif

        let path = UIBezierPath()
        path.move(to: start)
        path.addQuadCurve(to: end, controlPoint: control)

        let fly = CAKeyframeAnimation(keyPath: "position")
        fly.path = path.cgPath
        fly.duration = 0.65
        fly.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        fly.fillMode = .forwards
        fly.isRemovedOnCompletion = false

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.6
        scale.toValue = 0.05
        scale.duration = 0.65
        scale.fillMode = .forwards
        scale.isRemovedOnCompletion = false

        UIView.animate(withDuration: 0.65) {
            self.islandGlow.alpha = 1
            self.islandPill.frame = CGRect(
                x: (container.bounds.width - 270) / 2, y: Self.islandTopY - 16, width: 270, height: 68)
            self.islandPill.layer.cornerRadius = 34
            self.islandGlow.frame = self.islandPill.frame.insetBy(dx: -6, dy: -6)
            self.islandGlow.layer.cornerRadius = self.islandGlow.bounds.height / 2
        }

        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in self?.absorb() }
        thumbView.layer.add(fly, forKey: "fly")
        thumbView.layer.add(scale, forKey: "scale")
        thumbView.layer.position = end
        thumbView.transform = CGAffineTransform(scaleX: 0.05, y: 0.05)
        CATransaction.commit()
    }

    private func absorb() {
        #if !targetEnvironment(simulator)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 1.0)
        #endif
        thumbView.removeFromSuperview()
        onSave()
        guard let container else { onFinish(); return }
        UIView.animate(withDuration: 0.28, delay: 0, usingSpringWithDamping: 0.62, initialSpringVelocity: 0) {
            self.islandPill.frame = CGRect(
                x: (container.bounds.width - 280) / 2, y: Self.islandTopY - 17, width: 280, height: 70)
            self.islandGlow.alpha = 1
        } completion: { _ in
            UIView.animate(withDuration: 0.35, delay: 0.05, usingSpringWithDamping: 0.72, initialSpringVelocity: 0) {
                self.islandPill.frame = CGRect(
                    x: (container.bounds.width - 110) / 2, y: Self.islandTopY, width: 110, height: 36)
                self.islandPill.layer.cornerRadius = 18
                self.islandGlow.alpha = 0
            } completion: { _ in self.onFinish() }
        }
    }
}
