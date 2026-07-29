import Testing
@testable import CopyForLLMCore

@Suite struct GitignoreTests {

    private func verdict(_ lines: [String], _ path: String, isDir: Bool = false) -> Bool? {
        GitignoreFile(lines: lines, source: "test").verdict(relativePath: path, isDirectory: isDir)
    }

    @Test func basenameMatchesAtAnyDepth() {
        #expect(verdict(["*.log"], "app.log") == true)
        #expect(verdict(["*.log"], "sub/deep/app.log") == true)
        #expect(verdict(["*.log"], "app.log.txt") == nil)
    }

    @Test func negationLastMatchWins() {
        #expect(verdict(["*.log", "!keep.log"], "keep.log") == false)
        #expect(verdict(["*.log", "!keep.log"], "other.log") == true)
        #expect(verdict(["!keep.log", "*.log"], "keep.log") == true)  // order matters
    }

    @Test func directoryOnlyPatterns() {
        #expect(verdict(["build/"], "build", isDir: true) == true)
        #expect(verdict(["build/"], "build", isDir: false) == nil)   // file named build survives
        #expect(verdict(["build/"], "sub/build", isDir: true) == true)
    }

    @Test func anchoredPatterns() {
        #expect(verdict(["/todo.txt"], "todo.txt") == true)
        #expect(verdict(["/todo.txt"], "sub/todo.txt") == nil)
        #expect(verdict(["doc/*.md"], "doc/guide.md") == true)
        #expect(verdict(["doc/*.md"], "doc/sub/guide.md") == nil)
        #expect(verdict(["doc/*.md"], "other/guide.md") == nil)
    }

    @Test func doubleStarPatterns() {
        #expect(verdict(["**/logs"], "logs", isDir: true) == true)
        #expect(verdict(["**/logs"], "a/b/logs", isDir: true) == true)
        #expect(verdict(["logs/**"], "logs", isDir: true) == nil)    // contents, not the dir itself
        #expect(verdict(["logs/**"], "logs/a.txt") == true)
        #expect(verdict(["logs/**"], "logs/a/b.txt") == true)
        #expect(verdict(["a/**/b"], "a/b") == true)
        #expect(verdict(["a/**/b"], "a/x/y/b") == true)
    }

    @Test func commentsAndBlanksIgnored() {
        #expect(GitignoreFile(lines: ["# comment", "", "   "], source: "t").isEmpty)
        #expect(verdict(["\\#literal"], "#literal") == true)
    }

    @Test func trailingSpacesStripped() {
        #expect(verdict(["*.log   "], "app.log") == true)
    }
}
