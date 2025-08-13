import SwiftUI

@main
struct ZchatApp: App {
    @StateObject private var mesh = MeshSession()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(mesh)
        }
    }
}
