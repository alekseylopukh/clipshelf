import Observation

@MainActor
@Observable
final class CardActions {
    var targetAppName: String?
    var renamingCardID: Int64?
    @ObservationIgnored var perform: (CardCommand, [Int64]) -> Void = { _, _ in }
    @ObservationIgnored var rename: (Int64, String) -> Void = { _, _ in }
}
