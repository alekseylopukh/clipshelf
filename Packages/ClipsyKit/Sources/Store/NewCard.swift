import Foundation

public struct NewCard: Sendable {
    public var kind: CardKind
    /// in original pasteboard order: items by index, types within an item in their original order
    public var representations: [Representation]
    public var contentHash: Data
    public var previewText: String?
    public var metadata: String?
    public var sourceApp: SourceApp
    public var searchBody: String?
    public var url: String?
    public var fileNames: [String]

    public init(
        kind: CardKind,
        representations: [Representation],
        contentHash: Data,
        previewText: String?,
        metadata: String?,
        sourceApp: SourceApp,
        searchBody: String? = nil,
        url: String? = nil,
        fileNames: [String] = []
    ) {
        self.kind = kind
        self.representations = representations
        self.contentHash = contentHash
        self.previewText = previewText
        self.metadata = metadata
        self.sourceApp = sourceApp
        self.searchBody = searchBody
        self.url = url
        self.fileNames = fileNames
    }
}

extension NewCard {
    var byteSize: Int {
        representations.reduce(0) { $0 + $1.data.count }
    }

    var joinedFileNames: String? {
        fileNames.isEmpty ? nil : fileNames.joined(separator: "\n")
    }
}
