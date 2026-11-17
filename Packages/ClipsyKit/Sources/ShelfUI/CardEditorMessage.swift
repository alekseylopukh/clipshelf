import Store

enum CardEditorMessage {
    static func text(for error: any Error) -> String {
        if error as? CardEditError == .duplicateContent {
            String(
                localized: "A card with the same content already exists.",
                comment: "Inline error in the text editor when saving would make the card identical to another"
            )
        } else {
            String(
                localized: "Clipsy can’t save this card.",
                comment: "Inline error in the text editor when saving fails"
            )
        }
    }
}
