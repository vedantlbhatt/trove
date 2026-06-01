import UIKit

enum CaptureFlyoverPresenter {

    private static var overlayWindow: UIWindow?
    private static var isPresenting = false

    /// Called from trove:// URL — always try to show.
    static func presentCaptureAnimation() {
        DispatchQueue.main.async { presentNow(force: true) }
    }

    /// Called when app becomes active — only if extension marked a pending capture.
    static func presentIfPending() {
        DispatchQueue.main.async { presentNow(force: false) }
    }

    private static func presentNow(force: Bool) {
        guard !isPresenting else { return }

        let pending = AppGroupStorage.consumeCapturePending()
        guard force || pending else { return }

        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else {
            if pending { AppGroupStorage.markCapturePending() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { presentNow(force: force) }
            return
        }

        isPresenting = true
        dismissOverlay()

        let window = UIWindow(windowScene: scene)
        window.windowLevel = .statusBar + 1
        window.backgroundColor = .clear
        window.isOpaque = false
        window.isUserInteractionEnabled = false

        let root = FlyoverRootViewController {
            isPresenting = false
            dismissOverlay()
        }
        window.rootViewController = root
        window.isHidden = false
        overlayWindow = window

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            guard overlayWindow != nil else { return }
            isPresenting = false
            dismissOverlay()
        }
    }

    private static func dismissOverlay() {
        overlayWindow?.isHidden = true
        overlayWindow?.rootViewController = nil
        overlayWindow = nil
    }
}

private final class FlyoverRootViewController: UIViewController {
    private let onFinish: () -> Void
    private var didStart = false

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.isUserInteractionEnabled = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didStart else { return }
        didStart = true
        IslandCatchAnimator(onFinish: onFinish).start(in: view)
    }
}
