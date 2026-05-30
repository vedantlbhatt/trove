import SwiftUI

@main
struct TroveApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    guard url.scheme == "trove" else { return }
                    CaptureFlyoverPresenter.presentCaptureAnimation()
                }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        guard url.scheme == "trove" else { return false }
        CaptureFlyoverPresenter.presentCaptureAnimation()
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if options.urlContexts.contains(where: { $0.url.scheme == "trove" }) {
            DispatchQueue.main.async {
                CaptureFlyoverPresenter.presentCaptureAnimation()
            }
        }
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}
