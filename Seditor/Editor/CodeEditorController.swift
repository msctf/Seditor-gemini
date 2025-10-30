import UIKit
import Combine

@MainActor
final class CodeEditorController: ObservableObject {
    weak var container: CodeEditorContainer?

    func focus() {
        container?.textView.becomeFirstResponder()
    }

    func undo() {
        focus()
        container?.textView.undoManager?.undo()
        container?.publishState()
    }

    func redo() {
        focus()
        container?.textView.undoManager?.redo()
        container?.publishState()
    }

    func copy() {
        focus()
        container?.textView.copy(nil)
        container?.publishState()
    }

    func paste() {
        focus()
        container?.textView.paste(nil)
        container?.publishState()
    }

    func selectAll() {
        focus()
        container?.textView.selectAll(nil)
        container?.publishState()
    }
}
