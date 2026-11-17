import Foundation
import Testing
@testable import Pasting

@MainActor
final class SoundEffectsTests {
    private final class FakePlayer: SoundPlaying {
        var played: [SoundEffect] = []

        func play(_ effect: SoundEffect) {
            played.append(effect)
        }
    }

    private let suiteName = "SoundEffectsTests-\(UUID().uuidString)"
    private let defaults: UserDefaults
    private let player = FakePlayer()

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    @Test(arguments: [false, true])
    func `sounds off plays nothing`(isStoredExplicitly: Bool) {
        if isStoredExplicitly {
            defaults.set(false, forKey: PasteSettings.soundEffectsKey)
        }
        let sounds = SoundEffects(player: player, defaults: defaults)

        for effect in SoundEffect.allCases {
            sounds.play(effect)
        }

        #expect(player.played.isEmpty)
    }

    @Test func `sounds on plays each effect`() {
        defaults.set(true, forKey: PasteSettings.soundEffectsKey)
        let sounds = SoundEffects(player: player, defaults: defaults)

        sounds.play(.capture)
        sounds.play(.paste)

        #expect(player.played == [.capture, .paste])
    }
}
