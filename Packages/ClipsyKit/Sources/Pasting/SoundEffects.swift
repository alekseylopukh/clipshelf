import Foundation

@MainActor
public final class SoundEffects {
    private let player: any SoundPlaying
    private let defaults: UserDefaults

    public init(player: any SoundPlaying = BundledSoundPlayer(), defaults: UserDefaults = .standard) {
        self.player = player
        self.defaults = defaults
    }

    public func play(_ effect: SoundEffect) {
        guard defaults.bool(forKey: PasteSettings.soundEffectsKey) else { return }
        player.play(effect)
    }
}
