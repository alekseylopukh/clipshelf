import Foundation
import Store

@MainActor
public final class PasteCoordinator {
    public typealias RepresentationLoading = @Sendable (Int64) async throws -> [Representation]

    public enum Action: Sendable {
        case paste
        case copy
    }

    private let writer: PasteboardWriter
    private let representations: RepresentationLoading
    private let trust: any AccessibilityTrust
    private let keystroke: any PasteKeystrokePosting
    private let alert: any AccessibilityAlertPresenting
    private let defaults: UserDefaults
    private var hasAskedForAccessibility = false

    public init(
        writer: PasteboardWriter,
        representations: @escaping RepresentationLoading,
        trust: any AccessibilityTrust = SystemAccessibilityTrust(),
        keystroke: any PasteKeystrokePosting = PasteKeystroke(),
        alert: any AccessibilityAlertPresenting = AccessibilityAlert(),
        defaults: UserDefaults = .standard
    ) {
        self.writer = writer
        self.representations = representations
        self.trust = trust
        self.keystroke = keystroke
        self.alert = alert
        self.defaults = defaults
    }

    /// `hideShelf` must take the shelf off screen synchronously, so the keystroke reaches the target
    public func perform(
        _ action: Action,
        cards: [CardSummary],
        plainModifier: Bool,
        target: (any PasteTarget)?,
        hideShelf: () -> Void
    ) async throws {
        let representations = try await combinedRepresentations(of: cards)
        writer.write(representations, plainTextOnly: plainModifier || defaults.pastesPlainTextByDefault)
        hideShelf()
        guard action == .paste, defaults.pasteBehavior == .pasteIntoActiveApp else { return }
        guard trust.isTrusted else {
            await askForAccessibilityIfNeeded(target: target)
            return
        }
        if let target, !target.isActive {
            await target.activate()
        }
        keystroke.postCommandV()
    }

    private func combinedRepresentations(of cards: [CardSummary]) async throws -> [Representation] {
        let ordered = cards
            .sorted { ($0.lastCopiedAt ?? $0.createdAt, $0.id) < ($1.lastCopiedAt ?? $1.createdAt, $1.id) }
        if ordered.count == 1 {
            return try await representations(ordered[0].id)
        }
        var loaded: [(kind: CardKind, representations: [Representation])] = []
        for card in ordered {
            try await loaded.append((card.kind, representations(card.id)))
        }
        return CombinedPayload.representations(of: loaded)
    }

    private func askForAccessibilityIfNeeded(target: (any PasteTarget)?) async {
        guard !hasAskedForAccessibility, !defaults.isAccessibilityAlertSuppressed else { return }
        hasAskedForAccessibility = true
        let response = alert.presentAccessibilityAlert()
        if response.suppressesFutureAlerts {
            defaults.isAccessibilityAlertSuppressed = true
        }
        if response.opensSystemSettings {
            trust.requestTrust()
        } else {
            await target?.activate()
        }
    }
}
