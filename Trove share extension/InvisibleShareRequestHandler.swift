import Foundation

/// Headless share extension — save assets before dismiss so writes actually finish.
final class InvisibleShareRequestHandler: NSObject, NSExtensionRequestHandling {

    func beginRequest(with context: NSExtensionContext) {
        let inputItems = context.inputItems

        AppGroupStorage.importSharedItems(from: inputItems) {
            context.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }
}
