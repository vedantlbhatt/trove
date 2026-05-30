import UIKit

/// Headless share extension — no UIViewController, so iOS never presents the dark sheet.
final class InvisibleShareRequestHandler: NSObject, NSExtensionRequestHandling {

    private static let appGroupID = "group.com.app.catch"
    private static let captureFilename = "captured_media.jpg"
    private static let pendingKey = "capture.pending"

    func beginRequest(with context: NSExtensionContext) {
        markCapturePending()
        beginAsyncSave(from: context)

        if let url = URL(string: "trove://capture") {
            context.open(url, completionHandler: nil)
        }

        context.completeRequest(returningItems: nil, completionHandler: nil)
    }

    private func beginAsyncSave(from context: NSExtensionContext) {
        guard let provider = firstProvider(in: context) else { return }
        provider.loadPreviewImage(options: nil) { [weak self] item, _ in
            if let image = item as? UIImage {
                self?.saveCaptureImage(image)
            }
        }
    }

    private func markCapturePending() {
        UserDefaults(suiteName: Self.appGroupID)?.set(true, forKey: Self.pendingKey)
    }

    private func saveCaptureImage(_ image: UIImage) {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID),
              let data = image.jpegData(compressionQuality: 0.85) else { return }
        try? data.write(to: container.appendingPathComponent(Self.captureFilename), options: .atomic)
    }

    private func firstProvider(in context: NSExtensionContext) -> NSItemProvider? {
        guard let items = context.inputItems as? [NSExtensionItem] else { return nil }
        return items.flatMap { $0.attachments ?? [] }.first
    }
}
