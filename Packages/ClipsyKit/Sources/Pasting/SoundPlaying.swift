import AppKit

@MainActor
public protocol SoundPlaying {
    func play(_ effect: SoundEffect)
}

public struct BundledSoundPlayer: SoundPlaying {
    public init() {}

    public func play(_ effect: SoundEffect) {
        NSSound(named: effect.rawValue)?.play()
    }
}
