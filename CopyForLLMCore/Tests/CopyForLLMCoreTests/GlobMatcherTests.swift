import Testing
@testable import CopyForLLMCore

@Suite struct GlobMatcherTests {

    @Test(arguments: [
        ("*.py", "main.py", true),
        ("*.py", "main.pyc", false),
        ("*", "anything", true),
        ("?at", "cat", true),
        ("?at", "chat", false),
        ("[a-c]at", "bat", true),
        ("[a-c]at", "dat", false),
        ("[!a-c]at", "dat", true),
        ("[!a-c]at", "bat", false),
        ("a*b*c", "aXbYc", true),
        ("a*b*c", "aXcYb", false),
        ("main.py", "main.py", true),
        ("", "", true),
        ("*", "", true),
        ("test[", "test[", true),          // unclosed class is a literal
        ("\\*", "*", true),                // escaped star is a literal
        ("\\*", "x", false),
    ])
    func segment(_ pattern: String, _ text: String, _ expected: Bool) {
        #expect(GlobMatcher.matchSegment(pattern, text) == expected)
    }

    @Test(arguments: [
        (["**", "*.o"], ["a", "b", "c.o"], true),
        (["**", "*.o"], ["c.o"], true),
        (["**", "*.o"], ["a", "c.txt"], false),
        (["src", "**", "test"], ["src", "test"], true),           // ** matches zero segments
        (["src", "**", "test"], ["src", "a", "b", "test"], true),
        (["src", "**", "test"], ["other", "test"], false),
        (["doc", "*.md"], ["doc", "guide.md"], true),
        (["doc", "*.md"], ["doc", "sub", "guide.md"], false),     // * doesn't cross /
        (["**"], ["anything", "at", "all"], true),
    ])
    func path(_ pattern: [String], _ path: [String], _ expected: Bool) {
        #expect(GlobMatcher.matchPath(pattern, path) == expected)
    }
}
