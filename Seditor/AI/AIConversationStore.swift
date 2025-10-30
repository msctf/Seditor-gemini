import Foundation

final class AIConversationStore {
    static let shared = AIConversationStore()

    private let fileManager = FileManager.default
    private let directory: URL
    private let queue = DispatchQueue(label: "dev.seditor.ai.conversation.store", qos: .utility)

    private init() {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        directory = base.appendingPathComponent("AIConversations", isDirectory: true)
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            #if DEBUG
            print("AIConversationStore: Failed creating directory:", error)
            #endif
        }
    }

    private func url(for key: String) -> URL {
        directory.appendingPathComponent(key).appendingPathExtension("json")
    }

    func load(for key: String) -> Data? {
        let url = url(for: key)
        return try? Data(contentsOf: url)
    }

    func save(_ data: Data, for key: String) {
        let url = url(for: key)
        queue.async {
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                #if DEBUG
                print("AIConversationStore: Failed saving conversation:", error)
                #endif
            }
        }
    }

    func remove(for key: String) {
        let url = url(for: key)
        queue.async {
            try? self.fileManager.removeItem(at: url)
        }
    }
}

