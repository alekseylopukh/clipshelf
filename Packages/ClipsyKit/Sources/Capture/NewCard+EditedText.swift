import Store

public extension NewCard {
    static let editorSourceApp = SourceApp(bundleID: "app.gonar.clipsy", name: "Clipsy")

    /// classified and hashed like a copy, so text that is only a link or a color becomes that kind
    @concurrent
    static func editedText(_ representations: [Representation]) async -> NewCard {
        NewCard(snapshot: PasteboardSnapshot(representations: representations), sourceApp: editorSourceApp)
    }
}
