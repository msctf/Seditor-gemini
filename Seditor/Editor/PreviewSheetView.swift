import SwiftUI
import WebKit

struct PreviewSheetView: View {
    let content: String
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            WebPreviewView(content: content)
                .navigationTitle("Live Preview")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", action: onClose)
                    }
                }
        }
        .preferredColorScheme(.dark)
    }
}

struct WebPreviewView: UIViewRepresentable {
    let content: String

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptEnabled = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.backgroundColor = .clear
        view.scrollView.indicatorStyle = .white
        view.loadHTMLString(content, baseURL: nil)
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.loadHTMLString(content, baseURL: nil)
    }
}
