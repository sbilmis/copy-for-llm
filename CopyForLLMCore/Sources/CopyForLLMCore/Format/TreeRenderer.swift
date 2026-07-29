import Foundation

/// Renders the classic box-drawing directory tree.
public enum TreeRenderer {

    public static func render(_ roots: [FileNode]) -> String {
        var lines: [String] = []
        for root in roots {
            lines.append(root.isDirectory ? root.name + "/" : root.name)
            renderChildren(root.children, prefix: "", into: &lines)
        }
        return lines.joined(separator: "\n")
    }

    private static func renderChildren(_ children: [FileNode], prefix: String, into lines: inout [String]) {
        for (index, child) in children.enumerated() {
            let isLast = index == children.count - 1
            let connector = isLast ? "└── " : "├── "
            let name = child.isDirectory ? child.name + "/" : child.name
            lines.append(prefix + connector + name)
            if !child.children.isEmpty {
                let childPrefix = prefix + (isLast ? "    " : "│   ")
                renderChildren(child.children, prefix: childPrefix, into: &lines)
            }
        }
    }
}
