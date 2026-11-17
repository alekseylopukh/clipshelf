import Foundation

public struct Representation: Sendable, Equatable {
    public var itemIndex: Int
    public var uti: String
    public var data: Data

    public init(itemIndex: Int, uti: String, data: Data) {
        self.itemIndex = itemIndex
        self.uti = uti
        self.data = data
    }
}
