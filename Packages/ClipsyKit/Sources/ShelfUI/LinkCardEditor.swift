import AppKit
import Observation
import os
import Store

@MainActor
@Observable
final class LinkCardEditor: Identifiable {
    typealias Replace = ([Representation]) async throws -> Void
    typealias Rename = (String) async throws -> Void

    var url: String {
        didSet { errorMessage = nil }
    }

    var title: String {
        didSet { errorMessage = nil }
    }

    private(set) var errorMessage: String?
    private(set) var isSaving = false

    @ObservationIgnored let pageTitle: String?
    @ObservationIgnored private let initialURL: String
    @ObservationIgnored private let initialTitle: String
    @ObservationIgnored private let replace: Replace
    @ObservationIgnored private let rename: Rename

    private static let logger = Logger(subsystem: "app.gonar.clipsy", category: "Editing")

    init(card: CardSummary, replace: @escaping Replace, rename: @escaping Rename) {
        let metadata = card.decodedMetadata
        initialURL = metadata.url ?? card.preview ?? ""
        initialTitle = card.title ?? ""
        pageTitle = metadata.pageTitle
        url = initialURL
        title = initialTitle
        self.replace = replace
        self.rename = rename
    }

    var canSave: Bool {
        !trimmedURL.isEmpty && !isSaving
    }

    func save() async -> Bool {
        guard canSave else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            if trimmedURL != initialURL {
                let data = Data(trimmedURL.utf8)
                try await replace([Representation(
                    itemIndex: 0,
                    uti: NSPasteboard.PasteboardType.string.rawValue,
                    data: data
                )])
            }
            if title.trimmingCharacters(in: .whitespacesAndNewlines) != initialTitle {
                try await rename(title)
            }
            return true
        } catch {
            if error as? CardEditError != .duplicateContent {
                Self.logger.error("saving link failed: \(String(describing: type(of: error)), privacy: .public)")
            }
            errorMessage = CardEditorMessage.text(for: error)
            return false
        }
    }

    private var trimmedURL: String {
        url.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
