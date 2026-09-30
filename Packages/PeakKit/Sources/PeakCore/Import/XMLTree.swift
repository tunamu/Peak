import Foundation

/// A parsed XML element: enough of a DOM to read the parts of an .xlsx file. Names drop their namespace prefix
/// (`x:c` and `c` are both "c"), since writers differ in whether they use one.
final class XMLTree {
    let name: String
    let attributes: [String: String]
    private(set) var children: [XMLTree] = []
    /// Text directly inside the element.
    fileprivate(set) var text = ""

    init(name: String, attributes: [String: String]) {
        self.name = name
        self.attributes = attributes
    }

    func child(_ name: String) -> XMLTree? {
        children.first { $0.name == name }
    }

    func children(_ name: String) -> [XMLTree] {
        children.filter { $0.name == name }
    }

    /// Text of the element and everything inside it, skipping `skipping` elements (phonetic runs in Excel strings).
    func allText(skipping: Set<String> = []) -> String {
        children.reduce(into: text) { result, child in
            if !skipping.contains(child.name) { result += child.allText(skipping: skipping) }
        }
    }

    fileprivate func append(_ child: XMLTree) {
        children.append(child)
    }

    /// The root element of `data`, or nil if it is not well-formed XML. External entities are never loaded.
    static func parse(_ data: Data) -> XMLTree? {
        let builder = TreeBuilder()
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = builder
        return parser.parse() ? builder.root : nil
    }
}

private final class TreeBuilder: NSObject, XMLParserDelegate {
    var root: XMLTree?
    private var stack: [XMLTree] = []

    private static func local(_ name: String) -> String {
        name.split(separator: ":").last.map(String.init) ?? name
    }

    func parser(
        _ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?,
        attributes: [String: String] = [:]
    ) {
        var local: [String: String] = [:]
        for (key, value) in attributes {
            local[Self.local(key)] = value
        }
        let element = XMLTree(name: Self.local(elementName), attributes: local)
        stack.last?.append(element)
        if root == nil { root = element }
        stack.append(element)
    }

    func parser(
        _ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?
    ) {
        stack.removeLast()
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        stack.last?.text += string
    }
}
