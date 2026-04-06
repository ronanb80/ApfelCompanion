import SwiftUI

@main
struct UlogApp: App {
    @State private var apfelService = ApfelService()

    var body: some Scene {
        WindowGroup("Ulog") {
            ContentView(apfelService: apfelService)
        }
        .defaultSize(width: 600, height: 700)
    }
}
