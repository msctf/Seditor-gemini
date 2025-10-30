import SwiftUI

struct EditorWorkspaceView: View {
    @Binding var file: CodeFile
    let onReset: () -> Void
    let preferences: EditorPreferences

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var controller = CodeEditorController()
    @State private var editorState = EditorState(canUndo: false, canRedo: false, line: 1, column: 1)

    var body: some View {
        VStack(spacing: 0) {
            header
            CodeEditorView(
                text: $file.content,
                language: file.language,
                controller: controller,
                preferences: preferences
            ) { state in
                editorState = state
            }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if preferences.showStatusBar {
                Divider().overlay(Color.white.opacity(0.05))
                statusBar
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.07, green: 0.08, blue: 0.11))
        .onAppear {
            DispatchQueue.main.async {
                controller.focus()
            }
        }
    }

    private var header: some View {
        HStack(spacing: headerSpacing) {
            HStack(spacing: 14) {
                Image(systemName: file.language.iconName)
                    .font(.headline)
                    .foregroundStyle(file.language.accentColor)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
                VStack(alignment: .leading, spacing: 4) {
                    Text(file.name)
                        .font(.headline.monospaced())
                        .foregroundStyle(.white.opacity(0.88))
                    if isRegularWidth {
                        Text(file.language.displayName.uppercased())
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
            }
            Spacer()

            HStack(spacing: actionSpacing) {
                headerButton(icon: "arrow.uturn.backward", disabled: !editorState.canUndo) {
                    controller.undo()
                }
                headerButton(icon: "arrow.uturn.forward", disabled: !editorState.canRedo) {
                    controller.redo()
                }
                headerButton(icon: "doc.on.doc") {
                    controller.copy()
                }
                headerButton(icon: "doc.on.clipboard") {
                    controller.paste()
                }
                headerButton(icon: "square.dashed") {
                    controller.selectAll()
                }
                headerButton(icon: "arrow.counterclockwise") {
                    onReset()
                }
            }
        }
        .padding(.horizontal, isRegularWidth ? 28 : 20)
        .padding(.vertical, isRegularWidth ? 14 : 12)
        .background(Color(red: 0.09, green: 0.1, blue: 0.14))
    }

    private func headerButton(icon: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(disabled ? .white.opacity(0.3) : .white.opacity(0.85))
                .frame(width: isRegularWidth ? 32 : 28, height: isRegularWidth ? 32 : 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(disabled ? 0.05 : 0.12))
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private var statusBar: some View {
        HStack(spacing: 24) {
            Text("Ln \(editorState.line)  Col \(editorState.column)")
            Text("\(file.language.displayName.uppercased()) | UTF-8")
        }
        .font(.caption2.monospaced())
        .foregroundColor(.white.opacity(0.55))
        .padding(.horizontal, isRegularWidth ? 28 : 20)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.25))
    }

    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

    private var headerSpacing: CGFloat {
        isRegularWidth ? 24 : 18
    }

    private var actionSpacing: CGFloat {
        isRegularWidth ? 16 : 12
    }
}
