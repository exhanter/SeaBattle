//
//  HapticService.swift
//  SeaBattle
//
//  R4.3a: вибрация на те же события, что и звук, — исход выстрела, победа и
//  поражение. 09.10 отклики выбраны на устройстве на временном «Вибростенде»:
//  - **свой выстрел и выстрел по вам различаются там, где это важно.**
//    Промах по вам нарочно заметный (Medium): это сигнал «ваш ход», когда
//    отвлеклись от экрана, — сильнее своего промаха, лёгкого «плеска».
//    Попадания одинаковые (Heavy), потопления разные: свой — «взрыв», по
//    вам — «корабль тонет»;
//  - узоры Core Haptics («плеск», потопления, победа) — под длину звуков;
//    остальное — системные генераторы;
//  - **кнопки, которые щёлкают звуком, отзываются «тиком»** (`.button`,
//    selection). Прицел не вибрирует: он щёлкает на каждое касание, и дрожь
//    глушила бы важное.
//
//  Выключатель живёт здесь, а не у партии, как `soundOn`: вибрацию зовут
//  модели боя, у которых нет `AppState`, и тянуть флаг через каждую из них
//  ради одного тумблера не стоит. `AppState.hapticsOn` пишет его в `didSet`.
//  До того (тесты, превью) он выключен.
//
//  Системный выключатель «Системная тактильная отдача» генераторы и движок
//  уважают сами — проверять его не нужно.
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
        case ownMiss
        case ownHit
        case ownSunk
        case incomingMiss
        case incomingHit
        case incomingSunk
        case victory
        case defeat
        /// Кнопка, которая щёлкает звуком.
        case button
    }

    var isEnabled = false {
        didSet { if isEnabled && !oldValue { prepare() } }
    }

    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()
    private var engine: CHHapticEngine?

    private init() {}

    func play(_ event: Event) {
        guard isEnabled, Self.isSupported else { return }
        switch event {
        case .incomingMiss: medium.impactOccurred()
        case .ownHit, .incomingHit: heavy.impactOccurred()
        case .defeat: notification.notificationOccurred(.error)
        case .button: selection.selectionChanged()
        case .ownMiss, .ownSunk, .incomingSunk, .victory:
            play(Self.beats(for: event))
        }
    }

    /// Исход выстрела по правилам. Повтор отыгрывается как промах — как и звук.
    /// `incoming` — стреляли по вам.
    func play(shot result: Board.ShotResult, incoming: Bool) {
        switch result {
        case .miss, .repeated: play(incoming ? .incomingMiss : .ownMiss)
        case .hit: play(incoming ? .incomingHit : .ownHit)
        case .sunk: play(incoming ? .incomingSunk : .ownSunk)
        case .offBoard: break
        }
    }

    /// Исход выстрела так, как его пишет лента (сеть, «бумага»).
    func play(outcome: FeedOutcome, incoming: Bool) {
        switch outcome {
        case .miss, .repeatHit, .repeatMiss: play(incoming ? .incomingMiss : .ownMiss)
        case .hit: play(incoming ? .incomingHit : .ownHit)
        case .sunk: play(incoming ? .incomingSunk : .ownSunk)
        }
    }

    // MARK: - Узоры

    /// Элемент узора: щелчок или гул.
    private enum Beat {
        /// Время, сила, резкость (0 — глухо, 1 — звонко).
        case tap(Double, Float, Float)
        /// Время, длительность, сила, резкость; сила гаснет к концу.
        case fadingRumble(Double, Double, Float, Float)
    }

    private static func beats(for event: Event) -> [Beat] {
        switch event {
        // Плеск: слабый щелчок и короткая гаснущая дрожь.
        case .ownMiss:
            [.tap(0, 0.4, 0.3), .fadingRumble(0.02, 0.28, 0.3, 0.1)]
        // Взрыв: пик и длинный низкий хвост.
        case .ownSunk:
            [.tap(0, 1, 1), .fadingRumble(0.01, 0.9, 0.9, 0.15)]
        // Корабль тонет: гаснущая дрожь и глухие толчки в ней.
        case .incomingSunk:
            [.tap(0, 1, 0.2), .fadingRumble(0.01, 1.2, 0.8, 0.2),
             .tap(0.4, 1, 0.1), .tap(0.8, 1, 0.1)]
        // Фанфара: три нарастающих щелчка и гул-аккорд.
        case .victory:
            [.tap(0, 0.5, 0.6), .tap(0.15, 0.7, 0.7), .tap(0.3, 0.85, 0.8),
             .tap(0.5, 1, 0.9), .fadingRumble(0.51, 0.7, 0.7, 0.4)]
        case .incomingMiss, .ownHit, .incomingHit, .defeat, .button:
            []
        }
    }

    /// Движок заводится заранее: первый узор партии не должен опаздывать.
    private func prepare() {
        guard Self.isSupported else { return }
        _ = try? runningEngine()
    }

    private func play(_ beats: [Beat], retry: Bool = true) {
        do {
            let engine = try runningEngine()
            let player = try engine.makePlayer(with: try Self.pattern(beats))
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Движок мог остановиться (фон, прерывание звука) — пересоздать
            // один раз. Не вышло — событие просто без вибрации.
            engine = nil
            if retry { play(beats, retry: false) }
        }
    }

    private func runningEngine() throws -> CHHapticEngine {
        let engine = try self.engine ?? CHHapticEngine()
        if self.engine == nil {
            // Только вибрация: звук играет `AudioService`, своя аудиосессия
            // движку не нужна. Простаивая, движок гасит себя сам.
            engine.playsHapticsOnly = true
            engine.isAutoShutdownEnabled = true
            self.engine = engine
        }
        try engine.start()
        return engine
    }

    private static func pattern(_ beats: [Beat]) throws -> CHHapticPattern {
        var events: [CHHapticEvent] = []
        var curves: [CHHapticParameterCurve] = []
        for beat in beats {
            switch beat {
            case let .tap(at, intensity, sharpness):
                events.append(CHHapticEvent(eventType: .hapticTransient,
                                            parameters: parameters(intensity, sharpness),
                                            relativeTime: at))
            case let .fadingRumble(at, duration, intensity, sharpness):
                events.append(CHHapticEvent(eventType: .hapticContinuous,
                                            parameters: parameters(intensity, sharpness),
                                            relativeTime: at, duration: duration))
                // Кривая гасит силу всего узора, поэтому щелчки внутри гула
                // («Корабль тонет») тоже тише — так их и выбирали на стенде.
                // Почти экспонента: быстро падает, долго тлеет.
                let points: [(Double, Float)] = [(0, 1), (duration * 0.25, 0.5),
                                                 (duration * 0.6, 0.2), (duration, 0)]
                curves.append(CHHapticParameterCurve(
                    parameterID: .hapticIntensityControl,
                    controlPoints: points.map { .init(relativeTime: $0.0, value: $0.1) },
                    relativeTime: at))
            }
        }
        return try CHHapticPattern(events: events, parameterCurves: curves)
    }

    private static func parameters(_ intensity: Float, _ sharpness: Float) -> [CHHapticEventParameter] {
        [CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
         CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)]
    }
}
