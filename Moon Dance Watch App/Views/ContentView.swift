import SwiftData
import SwiftUI

/// Temporary home until milestone 3: problem counts and a link to the Bluetooth log.
struct ContentView: View {
    @Query private var problems: [Problem]
    @State private var showLog = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(HoldSet.allCases) { set in
                    LabeledContent(set.label, value: "\(problems.filter { $0.holdSet == set.rawValue }.count)")
                }
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
            showLog = RuntimeEnvironment.debugValue("openScreen") == "log"
        }
    }
}
