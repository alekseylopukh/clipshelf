import CoreGraphics

public struct PasteLandingLocator: Sendable {
    private let reader: any FocusGeometryReading

    public init(reader: any FocusGeometryReading = SystemFocusGeometryReader()) {
        self.reader = reader
    }

    @concurrent
    public func landingRect(in pid: pid_t, primaryScreenHeight: CGFloat) async -> CGRect? {
        locate(in: pid, primaryScreenHeight: primaryScreenHeight)
    }

    func locate(in pid: pid_t, primaryScreenHeight: CGFloat) -> CGRect? {
        let candidates: [() -> CGRect?] = [
            { reader.caretBounds(in: pid) },
            { reader.focusedElementFrame(in: pid) },
            { reader.focusedWindowFrame(in: pid) }
        ]
        for candidate in candidates {
            if let rect = candidate(), rect.height > 0 {
                return Self.appKitRect(fromAccessibility: rect, primaryScreenHeight: primaryScreenHeight)
            }
        }
        return nil
    }

    static func appKitRect(fromAccessibility rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryScreenHeight - rect.maxY, width: rect.width, height: rect.height)
    }
}
