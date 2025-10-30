import UIKit

enum SyntaxHighlighter {
    static let baseAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.monospacedSystemFont(ofSize: 15, weight: .regular),
        .foregroundColor: UIColor(red: 0.86, green: 0.89, blue: 0.94, alpha: 1.0)
    ]

    static func highlight(text: String, language: CodeLanguage) -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: text, attributes: baseAttributes)
        guard !text.isEmpty else { return attributed }
        let fullRange = NSRange(location: 0, length: (text as NSString).length)

        func apply(pattern: String, color: UIColor, options: NSRegularExpression.Options = []) {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
            regex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
                guard let matchRange = match?.range else { return }
                attributed.addAttribute(.foregroundColor, value: color, range: matchRange)
            }
        }

        switch language {
        case .html:
            apply(pattern: "<!--[\\s\\S]*?-->", color: UIColor.systemGreen)
            apply(pattern: "<\\/?[a-zA-Z0-9\\-]+", color: UIColor.systemPurple)
            apply(pattern: "\\b[a-zA-Z:-]+(?=\\=)", color: UIColor.systemTeal)
            apply(pattern: "\"[^\"]*\"", color: UIColor.systemOrange)
        case .css:
            apply(pattern: "/\\*[\\s\\S]*?\\*/", color: UIColor.systemGreen)
            apply(pattern: "(?m)^[^{]+(?=\\{)", color: UIColor.systemPurple)
            apply(pattern: "\\b[a-zA-Z-]+(?=\\s*:\\s)", color: UIColor.systemTeal)
            apply(pattern: "(?<=:)\\s*[^;\\n]+", color: UIColor.systemBlue)
            apply(pattern: "\\b\\d+(?:\\.\\d+)?(px|rem|em|%)?", color: UIColor.systemOrange)
        case .javascript:
            apply(pattern: "\\b(let|const|var|function|class|if|else|switch|case|break|continue|return|for|while|do|try|catch|throw|await|async|import|from|export|default|new)\\b", color: UIColor.systemPurple)
            apply(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", color: UIColor.systemOrange)
            apply(pattern: "'(?:[^'\\\\]|\\\\.)*'", color: UIColor.systemOrange)
            apply(pattern: "`(?:[^`\\\\]|\\\\.)*`", color: UIColor.systemOrange)
            apply(pattern: "/\\/[^\n]*", color: UIColor.systemGreen)
            apply(pattern: "/\\*[\\s\\S]*?\\*/", color: UIColor.systemGreen)
            apply(pattern: "\\b\\d+(?:\\.\\d+)?\\b", color: UIColor.systemBlue)
        }

        return attributed
    }
}
