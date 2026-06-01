import SwiftUI

struct ContentView: View {
    @StateObject private var store = AssetCanvasStore()
    @State private var panOffset = CGSize.zero
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        InfiniteDotCanvasView(assets: store.assets, panOffset: $panOffset)
            .onAppear { store.reload() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    store.reload()
                }
            }
    }
}

#Preview {
    ContentView()
}
