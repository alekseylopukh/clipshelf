import AppKit

public final class ActionMenuItem: NSMenuItem {
    private let handler: () -> Void

    public init(_ title: String, systemImage: String? = nil, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(runHandler), keyEquivalent: "")
        target = self
        image = systemImage.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: nil) }
    }

    @available(*, unavailable)
    required init(coder _: NSCoder) {
        fatalError("menu items are built in code")
    }

    @objc private func runHandler() {
        handler()
    }
}
