import Foundation
import Testing
@testable import CopyForLLMCore

@Suite struct ScannerTests {

    @Test func ignoresDefaultsGitignoreBinariesAndSymlinks() throws {
        let fixture = try FixtureTree(files: [
            "README.md": Data("# Hi\n".utf8),
            ".gitignore": Data("*.log\nbuild/\n".utf8),
            "src/main.py": Data("print(1)\n".utf8),
            "src/util.py": Data("x = 2\n".utf8),
            "app.log": Data("log\n".utf8),
            "build/out.txt": Data("out\n".utf8),
            "node_modules/pkg/index.js": Data("x\n".utf8),
            "image.png": Data([0x89, 0x50, 0x4E, 0x47]),
            "data.bin": Data([0x00, 0x01, 0x02, 0x03]),
        ])
        try fixture.symlink(at: "link", to: "src")

        let outcome = try FileScanner.scan(roots: [fixture.root])

        #expect(outcome.files.map(\.displayPath) == [".gitignore", "README.md", "src/main.py", "src/util.py"])
        // app.log, build/, image.png, node_modules/ are pruned by rules.
        #expect(outcome.ignoredCount == 4)
        let skipReasons = Set(outcome.skipped.map(\.reason))
        #expect(skipReasons == Set([SkipReason.binary, SkipReason.symlink]))

        #expect(TreeRenderer.render(outcome.trees) == """
        project/
        ├── .gitignore
        ├── README.md
        └── src/
            ├── main.py
            └── util.py
        """)
    }

    @Test func nestedGitignoreNegationWins() throws {
        let fixture = try FixtureTree(texts: [
            ".gitignore": "*.tmp\n",
            "a.tmp": "root tmp",
            "sub/.gitignore": "!special.tmp\n",
            "sub/special.tmp": "kept",
            "sub/other.tmp": "dropped",
        ])
        let outcome = try FileScanner.scan(roots: [fixture.root])
        let paths = outcome.files.map(\.displayPath)
        #expect(paths.contains("sub/special.tmp"))
        #expect(!paths.contains("a.tmp"))
        #expect(!paths.contains("sub/other.tmp"))
    }

    @Test func includeGlobsFilterFilesButKeepTraversal() throws {
        let fixture = try FixtureTree(texts: [
            "main.py": "1", "README.md": "2", "deep/nested/util.py": "3", "style.css": "4",
        ])
        let options = ScanOptions(ignore: IgnoreConfiguration(includeGlobs: ["*.py"]))
        let outcome = try FileScanner.scan(roots: [fixture.root], options: options)
        #expect(outcome.files.map(\.displayPath) == ["deep/nested/util.py", "main.py"])
    }

    @Test func excludeBeatsInclude() throws {
        let fixture = try FixtureTree(texts: ["main.py": "1", "util.py": "2"])
        let options = ScanOptions(ignore: IgnoreConfiguration(
            excludeGlobs: ["main.py"], includeGlobs: ["*.py"]
        ))
        let outcome = try FileScanner.scan(roots: [fixture.root], options: options)
        #expect(outcome.files.map(\.displayPath) == ["util.py"])
    }

    @Test func includeGlobOverridesDefaultIgnores() throws {
        let fixture = try FixtureTree(texts: ["app.log": "log", "main.py": "1"])
        // *.log would normally be a good default-exclude candidate via user rules:
        let options = ScanOptions(ignore: IgnoreConfiguration(
            includeGlobs: ["*.log"], defaultRules: ["*.log"]
        ))
        let outcome = try FileScanner.scan(roots: [fixture.root], options: options)
        #expect(outcome.files.map(\.displayPath) == ["app.log"])
    }

    @Test func perFileSizeCapSkips() throws {
        let fixture = try FixtureTree(texts: [
            "small.txt": "ok",
            "big.txt": String(repeating: "x", count: 4096),
        ])
        let options = ScanOptions(maxFileBytes: 1024)
        let outcome = try FileScanner.scan(roots: [fixture.root], options: options)
        #expect(outcome.files.map(\.displayPath) == ["small.txt"])
        #expect(outcome.skipped.first?.reason == .tooLarge)
    }

    @Test func explicitlySelectedFilesBypassIgnoreRules() throws {
        let fixture = try FixtureTree(texts: ["app.log": "log contents"])
        let options = ScanOptions(ignore: IgnoreConfiguration(defaultRules: ["*.log"]))
        let outcome = try FileScanner.scan(roots: [fixture.url("app.log")], options: options)
        #expect(outcome.files.map(\.displayPath) == ["app.log"])
    }

    @Test func multipleRootsArePrefixed() throws {
        let fixture = try FixtureTree(texts: ["one/a.txt": "a", "two/b.txt": "b"])
        let outcome = try FileScanner.scan(roots: [fixture.url("one"), fixture.url("two")])
        #expect(outcome.files.map(\.displayPath) == ["one/a.txt", "two/b.txt"])
    }

    @Test func unknownExtensionTextIsSniffedIn() throws {
        let fixture = try FixtureTree(texts: ["Makefile": "all:\n\ttrue\n", "notes.xyz": "plain text"])
        let outcome = try FileScanner.scan(roots: [fixture.root])
        #expect(outcome.files.map(\.displayPath) == ["Makefile", "notes.xyz"])
    }

    @Test func emptyDirectoriesDroppedFromTree() throws {
        let fixture = try FixtureTree(texts: ["src/main.py": "1", "empty/only.png": "not-text"])
        var outcome = try FileScanner.scan(roots: [fixture.root])
        // only.png is default-ignored, so "empty" has no included children.
        #expect(TreeRenderer.render(outcome.trees) == """
        project/
        └── src/
            └── main.py
        """)
        outcome = try FileScanner.scan(roots: [fixture.root])
        #expect(outcome.files.count == 1)
    }
}

@Suite struct BudgetTests {

    private func file(_ path: String, _ size: Int64) -> ScannedFile {
        ScannedFile(url: URL(fileURLWithPath: "/" + path), displayPath: path, sizeBytes: size, language: "")
    }

    @Test func maxFilesOmitsRest() {
        let selection = BudgetEnforcer.select(
            files: [file("a", 10), file("b", 10), file("c", 10)],
            limits: Limits(maxFiles: 2)
        )
        #expect(selection.selected.map(\.displayPath) == ["a", "b"])
        #expect(selection.omitted.map(\.displayPath) == ["c"])
        #expect(selection.hitLimit)
    }

    @Test func byteBudgetSkipsBigButKeepsSmallerLater() {
        let selection = BudgetEnforcer.select(
            files: [file("a", 500), file("big", 800), file("c", 400)],
            limits: Limits(maxTotalBytes: 1000)
        )
        #expect(selection.selected.map(\.displayPath) == ["a", "c"])
        #expect(selection.omitted.map(\.displayPath) == ["big"])
    }

    @Test func noLimitsSelectsEverything() {
        let selection = BudgetEnforcer.select(files: [file("a", 1), file("b", 2)], limits: Limits())
        #expect(selection.omitted.isEmpty)
        #expect(!selection.hitLimit)
    }
}

@Suite struct EncodingTests {

    @Test func utf8() {
        guard case .text(let s, let enc) = EncodingDetector.decode(Data("héllo".utf8)) else {
            Issue.record("expected text")
            return
        }
        #expect(s == "héllo")
        #expect(enc == .utf8)
    }

    @Test func utf8BOM() {
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(Data("hi".utf8))
        guard case .text(let s, _) = EncodingDetector.decode(data) else {
            Issue.record("expected text")
            return
        }
        #expect(s == "hi")
    }

    @Test func utf16LittleEndianBOM() {
        var data = Data([0xFF, 0xFE])
        data.append(contentsOf: [0x68, 0x00, 0x69, 0x00])  // "hi"
        guard case .text(let s, let enc) = EncodingDetector.decode(data) else {
            Issue.record("expected text")
            return
        }
        #expect(s.hasSuffix("hi"))
        #expect(enc == .utf16LittleEndian)
    }

    @Test func latin1Fallback() {
        let data = Data([0x63, 0x61, 0x66, 0xE9])  // "café" in Latin-1
        guard case .text(let s, let enc) = EncodingDetector.decode(data) else {
            Issue.record("expected text")
            return
        }
        #expect(s == "café")
        #expect(enc == .isoLatin1)
    }

    @Test func nullBytesMeanBinary() {
        guard case .binary = EncodingDetector.decode(Data([0x41, 0x00, 0x42])) else {
            Issue.record("expected binary")
            return
        }
    }
}
