import SwiftUI

@main
struct BluchatApp: App {
    @StateObject private var mesh = MeshSession()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(mesh)
        }
    }
}
