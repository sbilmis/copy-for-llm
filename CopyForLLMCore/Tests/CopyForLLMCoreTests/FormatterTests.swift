import Foundation
import Testing
@testable import CopyForLLMCore

@Suite struct FormatterTests {

    let payload = RenderPayload(
        template: nil,
        tree: "project/\n└── main.py",
        files: [RenderFile(displayPath: "main.py", language: "python", content: "print(1)\n")],
        omittedPaths: []
    )

    @Test func plain() {
        let out = PlainFormatter().render(payload)
        #expect(out == """
        project/
        └── main.py

        ===== main.py =====

        print(1)

        """)
    }

    @Test func markdown() {
        let out = MarkdownFormatter().render(payload)
        #expect(out == """
        ## Directory structure

        ```text
        project/
        └── main.py
        ```

        ## main.py

        ```python
        print(1)
        ```

        """)
    }

    @Test func markdownFenceCollision() {
        let content = "docs:\n```swift\nlet x = 1\n```\n"
        let fenced = MarkdownFormatter().fenced(content, language: "markdown")
        #expect(fenced.hasPrefix("````markdown\n"))
        #expect(fenced.hasSuffix("````"))
    }

    @Test func templatePrepended() {
        var p = payload
        p.template = "Review this code."
        let out = MarkdownFormatter().render(p)
        #expect(out.hasPrefix("Review this code.\n\n## Directory structure"))
    }

    @Test func xmlEscapes() {
        let p = RenderPayload(
            template: "a < b",
            tree: nil,
            files: [RenderFile(displayPath: "weird \"name\".swift", language: "swift",
                               content: "if a < b && c > d {}\n")]
        )
        let out = XMLFormatter().render(p)
        #expect(out.contains("<instructions>\na &lt; b\n</instructions>"))
        #expect(out.contains("path=\"weird &quot;name&quot;.swift\""))
        #expect(out.contains("if a &lt; b &amp;&amp; c &gt; d {}"))
        #expect(out.hasPrefix("<context>\n"))
        #expect(out.hasSuffix("</context>\n"))
    }

    @Test func json() throws {
        let out = JSONFormatter().render(payload)
        let data = try #require(out.data(using: .utf8))
        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let files = try #require(parsed?["files"] as? [[String: Any]])
        #expect(files.count == 1)
        #expect(files[0]["path"] as? String == "main.py")
        #expect(files[0]["content"] as? String == "print(1)\n")
        #expect(parsed?["tree"] as? String == "project/\n└── main.py")
    }

    @Test func omittedNotesAppear() {
        var p = payload
        p.omittedPaths = ["big1.txt", "big2.txt"]
        #expect(PlainFormatter().render(p).contains("2 file(s) omitted"))
        #expect(MarkdownFormatter().render(p).contains("> 2 file(s) omitted"))
        #expect(XMLFormatter().render(p).contains("<omitted_files count=\"2\">"))
    }
}

@Suite struct TreeRendererTests {

    @Test func rendersNestedTree() {
        let tree = FileNode(name: "project", isDirectory: true, children: [
            FileNode(name: "README.md", isDirectory: false),
            FileNode(name: "docs", isDirectory: true, children: [
                FileNode(name: "guide.md", isDirectory: false),
            ]),
            FileNode(name: "src", isDirectory: true, children: [
                FileNode(name: "main.py", isDirectory: false),
                FileNode(name: "util.py", isDirectory: false),
            ]),
        ])
        #expect(TreeRenderer.render([tree]) == """
        project/
        ├── README.md
        ├── docs/
        │   └── guide.md
        └── src/
            ├── main.py
            └── util.py
        """)
    }

    @Test func rendersFileRootsAndMultipleRoots() {
        let roots = [
            FileNode(name: "a.txt", isDirectory: false),
            FileNode(name: "lib", isDirectory: true, children: [
                FileNode(name: "x.py", isDirectory: false),
            ]),
        ]
        #expect(TreeRenderer.render(roots) == """
        a.txt
        lib/
        └── x.py
        """)
    }
}

@Suite struct RunReportTests {

    @Test func abbreviations() {
        #expect(RunReport.abbreviate(999) == "999")
        #expect(RunReport.abbreviate(1500) == "1.5k")
        #expect(RunReport.abbreviate(85000) == "85k")
        #expect(RunReport.abbreviate(2_000_000) == "2M")
    }
}
