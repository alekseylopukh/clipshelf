import Foundation

public struct CardMetadata: Codable, Sendable, Equatable {
    public var url: String?
    public var pixelWidth: Int?
    public var pixelHeight: Int?
    public var fileNames: [String]?
    public var totalFileSize: Int?
    public var color: String?
    public var characterCount: Int?
    public var wordCount: Int?
    public var lineCount: Int?
    public var typeIdentifier: String?
    public var pageTitle: String?

    public init(
        url: String? = nil,
        pixelWidth: Int? = nil,
        pixelHeight: Int? = nil,
        fileNames: [String]? = nil,
        totalFileSize: Int? = nil,
        color: String? = nil,
        characterCount: Int? = nil,
        wordCount: Int? = nil,
        lineCount: Int? = nil,
        typeIdentifier: String? = nil,
        pageTitle: String? = nil
    ) {
        self.url = url
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.fileNames = fileNames
        self.totalFileSize = totalFileSize
        self.color = color
        self.characterCount = characterCount
        self.wordCount = wordCount
        self.lineCount = lineCount
        self.typeIdentifier = typeIdentifier
        self.pageTitle = pageTitle
    }
}
