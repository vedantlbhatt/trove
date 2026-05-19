import UIKit
import SwiftUI
import UniformTypeIdentifiers

/// Lets SwiftUI draw in the status-bar / Dynamic Island region (above the safe area).
private final class FullBleedHostingController<Content: View>: UIHostingController<Content> {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.clipsToBounds = false
        view.insetsLayoutMarginsFromSafeArea = false
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        let inset = view.safeAreaInsets
        additionalSafeAreaInsets = UIEdgeInsets(
            top: -inset.top,
            left: -inset.left,
            bottom: -inset.bottom,
            right: -inset.right
        )
    }
}

/// Fully transparent root view — avoids the default opaque white extension chrome.
private final class TransparentRootView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        clipsToBounds = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class InvisibleShareViewController: UIViewController {

    private var didStartExtraction = false
    private var hostingController: FullBleedHostingController<IslandCatchView>?
    private var pendingProviderAttempts = 0
    private var didPresentCanvas = false

    private static let preferredImageTypes: [String] = [
        UTType.jpeg.identifier,
        UTType.heic.identifier,
        UTType.heif.identifier,
        UTType.png.identifier,
        UTType.image.identifier,
        "public.jpeg",
        "public.heic",
        "public.png",
        "public.image"
    ]

    override func loadView() {
        view = TransparentRootView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.clipsToBounds = false
        modalPresentationStyle = .overFullScreen
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        prepareOverlayEnvironment()
        extractSharedContentAndLoadUI()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        prepareOverlayEnvironment()
    }

    private func prepareOverlayEnvironment() {
        clearPresentationChrome()
    }

    private func clearPresentationChrome() {
        var ancestor: UIView? = view
        while let current = ancestor {
            current.backgroundColor = .clear
            current.isOpaque = false
            current.clipsToBounds = false
            ancestor = current.superview
        }
    }

    private func extractSharedContentAndLoadUI() {
        guard !didStartExtraction else { return }
        didStartExtraction = true

        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            dismissPipeline()
            return
        }

        let providers = items.flatMap { $0.attachments ?? [] }
        guard !providers.isEmpty else {
            dismissPipeline()
            return
        }

        pendingProviderAttempts = providers.count

        for provider in providers {
            attemptLoad(from: provider)
        }
    }

    private func attemptLoad(from provider: NSItemProvider) {
        // Preview loads reliably from Photos even when full item loading fails.
        provider.loadPreviewImage(options: nil) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self, !self.didPresentCanvas else { return }
                if let image = item as? UIImage {
                    self.presentCanvas(with: image)
                }
            }
        }

        let types = orderedTypeIdentifiers(for: provider)
        loadImage(from: provider, typeIdentifiers: types, index: 0) { [weak self] in
            self?.providerAttemptFinished()
        }
    }

    private func providerAttemptFinished() {
        pendingProviderAttempts -= 1
        guard pendingProviderAttempts <= 0, !didPresentCanvas else { return }
        // Preview callbacks often arrive after file/item loaders fail — brief grace period.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self, !self.didPresentCanvas else { return }
            self.dismissPipeline()
        }
    }

    private func orderedTypeIdentifiers(for provider: NSItemProvider) -> [String] {
        let registered = provider.registeredTypeIdentifiers
        let preferred = Self.preferredImageTypes.filter { registered.contains($0) }
        let remainder = registered.filter { !preferred.contains($0) }
        return preferred + remainder
    }

    private func loadImage(
        from provider: NSItemProvider,
        typeIdentifiers: [String],
        index: Int,
        completion: @escaping () -> Void
    ) {
        guard index < typeIdentifiers.count else {
            completion()
            return
        }

        let typeIdentifier = typeIdentifiers[index]

        provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { [weak self] url, _ in
            if let url, let image = Self.imageFromFileURL(url) {
                DispatchQueue.main.async {
                    self?.presentCanvas(with: image)
                    completion()
                }
                return
            }

            provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, _ in
                if let data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self?.presentCanvas(with: image)
                        completion()
                    }
                    return
                }

                provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                    DispatchQueue.main.async {
                        if let image = Self.image(from: item) {
                            self?.presentCanvas(with: image)
                            completion()
                        } else {
                            self?.loadImage(
                                from: provider,
                                typeIdentifiers: typeIdentifiers,
                                index: index + 1,
                                completion: completion
                            )
                        }
                    }
                }
            }
        }
    }

    private static func imageFromFileURL(_ url: URL) -> UIImage? {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    private static func image(from item: NSSecureCoding?) -> UIImage? {
        if let image = item as? UIImage { return image }
        if let data = item as? Data { return UIImage(data: data) }
        if let url = item as? URL { return imageFromFileURL(url) }
        return nil
    }

    private func presentCanvas(with sharedImage: UIImage) {
        guard !didPresentCanvas else { return }
        didPresentCanvas = true

        let islandView = IslandCatchView(
            sharedImage: sharedImage,
            onDismiss: { [weak self] in self?.dismissPipeline() },
            onSaveData: { [weak self] data in self?.saveToAppGroup(imageData: data) }
        )

        if let hostingController {
            hostingController.rootView = islandView
            prepareOverlayEnvironment()
            return
        }

        let host = FullBleedHostingController(rootView: islandView)
        host.view.backgroundColor = .clear
        host.view.isOpaque = false
        host.view.clipsToBounds = false

        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        host.didMove(toParent: self)
        hostingController = host
        prepareOverlayEnvironment()
    }

    private func saveToAppGroup(imageData: Data) {
        guard let sharedURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.app.catch") else { return }
        let fileURL = sharedURL.appendingPathComponent("captured_media.jpg")
        try? imageData.write(to: fileURL)
    }

    private func dismissPipeline() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
