import CoreGraphics
import Foundation
import Observation

@MainActor
@Observable
final class CardActions {
    var targetAppName: String?
    var renamingCardID: Int64?
    var popUp: CardPopUp?
    var textEditor: TextCardEditor?
    var plainTextModifier = QuickPasteModifiers.Key.shift
    var isCopyAsPlainTextShortcutTaken = false
    @ObservationIgnored var perform: (CardCommand, [Int64]) -> Void = { _, _ in }
    @ObservationIgnored var rename: (Int64, String) -> Void = { _, _ in }
    @ObservationIgnored var showPopUp: (CardPopUp, CGRect) -> Void = { _, _ in }
    @ObservationIgnored var pasteOnDoubleClick: ([Int64]) -> Void = { _ in }
    @ObservationIgnored var openWith: (URL, Int64) -> Void = { _, _ in }
    @ObservationIgnored var beginDrag: (CardDrag) -> Void = { _ in }

    func endEditing() {
        renamingCardID = nil
        popUp = nil
        textEditor = nil
    }
}
