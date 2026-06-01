import Foundation

/// Headless share extension — dismiss instantly, import assets in background.
final class InvisibleShareRequestHandler: NSObject, NSExtensionRequestHandling {

    func beginRequest(with context: NSExtensionContext) {
        let inputItems = context.inputItems
        context.completeRequest(returningItems: nil, completionHandler: nil)

        DispatchQueue.global(qos: .utility).async {
            AppGroupStorage.importSharedItems(from: inputItems)
        }
    }
}
