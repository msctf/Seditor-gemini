import SwiftUI
import UIKit

struct CodeEditorView: UIViewRepresentable {
    @Binding var text: String
    let language: CodeLanguage
    let controller: CodeEditorController
    let preferences: EditorPreferences
    let onStateChange: (EditorState) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> CodeEditorContainer {
        let container = CodeEditorContainer()
        container.configure()
        container.stateChange = onStateChange
        container.language = language
        container.preferences = preferences
        container.textView.delegate = context.coordinator
        context.coordinator.container = container
        controller.container = container
        container.setText(text, highlight: true)
        return container
    }

    func updateUIView(_ uiView: CodeEditorContainer, context: Context) {
        context.coordinator.parent = self
        uiView.language = language
        uiView.preferences = preferences
        controller.container = uiView
        if uiView.textView.text != text {
            uiView.setText(text, highlight: true)
        } else {
            uiView.syncScroll()
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: CodeEditorView
        weak var container: CodeEditorContainer?

        init(parent: CodeEditorView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            guard let container else { return }
            parent.text = textView.text
            container.refreshHighlight()
            container.publishState()
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            guard let container else { return }
            container.applyTypingAttributes()
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            container?.syncScroll()
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            container?.publishState()
        }
    }
}

// MARK: - Container

final class CodeEditorContainer: UIView {
    let lineNumberView = LineNumberRulerView()
    let textView = UITextView()

    var language: CodeLanguage = .html {
        didSet {
            if oldValue != language {
                refreshHighlight()
            }
        }
    }
    private var isHighlighting = false
    var stateChange: ((EditorState) -> Void)?
    var preferences: EditorPreferences = EditorPreferences() {
        didSet {
            applyPreferences()
        }
    }
    private var lineNumberWidthConstraint: NSLayoutConstraint?

    func configure() {
        backgroundColor = UIColor(red: 0.06, green: 0.07, blue: 0.09, alpha: 1.0)

        lineNumberView.translatesAutoresizingMaskIntoConstraints = false
        lineNumberView.backgroundColor = UIColor(red: 0.1, green: 0.11, blue: 0.16, alpha: 1.0)

        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.backgroundColor = UIColor(red: 0.07, green: 0.08, blue: 0.11, alpha: 1.0)
        textView.textColor = UIColor(red: 0.86, green: 0.89, blue: 0.94, alpha: 1.0)
        textView.keyboardDismissMode = .interactive
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        textView.smartInsertDeleteType = .no
        textView.indicatorStyle = .white
        textView.textContainerInset = UIEdgeInsets(top: 20, left: 18, bottom: 28, right: 24)
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.widthTracksTextView = false
        textView.textContainer.size = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.alwaysBounceVertical = true
        textView.alwaysBounceHorizontal = true
        if #available(iOS 11.0, *) {
            textView.contentInsetAdjustmentBehavior = .never
        }
        textView.font = UIFont.monospacedSystemFont(ofSize: 15, weight: .regular)

        addSubview(lineNumberView)
        addSubview(textView)

        let widthConstraint = lineNumberView.widthAnchor.constraint(equalToConstant: 56)
        lineNumberWidthConstraint = widthConstraint

        NSLayoutConstraint.activate([
            lineNumberView.leadingAnchor.constraint(equalTo: leadingAnchor),
            lineNumberView.topAnchor.constraint(equalTo: topAnchor),
            lineNumberView.bottomAnchor.constraint(equalTo: bottomAnchor),
            widthConstraint,

            textView.leadingAnchor.constraint(equalTo: lineNumberView.trailingAnchor),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor),
            textView.topAnchor.constraint(equalTo: topAnchor),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        lineNumberView.contentInsetTop = textView.textContainerInset.top
        applyTypingAttributes()
        applyPreferences()
    }

    func setText(_ text: String, highlight: Bool) {
        textView.text = text
        if highlight {
            refreshHighlight()
        } else {
            refreshLineNumbers()
            publishState()
        }
    }

    func refreshHighlight() {
        guard !isHighlighting else { return }
        isHighlighting = true
        let selectedRange = textView.selectedRange
        let contentOffset = textView.contentOffset
        textView.attributedText = SyntaxHighlighter.highlight(text: textView.text, language: language)
        textView.selectedRange = selectedRange
        textView.setContentOffset(contentOffset, animated: false)
        applyTypingAttributes()
        isHighlighting = false
        refreshLineNumbers()
        publishState()
    }

    func applyTypingAttributes() {
        var attributes = SyntaxHighlighter.baseAttributes
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 4
        paragraph.minimumLineHeight = (textView.font?.lineHeight ?? 18) + 2
        paragraph.maximumLineHeight = paragraph.minimumLineHeight
        attributes[.paragraphStyle] = paragraph
        textView.typingAttributes = attributes
    }

    func syncScroll() {
        refreshLineNumbers()
        publishState()
    }

    private func refreshLineNumbers() {
        guard preferences.showLineNumbers else { return }
        lineNumberView.font = textView.font ?? UIFont.monospacedSystemFont(ofSize: 15, weight: .regular)
        lineNumberView.textColor = UIColor(white: 0.7, alpha: 1.0)
        lineNumberView.text = textView.text
        lineNumberView.contentOffset = textView.contentOffset
        lineNumberView.setNeedsDisplay()
    }

    func publishState() {
        guard let stateChange else { return }
        let cursor = textView.selectedRange.location
        let substring = (textView.text as NSString).substring(to: min(cursor, textView.text.count))
        let segments = substring.components(separatedBy: "\n")
        let line = max(1, segments.count)
        let column = (segments.last?.count ?? 0) + 1
        stateChange(
            EditorState(
                canUndo: textView.undoManager?.canUndo ?? false,
                canRedo: textView.undoManager?.canRedo ?? false,
                line: line,
                column: column
            )
        )
    }

    private func applyPreferences() {
        let font = UIFont.monospacedSystemFont(ofSize: CGFloat(preferences.fontSize), weight: .regular)
        if textView.font != font {
            textView.font = font
            applyTypingAttributes()
        }
        lineNumberView.isHidden = !preferences.showLineNumbers
        lineNumberWidthConstraint?.constant = preferences.showLineNumbers ? 56 : 0
        if preferences.showLineNumbers {
            refreshLineNumbers()
        } else {
            lineNumberView.text = ""
            lineNumberView.setNeedsDisplay()
        }
        setNeedsLayout()
        layoutIfNeeded()
    }
}

// MARK: - Line Number Ruler

final class LineNumberRulerView: UIView {
    var text: String = "" {
        didSet { setNeedsDisplay() }
    }
    var contentOffset: CGPoint = .zero {
        didSet { setNeedsDisplay() }
    }
    var font: UIFont = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular) {
        didSet { setNeedsDisplay() }
    }
    var textColor: UIColor = UIColor(white: 0.7, alpha: 1.0)
    var contentInsetTop: CGFloat = 20 {
        didSet { setNeedsDisplay() }
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.setFillColor((backgroundColor ?? UIColor.clear).cgColor)
        context.fill(rect)

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraph
        ]

        let lines = max(1, text.components(separatedBy: "\n").count)
        let lineHeight = font.lineHeight + 4
        let offsetY = contentOffset.y + contentInsetTop
        let firstVisibleLine = max(Int((offsetY - contentInsetTop) / lineHeight), 0)
        let visibleLineCount = Int(ceil((rect.height + offsetY) / lineHeight)) + 2
        let lastVisibleLine = min(lines, firstVisibleLine + visibleLineCount)

        for index in firstVisibleLine..<lastVisibleLine {
            let y = CGFloat(index) * lineHeight - contentOffset.y + 2
            let number = "\(index + 1)" as NSString
            let drawRect = CGRect(x: 0, y: y, width: rect.width - 8, height: lineHeight)
            number.draw(in: drawRect, withAttributes: attributes)
        }

        context.setFillColor(UIColor.white.withAlphaComponent(0.08).cgColor)
        context.fill(CGRect(x: rect.width - 1, y: rect.minY, width: 1, height: rect.height))
    }
}
