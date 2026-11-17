import AppKit
import Observation
import os
import Store

@MainActor
@Observable
final class ColorCardEditor: Identifiable {
    typealias Replace = ([Representation]) async throws -> Void

    private(set) var color: CardColor
    private(set) var format: CardColor.Format
    private(set) var value: String
    private(set) var errorMessage: String?
    private(set) var isSaving = false

    @ObservationIgnored private let initialValue: String
    @ObservationIgnored private let replace: Replace

    private static let logger = Logger(subsystem: "app.gonar.clipsy", category: "Editing")

    init(card: CardSummary, replace: @escaping Replace) {
        let initial = (card.decodedMetadata.color ?? card.preview ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        initialValue = initial
        value = initial
        color = CardColor(copiedText: initial) ?? CardColor(red: 0, green: 0, blue: 0)
        format = CardColor.format(of: initial) ?? .hex
        self.replace = replace
    }

    var canSave: Bool {
        CardColor(copiedText: value) != nil && !isSaving
    }

    var cgColor: CGColor {
        CGColor(
            srgbRed: CGFloat(color.red) / 255,
            green: CGFloat(color.green) / 255,
            blue: CGFloat(color.blue) / 255,
            alpha: 1
        )
    }

    func setColor(_ cgColor: CGColor) {
        guard let picked = CardColor(cgColor) else { return }
        color = picked
        value = picked.text(in: format)
        errorMessage = nil
    }

    func setFormat(_ format: CardColor.Format) {
        self.format = format
        value = color.text(in: format)
        errorMessage = nil
    }

    func setValue(_ value: String) {
        self.value = value
        errorMessage = nil
        if let typed = CardColor(copiedText: value), let typedFormat = CardColor.format(of: value) {
            color = typed
            format = typedFormat
        }
    }

    func save() async -> Bool {
        guard canSave else { return false }
        guard value.trimmingCharacters(in: .whitespacesAndNewlines) != initialValue else { return true }
        isSaving = true
        defer { isSaving = false }
        do {
            let data = Data(color.text(in: format).utf8)
            try await replace([Representation(
                itemIndex: 0,
                uti: NSPasteboard.PasteboardType.string.rawValue,
                data: data
            )])
            return true
        } catch {
            if error as? CardEditError != .duplicateContent {
                Self.logger.error("saving color failed: \(String(describing: type(of: error)), privacy: .public)")
            }
            errorMessage = CardEditorMessage.text(for: error)
            return false
        }
    }
}

extension CardColor {
    init?(_ cgColor: CGColor) {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let converted = cgColor.converted(to: space, intent: .defaultIntent, options: nil),
              let components = converted.components, components.count >= 3 else { return nil }
        let bytes = components.prefix(3).map { UInt8((min(max($0, 0), 1) * 255).rounded()) }
        self.init(red: bytes[0], green: bytes[1], blue: bytes[2])
    }
}
