import SwiftUI

/// Temporary home for milestone 1: a link to the Bluetooth log.
struct ContentView: View {
    @State private var showLog = false

    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    BluetoothLogView()
                } label: {
                    Label("Bluetooth log", systemImage: "antenna.radiowaves.left.and.right")
                }
            }
            .navigationTitle("Moondance")
            .navigationDestination(isPresented: $showLog) { BluetoothLogView() }
        }
        .onAppear {
            #if DEBUG
            showLog = UserDefaults.standard.string(forKey: "openScreen") == "log"
            #endif
        }
    }
}
