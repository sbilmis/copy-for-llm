import Foundation
import Testing
@testable import CopyForLLMCore

@Suite struct PipelineTests {

    private func fixture() throws -> FixtureTree {
        try FixtureTree(texts: [
            "README.md": "# Demo\n",
            "src/main.py": "print(1)\n",
            "src/util.py": "x = 2\n",
        ])
    }

    @Test func autoModeOnFolderGivesTreeAndContents() async throws {
        let f = try fixture()
        let output = try await CopyPipeline.run(CopyRequest(roots: [f.root]))
        #expect(output.text.contains("## Directory structure"))
        #expect(output.text.contains("## src/main.py"))
        #expect(output.text.contains("```python\nprint(1)\n```"))
        #expect(output.report.filesCopied == 3)
        #expect(output.report.estimatedTokens > 0)
    }

    @Test func autoModeOnFilesGivesContentsOnly() async throws {
        let f = try fixture()
        let output = try await CopyPipeline.run(
            CopyRequest(roots: [f.url("src/main.py")], format: .plain)
        )
        #expect(output.text == "===== main.py =====\n\nprint(1)\n")
        #expect(!output.text.contains("Directory structure"))
    }

    @Test func treeModeHasNoContents() async throws {
        let f = try fixture()
        let output = try await CopyPipeline.run(
            CopyRequest(roots: [f.root], mode: .tree, format: .plain)
        )
        #expect(output.text == """
        project/
        ├── README.md
        └── src/
            ├── main.py
            └── util.py

        """)
    }

    @Test func pathsMode() async throws {
        let f = try fixture()
        let output = try await CopyPipeline.run(
            CopyRequest(roots: [f.url("src/main.py"), f.url("README.md")], mode: .paths, pathMode: .nameOnly)
        )
        #expect(output.text == "README.md\nmain.py\n")
    }

    @Test func charBudgetOmitsOverflow() async throws {
        let f = try FixtureTree(texts: [
            "a.txt": String(repeating: "a", count: 100),
            "b.txt": String(repeating: "b", count: 100),
        ])
        var request = CopyRequest(roots: [f.root], format: .plain)
        request.limits = Limits(maxTotalChars: 150)
        let output = try await CopyPipeline.run(request)
        #expect(output.report.omittedByBudget == ["b.txt"])
        #expect(output.text.contains("1 file(s) omitted"))
    }

    @Test func binaryOnlySelectionThrows() async throws {
        let f = try FixtureTree(files: ["blob.bin": Data([0x00, 0x01])])
        await #expect(throws: CopyPipelineError.self) {
            _ = try await CopyPipeline.run(
                CopyRequest(roots: [f.url("blob.bin")], mode: .contents)
            )
        }
    }

    @Test func templateFlowsThrough() async throws {
        let f = try fixture()
        var request = CopyRequest(roots: [f.root], format: .xml)
        request.template = "Review this code."
        let output = try await CopyPipeline.run(request)
        #expect(output.text.contains("<instructions>\nReview this code.\n</instructions>"))
    }
}

@Suite struct SettingsTests {

    @Test func settingsRoundTripThroughStore() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("copyforllm-settings-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SharedStore(directory: dir)

        var settings = store.loadSettings()
        #expect(settings.defaultFormat == .markdown)
        settings.defaultFormat = .xml
        settings.limits.maxFiles = 42
        try store.saveSettings(settings)

        let reloaded = store.loadSettings()
        #expect(reloaded.defaultFormat == .xml)
        #expect(reloaded.limits.maxFiles == 42)
        #expect(reloaded.templates.count == Template.builtIns.count)
    }

    @Test func tolerantDecodingFillsDefaults() throws {
        let json = #"{"defaultFormat":"xml"}"#
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
        #expect(settings.defaultFormat == .xml)
        #expect(settings.respectGitignore)
        #expect(!settings.ignoreRules.isEmpty)
    }

    @Test func handoffIsConsumedOnRead() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("copyforllm-handoff-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SharedStore(directory: dir)

        try store.writeHandoff(SelectionHandoff(paths: ["/tmp/x"]))
        #expect(store.takeHandoff()?.paths == ["/tmp/x"])
        #expect(store.takeHandoff() == nil)
    }

    @Test func presetOverridesSettings() {
        let settings = AppSettings()
        let preset = Preset(name: "Py", format: .xml, includeGlobs: ["*.py"])
        let request = settings.request(roots: [URL(fileURLWithPath: "/tmp")], mode: .auto, preset: preset)
        #expect(request.format == .xml)
        #expect(request.ignore.includeGlobs == ["*.py"])
        #expect(request.ignore.respectGitignore)
    }
}
