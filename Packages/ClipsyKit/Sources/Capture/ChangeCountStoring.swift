import Foundation

@MainActor
public protocol ChangeCountStoring: AnyObject {
    var lastHandledChangeCount: Int? { get set }
}

extension UserDefaults: ChangeCountStoring {
    private static let lastHandledChangeCountKey = "lastHandledChangeCount"

    public var lastHandledChangeCount: Int? {
        get { object(forKey: Self.lastHandledChangeCountKey) as? Int }
        set { set(newValue, forKey: Self.lastHandledChangeCountKey) }
    }
}
