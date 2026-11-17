import Foundation

public struct LinkPreview: Sendable, Equatable {
    public var title: String?
    public var imageData: Data?

    public init(title: String?, imageData: Data?) {
        self.title = title
        self.imageData = imageData
    }
}
