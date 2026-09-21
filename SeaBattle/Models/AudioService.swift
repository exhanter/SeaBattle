//
//  AudioService.swift
//  SeaBattle
//
//  R0.2: all sound and music in one main-actor-isolated service. Replaces the
//  `static var musicPlayer / soundPlayer` globals on `AppState`, which are an
//  error under Swift 6 strict concurrency (mutable global state).
//
//  Two behavioural fixes come with the move:
//    - players are created once per effect and cached, instead of decoding the
//      file again on every shot;
//    - each effect has its own player, so a click no longer cuts off the blast
//      that is still playing (previously everything shared one player).
//

import AVFoundation

@MainActor
final class AudioService {

    static let shared = AudioService()

    /// Every sound the game can play. Raw values are the bundled file names.
    enum Effect: String, CaseIterable {
        case click = "click_sound.wav"
        case start = "start_sound.wav"
        case missed = "blast_missed.wav"
        case hit = "blast_onfire2.wav"
        case sunk = "Glass_Break-stephan_schutze-958181291.wav"
        case victory = "victory_sound.wav"
        case defeat = "defeat_sound.wav"

        /// Effects play at full volume. The old code asked for `2.0` on the sunk
        /// and missed samples, but `AVAudioPlayer.volume` clamps to 0...1, so
        /// every effect was already at 1.0 — kept identical on purpose.
        var volume: Float { 1.0 }
    }

    enum Music: String {
        case battle = "Battles_on_the_High_Seas.mp3"
    }

    private var effectPlayers: [Effect: AVAudioPlayer] = [:]
    private var musicPlayer: AVAudioPlayer?

    private init() {
        configureSession()
    }

    // MARK: - Session

    /// Routes audio through the playback category so music and effects are heard
    /// even when the device's silent (mute) switch is on — otherwise there is no
    /// sound at all on a real device.
    private func configureSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            Log.audio.error("Audio session setup failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Effects

    func play(_ effect: Effect) {
        guard let player = player(for: effect) else { return }
        // Restart rather than ignore: repeated taps should each be audible.
        player.currentTime = 0
        player.volume = effect.volume
        player.play()
    }

    /// Bridge for call sites that still pass a bundled file name. Unknown names
    /// are ignored, which keeps the old "play nothing" behaviour for `""`.
    func play(named fileName: String) {
        guard let effect = Effect(rawValue: fileName) else { return }
        play(effect)
    }

    private func player(for effect: Effect) -> AVAudioPlayer? {
        if let cached = effectPlayers[effect] { return cached }
        guard let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "") else {
            Log.audio.error("Missing sound file \(effect.rawValue, privacy: .public)")
            return nil
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = effect.volume
            player.prepareToPlay()
            effectPlayers[effect] = player
            return player
        } catch {
            Log.audio.error("Cannot load \(effect.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Music

    func startMusic(_ music: Music = .battle) {
        guard let url = Bundle.main.url(forResource: music.rawValue, withExtension: "") else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = 0.5
            player.play()
            musicPlayer = player
        } catch {
            Log.audio.error("Cannot start music: \(error.localizedDescription, privacy: .public)")
        }
    }

    func stopMusic() {
        musicPlayer?.stop()
        musicPlayer = nil
    }
}
