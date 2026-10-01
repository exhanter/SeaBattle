//
//  HapticService.swift
//  SeaBattle
//
//  R4.3a: вибрация на те же события, что и звук, — исход выстрела (свой и
//  по вам), победа и поражение. Щелчки интерфейса не вибрируют: прицел и
//  кнопки щёлкают часто, и дрожь на каждое касание глушит важное.
//
//  Выключатель живёт здесь, а не у партии, как `soundOn`: вибрацию зовут
//  модели боя, у которых нет `AppState`, и тянуть флаг через каждую из них
//  ради одного тумблера не стоит. `AppState.hapticsOn` пишет его в `didSet`.
//  До того (тесты, превью) он выключен.
//
//  Системный выключатель «Системная тактильная отдача» генераторы уважают
//  сами — проверять его не нужно.
//

import CoreHaptics
import UIKit

@MainActor
final class HapticService {

    static let shared = HapticService()

    /// Есть ли в устройстве вибромотор. У iPad его нет, у симулятора тоже —
    /// там строки «Вибрация» в настройках нет.
    static let isSupported = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    enum Event {
        case miss
        case hit
        case sunk
        case victory
        case defeat
    }

    var isEnabled = false

    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()

    private init() {}

    func play(_ event: Event) {
        guard isEnabled, Self.isSupported else { return }
        switch event {
        case .miss: light.impactOccurred()
        case .hit: medium.impactOccurred()
        case .sunk: heavy.impactOccurred()
        case .victory: notification.notificationOccurred(.success)
        case .defeat: notification.notificationOccurred(.error)
        }
    }

    /// Исход выстрела по правилам. Повтор отыгрывается как промах — как и звук.
    func play(shot result: Board.ShotResult) {
        switch result {
        case .miss, .repeated: play(.miss)
        case .hit: play(.hit)
        case .sunk: play(.sunk)
        case .offBoard: break
        }
    }

    /// Исход выстрела так, как его пишет лента (сеть).
    func play(outcome: FeedOutcome) {
        switch outcome {
        case .miss, .repeatHit, .repeatMiss: play(.miss)
        case .hit: play(.hit)
        case .sunk: play(.sunk)
        }
    }
}
