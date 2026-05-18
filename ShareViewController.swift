// ShareViewController.swift
// Share Extension entry point
//
// IMPORTANT: Replace the APP_GROUP_IDENTIFIER constant below with your real App Group identifier,
// e.g. "group.com.yourcompany.catchapp" and ensure both the main app target and the Share Extension
// have the App Group capability enabled with the exact same identifier.

import UIKit
import SwiftUI
import MobileCoreServices
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    // MARK: - Properties
    private var hostingController: UIHostingController<IslandCatchView>?
    private let viewModel = IslandCatchViewModel()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        modalPresentationStyle = .overFullScreen
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        embedSwiftUIViewIfNeeded()
        prepareInitialPreviewIfPossible()
    }

    // MARK: - Setup UI
    private func embedSwiftUIViewIfNeeded() {
        guard hostingController == nil else { return }

        // Wiring callbacks from SwiftUI to UIKit pipeline
        viewModel.onRequestImport = { [weak self] completion in
            self?.extractAndStoreFromExtensionContext { success in
                completion(success)
            }
        }
        viewModel.onFinish = { [weak self] in
            guard let self else { return }
            self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }

        let rootView = IslandCatchView(viewModel: viewModel)
        let host = UIHostingController(rootView: rootView)
        host.view.backgroundColor = .clear
        host.view.isOpaque = false

        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)

        hostingController = host
    }

    // MARK: - Preview bootstrap (best-effort)
    private func prepareInitialPreviewIfPossible() {
        // Attempt to derive a lightweight preview image or icon from the first attachment
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return }
        for item in items {
            guard let providers = item.attachments else { continue }
            for provider in providers {
                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    provider.loadPreviewImage(options: nil) { [weak self] preview, _ in
                        DispatchQueue.main.async {
                            if let image = preview as? UIImage {
                                self?.viewModel.previewImage = image
                            }
                        }
                    }
                    return
                }
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    // Use a generic link glyph if only a URL is shared
                    DispatchQueue.main.async { [weak self] in
                        self?.viewModel.previewGlyph = .link
                    }
                    return
                }
                if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    DispatchQueue.main.async { [weak self] in
                        self?.viewModel.previewGlyph = .doc
                    }
                    return
                }
            }
        }
    }

    // MARK: - Data Extraction & Storage
    private func extractAndStoreFromExtensionContext(completion: @escaping (Bool) -> Void) {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            completion(false)
            return
        }

        let dispatchGroup = DispatchGroup()
        var success = false

        for item in items {
            guard let providers = item.attachments else { continue }
            for provider in providers {
                // Try image first
                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    dispatchGroup.enter()
                    provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, error in
                        defer { dispatchGroup.leave() }
                        if let error { print("ShareExt: image load error: \(error)") }
                        guard let item else { return }

                        if let url = item as? URL { // e.g. file URL to image
                            if let savedURL = AppGroupStorage.saveFile(at: url) {
                                success = true
                                AppGroupStorage.appendInboxRecord(.file(url: savedURL))
                            }
                        } else if let image = item as? UIImage {
                            if let savedURL = AppGroupStorage.saveImage(image) {
                                success = true
                                AppGroupStorage.appendInboxRecord(.file(url: savedURL))
                            }
                        } else if let data = item as? Data {
                            if let savedURL = AppGroupStorage.saveData(data, suggestedName: "shared-image.jpg") {
                                success = true
                                AppGroupStorage.appendInboxRecord(.file(url: savedURL))
                            }
                        }
                    }
                    continue
                }

                // Try URL (web link)
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    dispatchGroup.enter()
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, error in
                        defer { dispatchGroup.leave() }
                        if let error { print("ShareExt: url load error: \(error)") }
                        guard let url = item as? URL else { return }
                        AppGroupStorage.appendInboxRecord(.link(url: url))
                        success = true
                    }
                    continue
                }

                // Try generic file URL
                if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    dispatchGroup.enter()
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                        defer { dispatchGroup.leave() }
                        if let error { print("ShareExt: file load error: \(error)") }
                        guard let fileURL = item as? URL else { return }
                        if let savedURL = AppGroupStorage.saveFile(at: fileURL) {
                            success = true
                            AppGroupStorage.appendInboxRecord(.file(url: savedURL))
                        }
                    }
                    continue
                }
            }
        }

        dispatchGroup.notify(queue: .main) {
            completion(success)
        }
    }
}
