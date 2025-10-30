import SwiftUI
import UniformTypeIdentifiers

struct CodeFile: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var language: CodeLanguage
    var content: String
    var folderID: UUID?

    init(id: UUID = UUID(), name: String, language: CodeLanguage, content: String, folderID: UUID? = nil) {
        self.id = id
        self.name = name
        self.language = language
        self.content = content
        self.folderID = folderID
    }

    static let demoFiles: [CodeFile] = []

    static let starterProject: [CodeFile] = [
        CodeFile(name: "index.html", language: .html, content: CodeLanguage.html.template),
        CodeFile(name: "styles.css", language: .css, content: CodeLanguage.css.template),
        CodeFile(name: "scripts.js", language: .javascript, content: CodeLanguage.javascript.template)
    ]
}

struct CodeFolder: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

enum CodeLanguage: String, CaseIterable, Identifiable, Codable {
    case html
    case css
    case javascript

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .html: return "HTML"
        case .css: return "CSS"
        case .javascript: return "JavaScript"
        }
    }

    var fileExtension: String {
        switch self {
        case .html: return "html"
        case .css: return "css"
        case .javascript: return "js"
        }
    }

    var iconName: String {
        switch self {
        case .html: return "chevron.left.slash.chevron.right"
        case .css: return "paintbrush.pointed.fill"
        case .javascript: return "curlybraces"
        }
    }

    var accentColor: Color {
        switch self {
        case .html: return .accentPink
        case .css: return .accentTeal
        case .javascript: return .accentYellow
        }
    }

    var template: String {
        switch self {
        case .html:
            return """
            <header class="hero">
              <p class="eyebrow">Seditor Workshop</p>
              <h1>Craft interfaces in minutes.</h1>
              <p>Structure your web experience with clean, accessible markup and preview changes instantly.</p>
              <button id="cta">See tip</button>
            </header>
            <main class="grid">
              <article>
                <h2>Foundation</h2>
                <p>Organise content with semantic sections to aid navigation and SEO.</p>
              </article>
              <article>
                <h2>Expression</h2>
                <p>Blend layout, colour, and typography to match your brand tone.</p>
              </article>
              <article>
                <h2>Emotion</h2>
                <p>Use animation and micro-interactions to guide attention.</p>
              </article>
            </main>
            <footer class="credits">
              Built in Seditor • Dark-space palette demo
            </footer>
            """
        case .css:
            return """
            :root {
              color-scheme: dark;
              font-family: "Inter", -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
              --bg: #05060a;
              --panel: rgba(18, 20, 30, 0.92);
              --accent: #7a5cff;
              --accent-soft: rgba(122, 92, 255, 0.18);
              --text: #f5f7ff;
              --muted: rgba(245, 247, 255, 0.6);
            }

            * {
              margin: 0;
              padding: 0;
              box-sizing: border-box;
            }

            body {
              min-height: 100vh;
              background: radial-gradient(circle at top left, rgba(62, 77, 255, 0.24), transparent), var(--bg);
              color: var(--text);
              line-height: 1.6;
              padding: 72px 24px 96px;
              display: flex;
              flex-direction: column;
              gap: 48px;
            }

            .hero {
              max-width: 720px;
              margin: 0 auto;
              text-align: center;
              display: grid;
              gap: 16px;
            }

            .hero .eyebrow {
              text-transform: uppercase;
              letter-spacing: 0.28rem;
              font-size: 0.72rem;
              color: var(--muted);
            }

            h1 {
              font-size: clamp(2.75rem, 8vw, 3.6rem);
              font-weight: 800;
            }

            button {
              justify-self: center;
              background: linear-gradient(120deg, #4ee0c6, var(--accent));
              border: none;
              border-radius: 999px;
              padding: 14px 32px;
              color: #05060a;
              font-weight: 600;
              cursor: pointer;
              transition: transform 0.2s ease, box-shadow 0.2s ease;
              box-shadow: 0 18px 40px rgba(122, 92, 255, 0.28);
            }

            button:hover {
              transform: translateY(-2px);
            }

            .grid {
              display: grid;
              max-width: 960px;
              margin: 0 auto;
              gap: 20px;
              grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
            }

            article {
              padding: 24px;
              border-radius: 20px;
              background: var(--panel);
              border: 1px solid var(--accent-soft);
              box-shadow: 0 24px 50px rgba(6, 9, 20, 0.35);
              display: grid;
              gap: 12px;
            }

            article h2 {
              font-size: 1.25rem;
              font-weight: 700;
            }

            .credits {
              text-align: center;
              font-size: 0.9rem;
              color: var(--muted);
              margin-top: auto;
            }
            """
        case .javascript:
            return """
            const cta = document.querySelector("#cta");
            const notes = [
              "Tip • Keyboard shortcuts keep you in flow. Map your favourites.",
              "Tip • Combine CSS clamp() and fluid units for flexible type scales.",
              "Tip • Debounce expensive events in JavaScript to keep renders smooth.",
              "Tip • Experiment with scroll-driven animation using the View API."
            ];

            cta.addEventListener("click", () => {
              const card = document.createElement("article");
              card.innerHTML = `
                <h2>Workbench Insight</h2>
                <p>${notes[Math.floor(Math.random() * notes.length)]}</p>
              `;
              document.querySelector(".grid").appendChild(card);
              card.scrollIntoView({ behavior: "smooth", block: "center" });
            });
            """
        }
    }

    var templatePreview: String {
        switch self {
        case .html: return "Hero, grid, and footer layout scaffold."
        case .css: return "Dark-space palette with glass panels and gradients."
        case .javascript: return "Interactive tip cards appended to the grid."
        }
    }

    var placeholder: String {
        switch self {
        case .html: return "index"
        case .css: return "styles"
        case .javascript: return "scripts"
        }
    }

    static func guess(from fileExtension: String) -> CodeLanguage? {
        switch fileExtension.lowercased() {
        case "html", "htm": return .html
        case "css": return .css
        case "js", "mjs": return .javascript
        default: return nil
        }
    }

    static var supportedContentTypes: [UTType] {
        var types: [UTType] = []
        if let html = UTType(filenameExtension: "html") { types.append(html) }
        if let htm = UTType(filenameExtension: "htm") { types.append(htm) }
        if let css = UTType(filenameExtension: "css") { types.append(css) }
        if let js = UTType(filenameExtension: "js") { types.append(js) }
        types.append(.plainText)
        return types
    }
}
