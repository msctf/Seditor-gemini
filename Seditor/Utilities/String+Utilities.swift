import Foundation

extension String {
    var lineCount: Int {
        guard !isEmpty else { return 0 }
        return components(separatedBy: .newlines).count
    }
}
