import ApplicationServices

/// rects come back in Accessibility's global coordinates: origin at the top-left of the primary display, y down
public protocol FocusGeometryReading: Sendable {
    func caretBounds(in pid: pid_t) -> CGRect?
    func focusedElementFrame(in pid: pid_t) -> CGRect?
    func focusedWindowFrame(in pid: pid_t) -> CGRect?
}

public struct SystemFocusGeometryReader: FocusGeometryReading {
    private static let messagingTimeout: Float = 0.1

    public init() {}

    public func caretBounds(in pid: pid_t) -> CGRect? {
        guard let element = focusedElement(in: pid),
              let range = attribute(kAXSelectedTextRangeAttribute, of: element)
        else { return nil }
        var bounds: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            range,
            &bounds
        ) == .success, let bounds else { return nil }
        return Self.rect(bounds)
    }

    public func focusedElementFrame(in pid: pid_t) -> CGRect? {
        focusedElement(in: pid).flatMap(frame(of:))
    }

    public func focusedWindowFrame(in pid: pid_t) -> CGRect? {
        guard let window = attribute(kAXFocusedWindowAttribute, of: application(pid)).flatMap(Self.element)
        else { return nil }
        return frame(of: window)
    }

    private func application(_ pid: pid_t) -> AXUIElement {
        Self.limited(AXUIElementCreateApplication(pid))
    }

    /// the timeout is per element; without it a read waits ~6 s while the target app is busy handling ⌘V
    private static func limited(_ element: AXUIElement) -> AXUIElement {
        AXUIElementSetMessagingTimeout(element, messagingTimeout)
        return element
    }

    private func focusedElement(in pid: pid_t) -> AXUIElement? {
        attribute(kAXFocusedUIElementAttribute, of: application(pid)).flatMap(Self.element)
    }

    private func frame(of element: AXUIElement) -> CGRect? {
        guard let position = attribute(kAXPositionAttribute, of: element)
            .flatMap(Self.point),
            let size = attribute(kAXSizeAttribute, of: element)
            .flatMap(Self.size)
        else { return nil }
        return CGRect(origin: position, size: size)
    }

    private func attribute(_ name: String, of element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    private static func element(_ value: CFTypeRef) -> AXUIElement? {
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return limited(unsafeDowncast(value, to: AXUIElement.self))
    }

    private static func axValue(_ value: CFTypeRef, of type: AXValueType) -> AXValue? {
        guard CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let axValue = unsafeDowncast(value, to: AXValue.self)
        return AXValueGetType(axValue) == type ? axValue : nil
    }

    private static func rect(_ value: CFTypeRef) -> CGRect? {
        var rect = CGRect.zero
        guard let axValue = axValue(value, of: .cgRect), AXValueGetValue(axValue, .cgRect, &rect) else { return nil }
        return rect
    }

    private static func point(_ value: CFTypeRef) -> CGPoint? {
        var point = CGPoint.zero
        guard let axValue = axValue(value, of: .cgPoint), AXValueGetValue(axValue, .cgPoint, &point) else { return nil }
        return point
    }

    private static func size(_ value: CFTypeRef) -> CGSize? {
        var size = CGSize.zero
        guard let axValue = axValue(value, of: .cgSize), AXValueGetValue(axValue, .cgSize, &size) else { return nil }
        return size
    }
}
