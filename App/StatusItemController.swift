import AppKit
import Capture
import ShelfUI

final class StatusItemController: NSObject, NSMenuDelegate {
    private static let helpURL = url("https://github.com/alekseylopukh/clipsy")
    private static let issueURL = url("https://github.com/alekseylopukh/clipsy/issues/new")

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let iconView = NSImageView()
    private let menu = NSMenu()
    private let pause: CapturePause
    private let settings: MenuBarSettings
    private let openShelf: () -> Void
    private let startSequence: () -> Void
    private var isShowingPaused: Bool

    init(
        pause: CapturePause,
        settings: MenuBarSettings,
        openShelf: @escaping () -> Void,
        startSequence: @escaping () -> Void
    ) {
        self.pause = pause
        self.settings = settings
        self.openShelf = openShelf
        self.startSequence = startSequence
        isShowingPaused = pause.isPaused
        super.init()
        menu.delegate = self
        guard let button = statusItem.button else {
            fatalError("a status item created by NSStatusBar always has a button")
        }
        button.setAccessibilityLabel(String(localized: "Clipsy", comment: "Accessibility label of the menu bar item"))
        button.target = self
        button.action = #selector(buttonClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(textStyle: .body, scale: .large)
        iconView.image = Self.icon(isPaused: isShowingPaused)
        iconView.setAccessibilityElement(false)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(iconView)
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
    }

    /// applies the pause state and the menu bar settings until the calling task is cancelled
    func run() async {
        let changes = Observations { [pause, settings] in
            (pause.isPaused, settings.isItemShown, settings.clickOpensShelf)
        }
        for await (isPaused, isItemShown, clickOpensShelf) in changes {
            statusItem.isVisible = isItemShown
            statusItem.menu = clickOpensShelf ? nil : menu
            showPaused(isPaused)
        }
    }

    func bounce() {
        guard !reduceMotion else { return }
        iconView.addSymbolEffect(.bounce, options: .nonRepeating)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let openShelfItem = item(String(localized: "Open Shelf"), action: #selector(openShelfChosen))
        openShelfItem.setShortcut(for: .toggleShelf)
        menu.addItem(openShelfItem)
        let startSequenceItem = item(String(localized: "Start Sequence"), action: #selector(startSequenceChosen))
        startSequenceItem.setShortcut(for: .startSequence)
        menu.addItem(startSequenceItem)
        menu.addItem(.separator())
        menu.addItem(pause.isPaused
            ? item(String(localized: "Resume Capture"), action: #selector(togglePause))
            : item(String(localized: "Pause Capture"), action: #selector(togglePause)))
        menu.addItem(.separator())
        menu.addItem(item(String(localized: "Settings…"), action: #selector(openSettings), key: ","))
        menu.addItem(item(String(localized: "About Clipsy"), action: #selector(showAbout)))
        menu.addItem(.separator())
        menu.addItem(item(String(localized: "Clipsy Help"), action: #selector(openHelp)))
        menu.addItem(item(String(localized: "Report an Issue"), action: #selector(reportIssue)))
        menu.addItem(.separator())
        menu.addItem(item(String(localized: "Quit Clipsy"), action: #selector(quit), key: "q"))
    }

    private func item(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    private func showPaused(_ isPaused: Bool) {
        guard isPaused != isShowingPaused else { return }
        isShowingPaused = isPaused
        let image = Self.icon(isPaused: isPaused)
        if reduceMotion {
            iconView.image = image
        } else {
            iconView.setSymbolImage(image, contentTransition: .replace)
        }
        announce(isPaused
            ? String(localized: "Capture paused", comment: "VoiceOver announcement when capture is paused")
            : String(localized: "Capture resumed", comment: "VoiceOver announcement when capture is resumed"))
    }

    private static func icon(isPaused: Bool) -> NSImage {
        let symbol = isPaused ? "pause.circle" : "clipboard"
        let description = isPaused
            ? String(localized: "Capture Paused", comment: "Accessibility description of the paused menu bar symbol")
            : String(localized: "Clipsy", comment: "Accessibility label of the menu bar item")
        guard let image = NSImage(systemSymbolName: symbol, accessibilityDescription: description) else {
            fatalError("\(symbol) ships with SF Symbols on macOS 26")
        }
        return image
    }

    private func announce(_ text: String) {
        NSAccessibility.post(
            element: NSApplication.shared,
            notification: .announcementRequested,
            userInfo: [.announcement: text, .priority: NSAccessibilityPriorityLevel.high.rawValue]
        )
    }

    @objc private func buttonClicked() {
        guard let event = NSApplication.shared.currentEvent else { return }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            openShelf()
        }
    }

    @objc private func openShelfChosen() {
        openShelf()
    }

    @objc private func startSequenceChosen() {
        startSequence()
    }

    @objc private func togglePause() {
        pause.isPaused.toggle()
    }

    @objc private func openSettings() {
        SettingsWindow.open()
    }

    @objc private func showAbout() {
        NSApplication.shared.activate()
        NSApplication.shared.orderFrontStandardAboutPanel(nil)
    }

    @objc private func openHelp() {
        NSWorkspace.shared.open(Self.helpURL)
    }

    @objc private func reportIssue() {
        NSWorkspace.shared.open(Self.issueURL)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private static func url(_ string: String) -> URL {
        guard let url = URL(string: string) else {
            fatalError("\(string) is a valid URL literal")
        }
        return url
    }
}
