import UIKit

enum CaptureFlyoverPresenter {

    private static var overlayWindow: UIWindow?

    static func presentCaptureAnimation() {
        DispatchQueue.main.async {
            presentNow()
        }
    }

    private static func presentNow() {
        _ = AppGroupStorage.consumeCapturePending()

        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { presentNow() }
            return
        }

        let image = AppGroupStorage.loadCaptureImage() ?? placeholderImage()

        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.backgroundColor = .clear
        window.isOpaque = false

        let root = FlyoverRootViewController(image: image) {
            dismissOverlay()
        }
        window.rootViewController = root
        window.makeKeyAndVisible()
        overlayWindow = window
    }

    private static func dismissOverlay() {
        overlayWindow?.isHidden = true
        overlayWindow = nil
    }

    private static func placeholderImage() -> UIImage {
        let size = CGSize(width: 120, height: 120)
        return UIGraphicsImageRenderer(size: size).image { _ in
            UIColor.systemIndigo.withAlphaComponent(0.85).setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 20).fill()
            let config = UIImage.SymbolConfiguration(pointSize: 44, weight: .medium)
            UIImage(systemName: "bookmark.fill", withConfiguration: config)?
                .withTintColor(.white, renderingMode: .alwaysOriginal)
                .draw(at: CGPoint(x: 38, y: 38))
        }
    }
}

/// Starts animation only after the overlay view has a real frame.
private final class FlyoverRootViewController: UIViewController {
    private let image: UIImage
    private let onFinish: () -> Void
    private var didStart = false

    init(image: UIImage, onFinish: @escaping () -> Void) {
        self.image = image
        self.onFinish = onFinish
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isOpaque = false
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard !didStart, view.bounds.width > 10, view.bounds.height > 10 else { return }
        didStart = true
        IslandCatchAnimator(image: image, onSave: {}, onFinish: onFinish).start(in: view)
    }
}
