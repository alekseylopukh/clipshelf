import Observation

@MainActor
@Observable
final class CardActions {
    var targetAppName: String?
    var renamingCardID: Int64?
    var plainTextModifier = QuickPasteModifiers.Key.shift
    var isCopyAsPlainTextShortcutTaken = false
    @ObservationIgnored var perform: (CardCommand, [Int64]) -> Void = { _, _ in }
    @ObservationIgnored var rename: (Int64, String) -> Void = { _, _ in }
    @ObservationIgnored var pasteOnDoubleClick: ([Int64]) -> Void = { _ in }
}
