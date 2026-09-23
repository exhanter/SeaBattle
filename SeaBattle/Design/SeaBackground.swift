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
        withAnimation(.easeInOut(duration: Motion.breathe).repeatForever(autoreverses: true)) {
            inhaled = true
        }
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
