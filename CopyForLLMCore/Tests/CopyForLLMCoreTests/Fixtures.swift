import Foundation

/// Builds a temp directory tree from path → contents and cleans up on deinit.
final class FixtureTree {
    let root: URL

    init(name: String = "project", files: [String: Data]) throws {
        let base = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("copyforllm-tests-\(UUID().uuidString)")
        root = base.appendingPathComponent(name)
        for (path, data) in files {
            let url = root.appendingPathComponent(path)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try data.write(to: url)
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    convenience init(name: String = "project", texts: [String: String]) throws {
        try self.init(name: name, files: texts.mapValues { Data($0.utf8) })
    }

    func symlink(at path: String, to destination: String) throws {
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent(path),
            withDestinationURL: root.appendingPathComponent(destination)
        )
    }

    func url(_ path: String) -> URL {
        root.appendingPathComponent(path)
    }

    deinit {
        try? FileManager.default.removeItem(at: root.deletingLastPathComponent())
    }
}
