import Foundation

struct EditorState {
    var canUndo: Bool
    var canRedo: Bool
    var line: Int
    var column: Int
}
