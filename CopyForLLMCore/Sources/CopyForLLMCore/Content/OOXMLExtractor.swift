import Foundation

/// Text extraction for Office Open XML files (.docx, .pptx, .xlsx).
///
/// All three are ZIP archives of XML. Rather than depending on Pandoc or a Python
/// toolchain — neither of which can run inside the sandboxed Quick Action
/// extensions — the text is pulled straight out of the XML parts.
enum OOXMLExtractor {

    // MARK: Word

    /// `word/document.xml`: paragraphs are `<w:p>`, runs of text are `<w:t>`.
    static func docxText(data: Data) throws -> String {
        let xml = try ZIPReader.contents(ofEntryNamed: "word/document.xml", in: data)
        let collected = XMLTextCollector.collect(
            xml, textElements: ["w:t"], breakElements: ["w:p", "w:br", "w:tab"]
        )
        guard !collected.isEmpty else { throw ExtractionError.noTextFound }
        return collected
    }

    // MARK: PowerPoint

    /// One section per slide, in slide order. Text lives in `<a:t>`.
    static func pptxText(data: Data) throws -> String {
        let slides = try ZIPReader.entries(in: data)
            .filter { $0.name.hasPrefix("ppt/slides/slide") && $0.name.hasSuffix(".xml") }
            .sorted { slideNumber($0.name) < slideNumber($1.name) }

        var sections: [String] = []
        for (index, slide) in slides.enumerated() {
            guard let xml = try? ZIPReader.contents(of: slide, in: data) else { continue }
            let text = XMLTextCollector.collect(
                xml, textElements: ["a:t"], breakElements: ["a:p", "a:br"]
            )
            if !text.isEmpty {
                sections.append("--- slide \(index + 1) ---\n\(text)")
            }
        }
        guard !sections.isEmpty else { throw ExtractionError.noTextFound }
        return sections.joined(separator: "\n\n")
    }

    private static func slideNumber(_ name: String) -> Int {
        let digits = name.drop(while: { !$0.isNumber }).prefix(while: { $0.isNumber })
        return Int(digits) ?? 0
    }

    // MARK: Excel

    /// Cells reference a shared string table when `t="s"`; otherwise the value is
    /// inline. Rows are emitted tab-separated so tables survive the trip.
    static func xlsxText(data: Data) throws -> String {
        let shared: [String]
        if let stringsXML = try? ZIPReader.contents(ofEntryNamed: "xl/sharedStrings.xml", in: data) {
            shared = SharedStringsParser.parse(stringsXML)
        } else {
            shared = []
        }

        let sheets = try ZIPReader.entries(in: data)
            .filter { $0.name.hasPrefix("xl/worksheets/sheet") && $0.name.hasSuffix(".xml") }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        var sections: [String] = []
        for (index, sheet) in sheets.enumerated() {
            guard let xml = try? ZIPReader.contents(of: sheet, in: data) else { continue }
            let rows = SheetParser.parse(xml, sharedStrings: shared)
            let body = rows
                .map { $0.joined(separator: "\t") }
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                .joined(separator: "\n")
            if !body.isEmpty {
                sections.append("--- sheet \(index + 1) ---\n\(body)")
            }
        }
        guard !sections.isEmpty else { throw ExtractionError.noTextFound }
        return sections.joined(separator: "\n\n")
    }
}

/// Concatenates the character data of chosen elements, inserting newlines when a
/// structural element closes.
private final class XMLTextCollector: NSObject, XMLParserDelegate {

    private let textElements: Set<String>
    private let breakElements: Set<String>
    private var capturing = 0
    private var current = ""
    private var lines: [String] = []

    private init(textElements: Set<String>, breakElements: Set<String>) {
        self.textElements = textElements
        self.breakElements = breakElements
    }

    static func collect(_ xml: Data, textElements: [String], breakElements: [String]) -> String {
        let collector = XMLTextCollector(
            textElements: Set(textElements), breakElements: Set(breakElements))
        let parser = XMLParser(data: xml)
        parser.delegate = collector
        parser.parse()
        collector.flush()
        return collector.lines
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private func flush() {
        if !current.isEmpty {
            lines.append(current)
            current = ""
        }
    }

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String]) {
        if textElements.contains(name) { capturing += 1 }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if capturing > 0 { current += string }
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?,
                qualifiedName: String?) {
        if textElements.contains(name) { capturing = max(0, capturing - 1) }
        if breakElements.contains(name) { flush() }
    }
}

/// `xl/sharedStrings.xml`: an ordered list of `<si>` entries, each holding `<t>` runs.
private final class SharedStringsParser: NSObject, XMLParserDelegate {

    private var strings: [String] = []
    private var current = ""
    private var capturing = false

    static func parse(_ xml: Data) -> [String] {
        let delegate = SharedStringsParser()
        let parser = XMLParser(data: xml)
        parser.delegate = delegate
        parser.parse()
        return delegate.strings
    }

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String]) {
        if name == "si" { current = "" }
        if name == "t" { capturing = true }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if capturing { current += string }
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?,
                qualifiedName: String?) {
        if name == "t" { capturing = false }
        if name == "si" { strings.append(current) }
    }
}

/// A worksheet: `<row>` of `<c>` cells. `t="s"` means the value indexes the shared
/// string table; `t="inlineStr"` carries its own `<t>`; anything else is a literal.
private final class SheetParser: NSObject, XMLParserDelegate {

    private let sharedStrings: [String]
    private var rows: [[String]] = []
    private var row: [String] = []
    private var cellType: String?
    private var value = ""
    private var capturing = false

    private init(sharedStrings: [String]) {
        self.sharedStrings = sharedStrings
    }

    static func parse(_ xml: Data, sharedStrings: [String]) -> [[String]] {
        let delegate = SheetParser(sharedStrings: sharedStrings)
        let parser = XMLParser(data: xml)
        parser.delegate = delegate
        parser.parse()
        return delegate.rows
    }

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String]) {
        switch name {
        case "row": row = []
        case "c":
            cellType = attributes["t"]
            value = ""
        case "v", "t": capturing = true
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if capturing { value += string }
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?,
                qualifiedName: String?) {
        switch name {
        case "v", "t":
            capturing = false
        case "c":
            if cellType == "s", let index = Int(value), sharedStrings.indices.contains(index) {
                row.append(sharedStrings[index])
            } else {
                row.append(value)
            }
            value = ""
        case "row":
            rows.append(row)
            row = []
        default: break
        }
    }
}
