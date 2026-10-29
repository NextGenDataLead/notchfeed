import Foundation

/// A minimal element tree built with `XMLParser`. A parse error leaves the tree as far as it got,
/// and `isClosed` tells complete elements apart from ones cut off by the error.
final class XMLNode {
    enum Part {
        case text(String)
        case child(XMLNode)
    }

    let name: String
    let namespace: String
    let attributes: [String: String]
    private(set) var parts: [Part] = []
    private(set) var children: [XMLNode] = []
    fileprivate(set) var isClosed = false

    init(name: String, namespace: String, attributes: [String: String]) {
        self.name = name
        self.namespace = namespace
        self.attributes = attributes
    }

    func child(_ name: String, in namespaces: Set<String>) -> XMLNode? {
        children.first { $0.name == name && namespaces.contains($0.namespace) }
    }

    func children(_ name: String, in namespaces: Set<String>) -> [XMLNode] {
        children.filter { $0.name == name && namespaces.contains($0.namespace) }
    }

    /// Attribute by local name; matches prefixed keys such as `rdf:about` or `xml:base` too.
    func attribute(_ localName: String) -> String? {
        attributes[localName] ?? attributes.first { $0.key.hasSuffix(":" + localName) }?.value
    }

    /// All text of this element and its descendants, in document order.
    var textContent: String {
        parts.map { part in
            switch part {
            case .text(let text): text
            case .child(let node): node.textContent
            }
        }.joined()
    }

    fileprivate func append(_ text: String) {
        if case .text(let previous) = parts.last {
            parts[parts.count - 1] = .text(previous + text)
        } else {
            parts.append(.text(text))
        }
    }

    fileprivate func append(_ child: XMLNode) {
        children.append(child)
        parts.append(.child(child))
    }
}

final class XMLTreeBuilder: NSObject, XMLParserDelegate {
    private(set) var root: XMLNode?
    private(set) var failed = false
    private var stack: [XMLNode] = []

    static func build(_ data: Data) -> XMLTreeBuilder {
        let builder = XMLTreeBuilder()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.shouldResolveExternalEntities = false
        parser.delegate = builder
        builder.failed = !parser.parse()
        return builder
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        let node = XMLNode(name: elementName, namespace: namespaceURI ?? "", attributes: attributeDict)
        if let parent = stack.last {
            parent.append(node)
        } else if root == nil {
            root = node
        }
        stack.append(node)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        stack.popLast()?.isClosed = true
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        stack.last?.append(string)
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        stack.last?.append(String(decoding: CDATABlock, as: UTF8.self))
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: any Error) {
        failed = true
    }
}
