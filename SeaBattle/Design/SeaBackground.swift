//
//  SeaBackground.swift
//  Sea Battle — фон приложения
//
//  Единственный фон на всю игру, два слоя (спека 2.1):
//
//  1. `LinearGradient.sea` во всю область — **неподвижен**;
//  2. радиальное свечение `Sea/Glow` поверх него — **единственное, что дышит**.
//
//  Это не придирка к формулировке: в макетах анимация висит именно на слое
//  свечения, а градиент моря стоит. Если дышать заставить весь фон, поедут
//  границы между тремя цветами, и море начнёт «шевелиться» — эффект, который
//  дизайн отклонил.
//
//  Один экземпляр на корневом контейнере, не по одному на экран.
//

import SwiftUI

// MARK: - Состояние дыхания

/// Три значения, которыми описывается слой свечения. Отдельный тип, потому что
/// правило Reduce Motion — не «выключить анимацию», а «замереть на средних
/// значениях», и это стоит проверять тестом, а не глазами.
struct BreathState: Equatable, Sendable {
    let scale: CGFloat
    /// Сдвиг по вертикали как доля высоты области, а не в точках: иначе на iPad
    /// пришлось бы держать вторую константу.
    let offsetFraction: CGFloat
    let opacity: Double

    /// Выдох — начало и конец цикла.
    static let resting = BreathState(scale: Motion.breatheScale.lowerBound,
                                     offsetFraction: 0,
                                     opacity: Motion.breatheOpacity.lowerBound)

    /// Вдох — середина цикла.
    static let inhaled = BreathState(scale: Motion.breatheScale.upperBound,
                                     offsetFraction: Motion.breatheOffsetY,
                                     opacity: Motion.breatheOpacity.upperBound)

    /// Reduce Motion: слой стоит неподвижно и **не исчезает**. Масштаб — середина
    /// между вдохом и выдохом, прозрачность — полная: свечение остаётся частью
    /// картинки, просто перестаёт двигаться.
    static let frozen = BreathState(scale: (Motion.breatheScale.lowerBound
                                            + Motion.breatheScale.upperBound) / 2,
                                    offsetFraction: 0,
                                    opacity: Motion.breatheOpacity.upperBound)

    static func state(reduceMotion: Bool, inhaled: Bool) -> BreathState {
        if reduceMotion { return .frozen }
        return inhaled ? .inhaled : .resting
    }
}

// MARK: - Фон

struct SeaBackground: View {

    /// Длительность цикла дыхания. В игре всегда `Motion.breathe` — 18 секунд;
    /// параметр существует ради превью: на 18 секундах движение по замыслу
    /// незаметно, и убедиться, что оно вообще идёт, иначе нечем.
    var cycle: Double = Motion.breathe

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var inhaled = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let breath = BreathState.state(reduceMotion: reduceMotion, inhaled: inhaled)

            LinearGradient.sea
                .overlay {
                    // Слой занимает всю область и масштабируется от центра,
                    // поэтому края никогда не обнажаются и считать вылет за
                    // границы не нужно — обрезает родитель.
                    RadialGradient.seaGlow(in: size)
                        .scaleEffect(breath.scale)
                        .offset(y: size.height * breath.offsetFraction)
                        .opacity(breath.opacity)
                }
                .clipped()
        }
        .ignoresSafeArea()
        .onAppear { startBreathing() }
        .onChange(of: reduceMotion) { _, nowReduced in
            if nowReduced {
                // Снять бесконечную анимацию: дальше значения берутся из
                // `frozen`, и двигаться уже нечему.
                withAnimation(.linear(duration: 0)) { inhaled = false }
            } else {
                startBreathing()
            }
        }
    }

    private func startBreathing() {
        guard !reduceMotion, !inhaled else { return }
        withAnimation(.easeInOut(duration: cycle).repeatForever(autoreverses: true)) {
            inhaled = true
        }
    }
}

// MARK: - Превью

/// Дыхание на своих 18 секундах увидеть нельзя — это его свойство, а не
/// недоработка. Здесь оно разобрано на части: ползунок проводит цикл руками,
/// переключатель запускает его вживую, но за 2 секунды вместо 18. Нужно, чтобы
/// можно было убедиться, что слой действительно движется, и оценить амплитуду.
private struct BreathInspector: View {
    @State private var phase: Double = 0
    @State private var live = false

    var body: some View {
        ZStack(alignment: .bottom) {
            if live {
                SeaBackground(cycle: 2)
            } else {
                manualLayers
            }

            VStack(alignment: .leading, spacing: 10) {
                Toggle("Живой цикл, 2 с вместо 18", isOn: $live)
                    .font(TypeScale.callout)
                    .foregroundStyle(Color.inkPrimary)

                if !live {
                    Slider(value: $phase)
                    Text(readout(for: interpolated(phase)))
                        .font(TypeScale.caption)
                        .foregroundStyle(Color.inkSecondary)
                }
            }
            .padding(14)
            .glassPanel(.g2, wood: .top)
            .padding(Geometry.Inset.phoneSide)
        }
    }

    /// Слои те же, что в `SeaBackground`, но фаза задаётся руками.
    private var manualLayers: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let state = interpolated(phase)
            LinearGradient.sea
                .overlay {
                    RadialGradient.seaGlow(in: size)
                        .scaleEffect(state.scale)
                        .offset(y: size.height * state.offsetFraction)
                        .opacity(state.opacity)
                }
                .clipped()
        }
        .ignoresSafeArea()
    }

    private func readout(for state: BreathState) -> String {
        let scale = String(format: "%.3f", state.scale)
        let shift = String(format: "%.1f", state.offsetFraction * 100)
        let opacity = String(format: "%.2f", state.opacity)
        return "выдох → вдох: масштаб \(scale) · сдвиг \(shift) % высоты · прозрачность \(opacity)"
    }

    /// Промежуточное состояние цикла. Концы берутся из `BreathState`, поэтому
    /// разъехаться с игрой значения не могут.
    private func interpolated(_ t: Double) -> BreathState {
        let a = BreathState.resting, b = BreathState.inhaled
        return BreathState(scale: a.scale + (b.scale - a.scale) * CGFloat(t),
                           offsetFraction: a.offsetFraction
                                           + (b.offsetFraction - a.offsetFraction) * CGFloat(t),
                           opacity: a.opacity + (b.opacity - a.opacity) * t)
    }
}

#Preview("Фон · тёмная") {
    SeaBackground()
        .preferredColorScheme(.dark)
}

#Preview("Фон · светлая") {
    SeaBackground()
        .preferredColorScheme(.light)
}

#Preview("Дыхание под лупой · тёмная") {
    BreathInspector()
        .preferredColorScheme(.dark)
}

#Preview("Дыхание под лупой · светлая") {
    BreathInspector()
        .preferredColorScheme(.light)
}
