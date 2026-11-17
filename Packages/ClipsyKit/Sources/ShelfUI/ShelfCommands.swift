import Observation

@MainActor
@Observable
public final class ShelfCommands {
    public var newBoard: (() -> Void)?
    public var newTextCard: (() -> Void)?
    public var startSequence: (() -> Void)?
    public var isCapturePaused: () -> Bool = { false }
    public var setCapturePaused: ((Bool) -> Void)?
    public var openSettings: (() -> Void)?

    public init() {}
}
