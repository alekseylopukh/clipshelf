import Observation

@MainActor
@Observable
final class CardActions {
    var targetAppName: String?
    @ObservationIgnored var perform: (CardCommand, [Int64]) -> Void = { _, _ in }
}
