import SwiftUI

@main
struct IOLCalcApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        #if os(macOS)
        .defaultSize(width: 1100, height: 900)
        #endif
    }
}
