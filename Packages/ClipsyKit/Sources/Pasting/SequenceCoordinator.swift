import AppKit
import os
import Store

@MainActor
public final class SequenceCoordinator {
    public typealias CardLoading = @Sendable ([Int64]) async throws -> [CardSummary]

    public let sequence: PasteSequence

    private let detector: SequencePasteDetector
    private let paster: PasteCoordinator
    private let representations: PasteCoordinator.RepresentationLoading
    private let loadCards: CardLoading
    private let trust: any AccessibilityTrust
    private let keystroke: any PasteKeystrokePosting
    private let frontmostTarget: @MainActor () -> (any PasteTarget)?
    private var publishedPlainText = false

    private static let logger = Logger(subsystem: "app.gonar.clipsy", category: "Sequence")

    public init(
        sequence: PasteSequence = PasteSequence(),
        detector: SequencePasteDetector,
        paster: PasteCoordinator,
        representations: @escaping PasteCoordinator.RepresentationLoading,
        loadCards: @escaping CardLoading,
        trust: any AccessibilityTrust = SystemAccessibilityTrust(),
        keystroke: any PasteKeystrokePosting = PasteKeystroke(),
        frontmostTarget: @escaping @MainActor () -> (any PasteTarget)? = SequenceCoordinator.frontmostApplication
    ) {
        self.sequence = sequence
        self.detector = detector
        self.paster = paster
        self.representations = representations
        self.loadCards = loadCards
        self.trust = trust
        self.keystroke = keystroke
        self.frontmostTarget = frontmostTarget
    }

    /// `shelfSelection` is nil while the shelf is hidden; then the frontmost app's selection is copied
    /// and joins the Sequence once it is captured
    public func start(shelfSelection: [Int64]?) {
        if let shelfSelection {
            add(shelfSelection)
            return
        }
        sequence.open()
        guard trust.isTrusted else { return }
        keystroke.postCommandC()
    }

    /// `cardIDs` in shelf order
    public func add(_ cardIDs: [Int64]) {
        if cardIDs.isEmpty {
            sequence.open()
        } else {
            sequence.add(cardIDs)
        }
    }

    public func didCapture(_ cardID: Int64) {
        guard sequence.isOpen else { return }
        sequence.add([cardID])
    }

    /// keeps the head on the pasteboard and advances on each paste, until the calling task is cancelled; call it once
    public func run() async throws {
        async let detection: Void = detector.run()
        async let advancing: Void = advanceOnPastes()
        await publishHeads()
        await advancing
        try await detection
    }

    /// `cardIDs` in paste order, as the Sequence returned them
    public func pasteAll(_ cardIDs: [Int64], hideShelf: () -> Void) async {
        do {
            let summaries = try await loadCards(cardIDs)
            let byID = Dictionary(summaries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            let cards = cardIDs.compactMap { byID[$0] }
            guard cards.isEmpty == false else { return }
            try await paster.perform(
                .paste,
                cards: cards,
                plainModifier: sequence.isPlainText,
                keepsOrder: true,
                target: frontmostTarget(),
                hideShelf: hideShelf
            )
        } catch is CancellationError {
            return
        } catch {
            Self.logger.error("paste all failed: \(String(describing: type(of: error)), privacy: .public)")
            hideShelf()
            let alert = NSAlert(error: error)
            alert.messageText = String(
                localized: "Clipsy can’t paste the Sequence.",
                comment: "Title of the alert shown when Paste All cannot read the Sequence cards"
            )
            alert.informativeText = error.localizedDescription
            NSApplication.shared.activate()
            alert.runModal()
        }
    }

    public static func frontmostApplication() -> (any PasteTarget)? {
        let frontmost = NSWorkspace.shared.frontmostApplication
        return frontmost == NSRunningApplication.current ? nil : frontmost
    }

    private func advanceOnPastes() async {
        for await entryID in detector.pastedEntryIDs {
            sequence.didPaste(entryID)
        }
    }

    private func publishHeads() async {
        let sequence = sequence
        for await (entries, isPlainText) in Observations({ (sequence.entries, sequence.isPlainText) }) {
            guard let head = entries.first else {
                detector.stop()
                continue
            }
            if publishedPlainText == isPlainText, detector.holdsPublication(of: head.id) {
                continue
            }
            do {
                let loaded = try await representations(head.cardID)
                guard sequence.head == head, sequence.isPlainText == isPlainText else { continue }
                detector.publish(head.id, representations: loaded, plainTextOnly: isPlainText)
                publishedPlainText = isPlainText
            } catch is CancellationError {
                return
            } catch {
                detector.stop()
                Self.logger.error("loading the head failed: \(String(describing: type(of: error)), privacy: .public)")
            }
        }
    }
}
