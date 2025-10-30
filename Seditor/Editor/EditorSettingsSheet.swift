import SwiftUI

struct EditorSettingsSheet: View {
    @Binding var preferences: EditorPreferences
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Editor Display") {
                    Toggle("Show line numbers", isOn: $preferences.showLineNumbers)
                    Toggle("Show status bar", isOn: $preferences.showStatusBar)
                }

                Section("Typography") {
                    sliderRow
                }
            }
            .navigationTitle("Editor Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var sliderRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Font size")
                Spacer()
                Text("\(Int(preferences.fontSize)) pt")
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: Binding(
                    get: { preferences.fontSize },
                    set: { preferences.fontSize = $0 }
                ),
                in: 10...24,
                step: 1
            )
        }
    }
}
