import Observation

@MainActor
@Observable
public final class CapturePause {
    public var isPaused = false

    public init() {}
}
