import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section("Development") {
                LabeledContent("Data Source", value: "Local mock assignments")
                Text("Brightspace connection and synchronization will be added in a later milestone.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 480, height: 220)
    }
}

