import AppKit
import Carbon.HIToolbox
import DesignSystem
import KeyboardShortcuts
import Media
import os
import Pasting
import Store
import SwiftUI

@MainActor
public final class ShelfController {
    public typealias Rename = @Sendable (Int64, String) async throws -> Void

    public private(set) var targetApplication: NSRunningApplication?
    public let commands = ShelfCommands()

    private static let heightKey = "ShelfHeight"
    private static let logger = Logger(subsystem: "app.gonar.clipsy", category: "Shelf")
    private static let commandKeys: [String: CardCommand] = ["o": .open, "r": .rename]

    let panel = ShelfPanel()
    private let presentation = ShelfPresentation()
    private let calculator = ShelfFrameCalculator()
    private let model: ShelfModel
    private let paster: PasteCoordinator
    private let deletion: CardDeletion
    private let representations: PasteCoordinator.RepresentationLoading
    private let renameCard: Rename
    private let actions = CardActions()
    private let defaults: UserDefaults
    private var resizeStart: (mouseY: CGFloat, height: CGFloat)?

    public init(
        model: ShelfModel,
        paster: PasteCoordinator,
        deletion: CardDeletion,
        representations: @escaping PasteCoordinator.RepresentationLoading,
        rename: @escaping Rename,
        thumbnails: ThumbnailCache,
        defaults: UserDefaults = .standard
    ) {
        self.model = model
        self.paster = paster
        self.deletion = deletion
        self.representations = representations
        renameCard = rename
        self.defaults = defaults
        let hostingView = NSHostingView(rootView: ShelfContainerView(
            presentation: presentation,
            model: model,
            commands: commands,
            onResize: { [weak self] in self?.resize() },
            onResizeEnded: { [weak self] in self?.endResize() }
        ).environment(actions).environment(\.richTextLoader, RichTextLoader(representations: representations))
            .environment(\.cardMediaLoader, CardMediaLoader(representations: representations, thumbnails: thumbnails)))
        hostingView.sizingOptions = []
        hostingView.autoresizingMask = [.width, .height]
        let contentView = NSView()
        contentView.addSubview(hostingView)
        panel.contentView = contentView
        panel.onCancel = { [weak self] in self?.cancel() }
        panel.onResignKey = { [weak self] in self?.closeOnFocusLoss() }
        panel.onKeyDown = { [weak self] event in self?.handleKeyDown(event) ?? false }
        panel.onFlagsChanged = { [weak self] event in self?.updateQuickPasteModifier(event.modifierFlags) }
        actions.perform = { [weak self] command, ids in self?.perform(command, on: ids) }
        actions.rename = { [weak self] id, title in
            Task {
                await self?.rename(id, to: title)
            }
        }
        actions.pasteOnDoubleClick = { [weak self] ids in self?.pasteOnDoubleClick(ids) }
    }

    public var isShown: Bool {
        presentation.isVisible
    }

    public func toggle() {
        if isShown {
            hide()
        } else {
            show()
        }
    }

    public func show() {
        guard !isShown else { return }
        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }) ?? NSScreen.screens.first
        else {
            return
        }
        let frontmost = NSWorkspace.shared.frontmostApplication
        targetApplication = frontmost == NSRunningApplication.current ? nil : frontmost
        actions.targetAppName = targetApplication?.localizedName
        actions.plainTextModifier = QuickPasteModifiers(defaults: defaults).plainText
        panel.setFrame(calculator.frame(height: storedHeight, in: screen.visibleFrame), display: false)
        model.didOpen()
        updateQuickPasteModifier(NSEvent.modifierFlags)
        panel.makeKeyAndOrderFront(nil)
        withAnimation(reduceMotion ? .default : .spring) {
            presentation.isVisible = true
        }
    }

    public func hide() {
        guard isShown else { return }
        resizeStart = nil
        model.setQuickPasteModifierHeld(false)
        actions.renamingCardID = nil
        deletion.discardUndo()
        withAnimation(reduceMotion ? .default : .snappy) {
            presentation.isVisible = false
        } completion: { [weak self] in
            guard let self, !isShown else { return }
            panel.orderOut(nil)
        }
    }

    func perform(_ action: PasteCoordinator.Action, cards: [CardSummary], plainModifier: Bool) async {
        do {
            try await paster.perform(
                action,
                cards: cards,
                plainModifier: plainModifier,
                target: targetApplication,
                hideShelf: { [weak self] in self?.hideImmediately() }
            )
        } catch is CancellationError {
            return
        } catch {
            Self.logger.error("paste failed: \(String(describing: type(of: error)), privacy: .public)")
            hideImmediately()
            let alert = NSAlert(error: error)
            alert.messageText = String(
                localized: "Clipsy can’t paste this card.",
                comment: "Title of the alert shown when a card's contents cannot be read for pasting"
            )
            alert.informativeText = error.localizedDescription
            NSApplication.shared.activate()
            alert.runModal()
        }
    }

    private func perform(_ command: CardCommand, on ids: [Int64]) {
        switch command {
        case .paste, .pasteAsPlainText, .copy, .copyAsPlainText:
            let cards = model.cards.filter { ids.contains($0.id) }
            guard !cards.isEmpty else { return }
            let action: PasteCoordinator.Action = command == .paste || command == .pasteAsPlainText ? .paste : .copy
            let plain = command == .pasteAsPlainText || command == .copyAsPlainText
            Task {
                await perform(action, cards: cards, plainModifier: plain)
            }
        case .open:
            guard ids.count == 1, let cardID = ids.first else { return }
            Task {
                await open(cardID)
            }
        case .rename:
            guard ids.count == 1 else { return }
            actions.renamingCardID = ids.first
        case .removeFromBoard, .delete:
            Task {
                await delete(ids)
            }
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        let quickPaste = QuickPasteModifiers(defaults: defaults)
        if let shortcut = quickPaste.shortcut(keyCode: event.keyCode, modifierFlags: event.modifierFlags) {
            guard !event.isARepeat,
                  let cardID = model.quickPasteCard(number: shortcut.number),
                  let card = model.cards.first(where: { $0.id == cardID })
            else { return true }
            Task {
                await perform(.paste, cards: [card], plainModifier: shortcut.plainText)
            }
            return true
        }
        let modifiers = event.modifierFlags.intersection([.shift, .control, .option, .command])
        let key = event.charactersIgnoringModifiers?.lowercased()
        if Int(event.keyCode) == kVK_Delete, modifiers.isEmpty {
            if !event.isARepeat {
                perform(.delete, on: model.selectedCards.map(\.id))
            }
            return true
        }
        if modifiers == .command, let command = key.flatMap({ Self.commandKeys[$0] }) {
            if !event.isARepeat {
                perform(command, on: model.selectedCards.map(\.id))
            }
            return true
        }
        if handleNavigationKey(event, character: key, modifiers: modifiers) {
            return true
        }
        if modifiers == .command, handleCommandKey(key, isRepeat: event.isARepeat) {
            return true
        }
        guard let command = quickPaste.command(keyCode: event.keyCode, character: key, modifierFlags: modifiers)
        else { return false }
        if !event.isARepeat {
            perform(command, on: model.selectedCards.map(\.id))
        }
        return true
    }

    private func pasteOnDoubleClick(_ ids: [Int64]) {
        perform(
            QuickPasteModifiers(defaults: defaults).doubleClickCommand(modifierFlags: NSEvent.modifierFlags),
            on: ids
        )
    }

    private func open(_ cardID: Int64) async {
        guard let card = model.cards.first(where: { $0.id == cardID }), card.kind == .link || card.kind == .file else {
            return
        }
        do {
            let loaded = card.kind == .file ? try await representations(cardID) : []
            for url in card.openableURLs(in: loaded) {
                try await NSWorkspace.shared.open(url, configuration: NSWorkspace.OpenConfiguration())
            }
        } catch is CancellationError {
            return
        } catch {
            Self.logger.error("open failed: \(String(describing: type(of: error)), privacy: .public)")
            await presentError(error, title: String(
                localized: "Clipsy can’t open this card.",
                comment: "Title of the alert shown when a card's link or file cannot be opened"
            ))
        }
    }

    private func delete(_ ids: [Int64]) async {
        let list = model.tab
        let neighbor = model.neighbor(afterRemoving: Set(ids))
        do {
            let deleted = try await deletion.delete(ids, in: list) { [weak self] count in
                await self?.confirmDeletion(of: count, in: list) ?? false
            }
            if deleted, let neighbor, model.tab == list {
                model.select(neighbor)
            }
        } catch {
            Self.logger.error("delete failed: \(String(describing: type(of: error)), privacy: .public)")
            await presentError(error, title: String(
                localized: "Clipsy can’t delete these cards.",
                comment: "Title of the alert shown when deleting cards fails"
            ))
        }
    }

    private func undoDelete() async {
        do {
            try await deletion.undo()
        } catch {
            Self.logger.error("undo failed: \(String(describing: type(of: error)), privacy: .public)")
            await presentError(error, title: String(
                localized: "Clipsy can’t restore the deleted cards.",
                comment: "Title of the alert shown when undoing a delete fails"
            ))
        }
    }

    private func rename(_ cardID: Int64, to title: String) async {
        do {
            try await renameCard(cardID, title)
        } catch {
            Self.logger.error("rename failed: \(String(describing: type(of: error)), privacy: .public)")
            await presentError(error, title: String(
                localized: "Clipsy can’t rename this card.",
                comment: "Title of the alert shown when renaming a card fails"
            ))
        }
    }

    private func presentError(_ error: any Error, title: String) async {
        let alert = NSAlert(error: error)
        alert.messageText = title
        alert.informativeText = error.localizedDescription
        if isShown {
            _ = await alert.beginSheetModal(for: panel)
        } else {
            NSApplication.shared.activate()
            alert.runModal()
        }
    }

    /// orders the panel out at once, because a keystroke posted while it is key would land in the shelf
    private func hideImmediately() {
        resizeStart = nil
        model.setQuickPasteModifierHeld(false)
        actions.renamingCardID = nil
        deletion.discardUndo()
        presentation.isVisible = false
        panel.orderOut(nil)
    }

    private func updateQuickPasteModifier(_ modifierFlags: NSEvent.ModifierFlags) {
        model.setQuickPasteModifierHeld(QuickPasteModifiers(defaults: defaults).isQuickPasteHeld(in: modifierFlags))
    }

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private var storedHeight: CGFloat {
        defaults.object(forKey: Self.heightKey) == nil
            ? DesignTokens.shelfDefaultHeight
            : defaults.double(forKey: Self.heightKey)
    }

    private func closeOnFocusLoss() {
        guard panel.attachedSheet == nil, panel.childWindows?.isEmpty ?? true else { return }
        hide()
    }

    private func resize() {
        guard let screen = panel.screen else { return }
        let mouseY = NSEvent.mouseLocation.y
        let start = resizeStart ?? (mouseY, panel.frame.height)
        resizeStart = start
        let height = start.height + mouseY - start.mouseY
        panel.setFrame(calculator.frame(height: height, in: screen.visibleFrame), display: true)
    }

    private func endResize() {
        guard resizeStart != nil else { return }
        resizeStart = nil
        defaults.set(Double(panel.frame.height), forKey: Self.heightKey)
    }
}

private extension ShelfController {
    func handleCommandKey(_ key: String?, isRepeat: Bool) -> Bool {
        switch key {
        case "t":
            if !isRepeat {
                commands.setCapturePaused?(!commands.isCapturePaused())
            }
        case "z":
            Task {
                await undoDelete()
            }
        default:
            return false
        }
        return true
    }

    func cancel() {
        if !model.clearSearch() {
            hide()
        }
    }

    func handleNavigationKey(_ event: NSEvent, character: String?, modifiers: NSEvent.ModifierFlags) -> Bool {
        if let shortcut = KeyboardShortcuts.Shortcut(event: event), model.handleTabShortcut(shortcut) {
            return true
        }
        return model.handleSelectionKey(keyCode: Int(event.keyCode), character: character, modifiers: modifiers)
    }
}

public extension ShelfController {
    var isShownInScreenCapture: Bool {
        get { panel.sharingType != .none }
        set { panel.sharingType = newValue ? .readOnly : .none }
    }
}
