import SwiftUI

@main
struct IOLCalcApp: App {
    init() {
        #if os(macOS) && DEBUG
        DebugSnapshot.runHeadlessIfRequested()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        #if os(macOS)
        .defaultSize(width: 1100, height: 900)
        #endif
    }
}
