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
    static let commandKeys: [String: CardCommand] = [
        "b": .addToBoard, "o": .open, "r": .rename, "g": .showInList, "e": .edit
    ]
    static let shiftCommandKeys: [String: CardCommand] = [
        "o": .openWith, "r": .showInFinder, "s": .share
    ]
    private static let cardMoveKeys: [Int: ShelfModel.Direction] = [kVK_LeftArrow: .previous, kVK_RightArrow: .next]

    let panel = ShelfPanel()
    let flight = PasteFlightPanel()
    let landingLocator = PasteLandingLocator()
    let dragSource = CardDragSource()
    var isDragging = false
    let presentation = ShelfPresentation()
    private let calculator = ShelfFrameCalculator()
    let model: ShelfModel
    let paster: PasteCoordinator
    private let deletion: CardDeletion
    let boardEditor: BoardEditor
    let representations: PasteCoordinator.RepresentationLoading
    let renameCard: Rename
    private let addToSequence: ([Int64]) -> Void
    let replaceText: ReplaceText
    let addText: AddText
    let actions = CardActions()
    let preview: CardPreviewPopover
    private let defaults: UserDefaults
    private var resizeStart: (mouseY: CGFloat, height: CGFloat)?
    let slide = ShelfSlide()
    var closeTask: Task<Void, Never>?

    public init(
        model: ShelfModel,
        paster: PasteCoordinator,
        deletion: CardDeletion,
        boardEditor: BoardEditor,
        representations: @escaping PasteCoordinator.RepresentationLoading,
        rename: @escaping Rename,
        addToSequence: @escaping ([Int64]) -> Void,
        thumbnails: ThumbnailCache,
        replaceText: @escaping ReplaceText,
        addText: @escaping AddText,
        defaults: UserDefaults = .standard
    ) {
        self.model = model
        self.paster = paster
        self.deletion = deletion
        self.boardEditor = boardEditor
        self.representations = representations
        renameCard = rename
        self.addToSequence = addToSequence
        self.replaceText = replaceText
        self.addText = addText
        self.defaults = defaults
        let richTextLoader = RichTextLoader(representations: representations)
        let mediaLoader = CardMediaLoader(representations: representations, thumbnails: thumbnails)
        preview = CardPreviewPopover(model: model, richTextLoader: richTextLoader, mediaLoader: mediaLoader)
        let hostingView = NSHostingView(rootView: ShelfContainerView(
            presentation: presentation,
            model: model,
            commands: commands,
            onResize: { [weak self] in self?.resize() },
            onResizeEnded: { [weak self] in self?.endResize() }
        ).environment(actions).environment(boardEditor)
            .environment(\.richTextLoader, richTextLoader)
            .environment(\.cardMediaLoader, mediaLoader)
            .padding(DesignTokens.shelfShadowMargin))
        hostingView.sizingOptions = []
        hostingView.autoresizingMask = [.width, .height]
        slide.attach(to: hostingView, in: panel)
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
        actions.showPopUp = { [weak self] popUp, frame in self?.showPopUp(popUp, at: frame) }
        actions.openWith = { [weak self] application, cardID in
            Task {
                await self?.open(cardID, with: application)
            }
        }
        actions.beginDrag = { [weak self] drag in self?.beginDrag(drag) }
        dragSource.onEnd = { [weak self] in self?.isDragging = false }
        commands.newBoard = { [weak boardEditor] in boardEditor?.beginNew() }
        commands.newTextCard = { [weak self] in self?.beginNewTextCard() }
        boardEditor.confirmDeletion = { [weak self] board in await self?.confirmDeletion(of: board) ?? false }
        boardEditor.reportError = { [weak self] error, title in await self?.presentError(error, title: title) }
        actions.attachPreviewAnchor = { [weak self] view in self?.preview.attach(view) }
        actions.detachPreviewAnchor = { [weak self] view in self?.preview.detach(view) }
        preview.returnKeyToShelf = { [weak self] in self?.returnKeyToPanel() }
        preview.onResignKey = { [weak self] in self?.closeOnFocusLoss() }
        preview.onKeyDown = { [weak self] event in self?.handlePreviewKeyDown(event) ?? false }
        preview.sharingType = { [weak self] in self?.panel.sharingType ?? .none }
        preview.availableSize = { [weak self] in self?.previewAvailableSize ?? PreviewSizeCalculator().defaultSize }
    }

    public var isShown: Bool {
        presentation.isVisible && closeTask == nil
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
        let plainText = QuickPasteModifiers(defaults: defaults).plainText
        actions.plainTextModifier = plainText
        actions.isCopyAsPlainTextShortcutTaken = KeyboardShortcuts.getShortcut(for: .startSequence)
            == KeyboardShortcuts.Shortcut(.c, modifiers: plainText.flags.union(.command))
        cancelClosing()
        panel.setFrame(calculator.windowFrame(height: storedHeight, in: screen.visibleFrame), display: false)
        model.didOpen()
        updateQuickPasteModifier(NSEvent.modifierFlags)
        if reduceMotion, !panel.isVisible {
            panel.alphaValue = 0
        }
        panel.makeKeyAndOrderFront(nil)
        presentation.isVisible = true
        slide.open(reduceMotion: reduceMotion)
    }

    public func hide() {
        guard isShown else { return }
        resizeStart = nil
        model.setQuickPasteModifierHeld(false)
        actions.endEditing()
        preview.dismiss()
        boardEditor.cancel()
        deletion.discardUndo()
        beginClosing()
    }

    func perform(_ command: CardCommand, on ids: [Int64]) {
        switch command {
        case .paste, .pasteAsPlainText, .copy, .copyAsPlainText:
            pasteOrCopy(command, on: ids)
        case .open, .showInFinder:
            openOrReveal(command, on: ids)
        case .quickLook, .showInList, .rename:
            guard ids.count == 1, let cardID = ids.first else { return }
            perform(command, on: cardID)
        case .edit:
            edit(ids)
        case .addToBoard, .openWith, .share:
            requestPopUp(for: command, on: ids)
        case .addToSequence:
            addToSequence(model.cards.map(\.id).filter { ids.contains($0) })
        case .removeFromBoard, .delete:
            Task {
                await delete(ids)
            }
        }
    }

    private func pasteOrCopy(_ command: CardCommand, on ids: [Int64]) {
        let cards = model.cards.filter { ids.contains($0.id) }
        guard !cards.isEmpty else { return }
        let action: PasteCoordinator.Action = command == .paste || command == .pasteAsPlainText ? .paste : .copy
        let plain = command == .pasteAsPlainText || command == .copyAsPlainText
        Task {
            await perform(action, cards: cards, plainModifier: plain)
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
        if modifiers.isEmpty, handleUnmodifiedKey(event) {
            return true
        }
        if let key, handleCardCommandKey(key, modifiers: modifiers, isRepeat: event.isARepeat) {
            return true
        }
        if handleNavigationKey(event, character: key, modifiers: modifiers)
            || handleBoardKey(event, character: key, modifiers: modifiers)
        {
            return true
        }
        if modifiers == .command, handleCommandKey(key, isRepeat: event.isARepeat) {
            return true
        }
        return handleCommandOrTyping(event, character: key, modifiers: modifiers, quickPaste: quickPaste)
    }

    private func delete(_ ids: [Int64]) async {
        let tab = model.tab
        let list = model.removalList(for: ids)
        let neighbor = model.neighbor(afterRemoving: Set(ids))
        do {
            let deleted = try await deletion.delete(model.idsByList(ids)) { [weak self] count in
                await self?.confirmDeletion(of: count, in: list) ?? false
            }
            if deleted, let neighbor, model.tab == tab {
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

    private func updateQuickPasteModifier(_ modifierFlags: NSEvent.ModifierFlags) {
        model.setQuickPasteModifierHeld(QuickPasteModifiers(defaults: defaults).isQuickPasteHeld(in: modifierFlags))
    }

    var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private var storedHeight: CGFloat {
        defaults.object(forKey: Self.heightKey) == nil
            ? DesignTokens.shelfDefaultHeight
            : defaults.double(forKey: Self.heightKey)
    }

    private var previewAvailableSize: CGSize? {
        guard let screen = panel.screen else { return nil }
        let glassFrame = panel.frame.insetBy(dx: calculator.shadowMargin, dy: calculator.shadowMargin)
        return PreviewSizeCalculator().availableSize(in: screen.visibleFrame, above: glassFrame)
    }

    private func resize() {
        guard let screen = panel.screen else { return }
        let mouseY = NSEvent.mouseLocation.y
        let start = resizeStart ?? (mouseY, calculator.glassHeight(windowHeight: panel.frame.height))
        resizeStart = start
        let height = start.height + mouseY - start.mouseY
        panel.setFrame(calculator.windowFrame(height: height, in: screen.visibleFrame), display: true)
    }

    private func endResize() {
        guard resizeStart != nil else { return }
        resizeStart = nil
        defaults.set(Double(calculator.glassHeight(windowHeight: panel.frame.height)), forKey: Self.heightKey)
    }
}

extension ShelfController {
    func presentError(_ error: any Error, title: String) async {
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
}

private extension ShelfController {
    func pasteOnDoubleClick(_ ids: [Int64]) {
        perform(
            QuickPasteModifiers(defaults: defaults).doubleClickCommand(modifierFlags: NSEvent.modifierFlags),
            on: ids
        )
    }

    func handleCommandKey(_ key: String?, isRepeat: Bool) -> Bool {
        switch key {
        case "t":
            if !isRepeat {
                commands.setCapturePaused?(!commands.isCapturePaused())
            }
        case "f":
            model.focusSearch()
        case "z":
            Task {
                await undoDelete()
            }
        default:
            return false
        }
        return true
    }

    func handleBoardKey(_ event: NSEvent, character: String?, modifiers: NSEvent.ModifierFlags) -> Bool {
        let isRepeat = event.isARepeat
        if modifiers == [.option, .command], let direction = Self.cardMoveKeys[Int(event.keyCode)] {
            guard case .board = model.tab, !model.isSearching else { return false }
            if !isRepeat {
                Task {
                    await boardEditor.moveSelection(direction)
                }
            }
            return true
        }
        guard modifiers == [.shift, .command] else { return false }
        switch (Int(event.keyCode), character) {
        case (_, "n") where !isRepeat:
            boardEditor.beginNew()
        case (_, "e") where !isRepeat:
            boardEditor.beginEditingCurrent()
        case (kVK_Delete, _) where !isRepeat:
            Task {
                await boardEditor.deleteCurrent()
            }
        case (_, "n"), (_, "e"), (kVK_Delete, _):
            break
        default:
            return false
        }
        return true
    }

    func handleCommandOrTyping(
        _ event: NSEvent,
        character: String?,
        modifiers: NSEvent.ModifierFlags,
        quickPaste: QuickPasteModifiers
    ) -> Bool {
        guard let command = quickPaste.command(keyCode: event.keyCode, character: character, modifierFlags: modifiers)
        else {
            guard modifiers.isSubset(of: .shift), let characters = event.characters else { return false }
            return model.typeToSearch(characters)
        }
        if !event.isARepeat {
            perform(command, on: model.selectedCards.map(\.id))
        }
        return true
    }

    func cancel() {
        if preview.isShown {
            preview.dismiss()
        } else if !model.clearSearch() {
            hide()
        }
    }

    func handleUnmodifiedKey(_ event: NSEvent) -> Bool {
        switch Int(event.keyCode) {
        case kVK_Space:
            if !event.isARepeat {
                preview.toggle()
            }
        case kVK_Delete:
            if !event.isARepeat {
                perform(.delete, on: model.selectedCards.map(\.id))
            }
        default:
            return false
        }
        return true
    }

    func returnKeyToPanel() {
        guard isShown else { return }
        panel.makeKey()
    }

    func handlePreviewKeyDown(_ event: NSEvent) -> Bool {
        if Int(event.keyCode) == kVK_Escape {
            cancel()
            return true
        }
        guard !event.modifierFlags.contains(.command) else { return false }
        return handleKeyDown(event)
    }

    func closeOnFocusLoss() {
        // the window that takes key status is known only after resignKey returns
        // swiftlint:disable:next no_dispatch_queue
        DispatchQueue.main.async { [weak self] in
            guard let self, isShown, panel.attachedSheet == nil, !panel.isKeyWindow,
                  panel.childWindows?.contains(where: \.isKeyWindow) != true
            else { return }
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
    /// the selected cards in shelf order; nil while the shelf is hidden
    var selectedCardIDs: [Int64]? {
        isShown ? model.selectedCards.map(\.id) : nil
    }

    /// orders the panel out at once, because a keystroke posted while it is key would land in the shelf
    func hideImmediately() {
        resizeStart = nil
        model.setQuickPasteModifierHeld(false)
        actions.endEditing()
        preview.dismiss()
        boardEditor.cancel()
        deletion.discardUndo()
        closeNow()
    }

    var isShownInScreenCapture: Bool {
        get { panel.sharingType != .none }
        set {
            panel.sharingType = newValue ? .readOnly : .none
            flight.sharingType = panel.sharingType
        }
    }
}
