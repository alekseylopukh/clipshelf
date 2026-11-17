import AppKit
import Observation
import os
import Store

@MainActor
@Observable
final class TextCardEditor: Identifiable {
    enum Target: Equatable {
        case card(Int64)
        case new(CardList)
    }

    typealias Save = (Target, [Representation]) async throws -> Void

    let target: Target
    private(set) var counts: TextCounts
    private(set) var activeStyles: Set<TextStyle> = []
    private(set) var errorMessage: String?
    private(set) var isSaving = false
    private(set) var isEmpty: Bool

    @ObservationIgnored let initialText: NSAttributedString
    @ObservationIgnored private let isInitiallyRich: Bool
    @ObservationIgnored private let persist: Save
    @ObservationIgnored private weak var textView: NSTextView?

    static let font = NSFont.preferredFont(forTextStyle: .body)
    private static let logger = Logger(subsystem: "app.gonar.clipsy", category: "Editing")

    init(target: Target, representations: [Representation] = [], save: @escaping Save) {
        self.target = target
        initialText = TextCardContent.attributedString(from: representations, font: Self.font)
        isInitiallyRich = TextCardContent.isRich(representations)
        persist = save
        counts = TextCounts(initialText.string)
        isEmpty = Self.isBlank(initialText.string)
    }

    var canSave: Bool {
        !isEmpty && !isSaving
    }

    func attach(_ textView: NSTextView) {
        self.textView = textView
        selectionDidChange()
    }

    func textDidChange() {
        guard let textView else { return }
        counts = TextCounts(textView.string)
        isEmpty = Self.isBlank(textView.string)
        errorMessage = nil
        selectionDidChange()
    }

    func selectionDidChange() {
        guard let textView else { return }
        let ranges = selectedRanges(in: textView)
        activeStyles = Set(TextStyle.allCases.filter { style in
            if ranges.isEmpty {
                return style.isApplied(in: textView.typingAttributes)
            }
            return ranges.allSatisfy { isApplied(style, throughout: $0, of: textView.attributedString()) }
        })
    }

    func setStyle(_ style: TextStyle, applied: Bool) {
        guard let textView, let storage = textView.textStorage else { return }
        let ranges = selectedRanges(in: textView)
        if ranges.isEmpty {
            textView.typingAttributes = style.setting(applied, in: textView.typingAttributes, defaultFont: Self.font)
        } else if textView.shouldChangeText(inRanges: ranges.map { NSValue(range: $0) }, replacementStrings: nil) {
            storage.beginEditing()
            for range in ranges {
                storage.enumerateAttributes(in: range) { attributes, run, _ in
                    storage.setAttributes(style.setting(applied, in: attributes, defaultFont: Self.font), range: run)
                }
            }
            storage.endEditing()
            textView.didChangeText()
        }
        selectionDidChange()
    }

    func save() async -> Bool {
        guard canSave, let textView else { return false }
        isSaving = true
        defer { isSaving = false }
        let text = textView.attributedString()
        do {
            let representations = try TextCardContent.representations(
                of: text,
                rich: isInitiallyRich || TextCardContent.hasStyles(text)
            )
            try await persist(target, representations)
            return true
        } catch CardEditError.duplicateContent {
            errorMessage = String(
                localized: "A card with the same content already exists.",
                comment: "Inline error in the text editor when saving would make the card identical to another"
            )
        } catch {
            Self.logger.error("saving text failed: \(String(describing: type(of: error)), privacy: .public)")
            errorMessage = String(
                localized: "Clipsy can’t save this card.",
                comment: "Inline error in the text editor when saving fails"
            )
        }
        return false
    }

    private func selectedRanges(in textView: NSTextView) -> [NSRange] {
        textView.selectedRanges.map(\.rangeValue).filter { $0.length > 0 }
    }

    private func isApplied(_ style: TextStyle, throughout range: NSRange, of text: NSAttributedString) -> Bool {
        var applied = true
        text.enumerateAttributes(in: range) { attributes, _, stop in
            if !style.isApplied(in: attributes) {
                applied = false
                stop.pointee = true
            }
        }
        return applied
    }

    private static func isBlank(_ text: String) -> Bool {
        text.allSatisfy(\.isWhitespace)
    }
}
