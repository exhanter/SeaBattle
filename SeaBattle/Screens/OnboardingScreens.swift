//
//  OnboardingScreens.swift
//  Sea Battle — первый запуск (R4.4, шаг 17)
//
//  Спека 4.1, кадры `screen13Welcome` и `screen13Name` (одно поколение, тур 13).
//  Два экрана, карусели и обучения правилам нет: приветствие — что за игра и с
//  кем играют, внизу «Восстановить»; затем имя, значок и цвет той же
//  `PlayerCard`, что в игре вдвоём. Второй экран живёт и в настройках
//  (`SettingsPage.player`): подзаголовок обещает, что имя меняется там.
//
//  Отступления от кадров — решения R4.4:
//  - **Имя «из системы» не подставляется:** с iOS 16 `UIDevice.name` отдаёт
//    просто «iPhone», а Game Center при первом запуске ещё не вошёл. Поле пустое
//    с подсказкой, значок и цвет выбраны заранее.
//  - «Готово» гаснет без имени — рядом есть «Пропустить».
//  - **Строки «Меню» внизу нет** (её нет и в кадрах): из онбординга некуда
//    выходить, кроме как вперёд.
//  - «Восстановить» — только где Pro продаётся (iOS 26+, решение 8).
//  - Окошки значка и цвета — системные поповеры `PlayerCard`, как в игре
//    вдвоём, поэтому пояснение про цвет стоит сразу под карточкой.
//

import SwiftUI

// MARK: - Числа

/// Кадры `screen13Welcome` и `screen13Name` (393 pt, полоса состояния 59).
enum OnboardingMetrics {
    /// Верх приветствия — 96 от края экрана.
    static func welcomeTop(compact: Bool) -> CGFloat { compact ? 16 : 96 - 59 }
    static let welcomeGap: CGFloat = 22
    static let linesGap: CGFloat = 10
    static let lead: CGFloat = 15.5
    static let leadLineSpacing: CGFloat = 15.5 * 0.45
    static let body: CGFloat = 14
    static let bodyLineSpacing: CGFloat = 14 * 0.5
    static let restoreText: CGFloat = 12.5
    static let skipText: CGFloat = 13
    /// Имя: заголовок на 76 от края, а не на 68, как у остальных экранов.
    static let nameTitleExtra: CGFloat = 76 - Geometry.Nav.titleTop
    static let subtitleGap: CGFloat = 12
    static let cardGap: CGFloat = 16
    static let cardRadius: CGFloat = 20
    static let cardPadding = EdgeInsets(top: 12, leading: 13, bottom: 12, trailing: 13)
    static let note: CGFloat = 11.5
    static let noteInset: CGFloat = 3
}

// MARK: - Весь первый запуск

/// Два экрана подряд. Что выбрано, отдаётся в `onFinish` целиком: `nil` —
/// «Пропустить».
struct OnboardingFlow: View {
    enum Step { case welcome, name }

    /// Строка «Восстановить» — только где Pro продаётся.
    var offersRestore: Bool = PremiumManager.isOffered
    var isPremium: Bool = false
    var onRestore: () async -> Bool = { false }
    var onFinish: (OwnPlayer?) -> Void = { _ in }

    @State private var step: Step = .welcome
    @State private var player = OwnPlayer.starter

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            switch step {
            case .welcome:
                WelcomeScreen(offersRestore: offersRestore,
                              isPremium: isPremium,
                              onRestore: onRestore,
                              onPlay: { withAnimation(Motion.standard.reduced(reduceMotion)) { step = .name } })
                    .transition(.opacity)
            case .name:
                PlayerNameScreen(player: $player,
                                 purpose: .firstLaunch,
                                 onDone: { onFinish(player) },
                                 onSkip: { onFinish(nil) })
                    .transition(.opacity)
            }
        }
    }
}

// MARK: - Приветствие

struct WelcomeScreen: View {
    var offersRestore: Bool = true
    var isPremium: Bool = false
    var onRestore: () async -> Bool = { false }
    var onPlay: () -> Void = {}

    @Environment(\.usesPadLayout) private var usesPadLayout
    @State private var restoring = false
    @State private var notice: ProPurchaseNotice?

    var body: some View {
        GeometryReader { proxy in
            let size = Geometry.SizeClass.forWidth(proxy.size.width)

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: OnboardingMetrics.welcomeGap) {
                        Text("Sea Battle")
                            .font(TypeScale.gameTitle(compact: size.isCompact))
                            .tracking(TypeScale.gameTitleTracking(compact: size.isCompact))
                            .foregroundStyle(Color.inkPrimary)
                            .accessibilityAddTraits(.isHeader)

                        MenuHero(size: size)

                        lines
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, Geometry.Nav.titleInset)
                    .padding(.top, OnboardingMetrics.welcomeTop(compact: size.isCompact))
                    .padding(.bottom, OnboardingMetrics.welcomeGap)
                }
                .scrollBounceBehavior(.basedOnSize)

                VStack(spacing: Geometry.Nav.stackGap) {
                    Button("Play", action: onPlay)
                        .primaryButton()
                        .accessibilityIdentifier("welcomePlay")
                    if offersRestore { restoreLine }
                }
                .padding(.horizontal, Geometry.Nav.stackInset)
                .padBottomFrame()
            }
        }
    }

    private var lines: some View {
        VStack(spacing: OnboardingMetrics.linesGap) {
            Text("Familiar rules: a 10 × 10 board and ten ships.")
                .font(.scalable(size: OnboardingMetrics.lead))
                .lineSpacing(OnboardingMetrics.leadLineSpacing)
                .foregroundStyle(Color.inkPrimary)
            (usesPadLayout
             ? Text("Alone against the computer, two players on one device, nearby without internet or online. You can even play someone who has a sheet of paper.")
             : Text("Alone against the computer, two players on one phone, nearby without internet or online. You can even play someone who has a sheet of paper."))
                .font(.scalable(size: OnboardingMetrics.body))
                .lineSpacing(OnboardingMetrics.bodyLineSpacing)
                .foregroundStyle(Color.inkSecondary)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// «Уже покупали Pro? Восстановить» — строка, а не кнопка: тот, кто
    /// переставил приложение, найдёт покупку здесь, а новичку она не мешает.
    /// Нашёлся Pro — строка говорит об этом и больше не нажимается.
    @ViewBuilder
    private var restoreLine: some View {
        if isPremium {
            restoreText(Text("Pro is active"))
        } else if let notice {
            restoreText(Text(notice.text))
        } else {
            Button {
                Task {
                    restoring = true
                    notice = await onRestore() ? nil : .nothingToRestore
                    restoring = false
                }
            } label: {
                restoreText(restoring ? Text("Restoring…") : Text("Bought Pro before? Restore"))
                    .frame(maxWidth: .infinity, minHeight: Geometry.Hit.minTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(restoring)
            .accessibilityIdentifier("welcomeRestore")
        }
    }

    private func restoreText(_ text: Text) -> some View {
        text
            .font(.scalable(size: OnboardingMetrics.restoreText))
            .foregroundStyle(Color.inkSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: Geometry.Hit.minTarget)
    }
}

// MARK: - Имя, значок и цвет

struct PlayerNameScreen: View {
    /// Первый запуск — «Готово» и «Пропустить» внизу; настройки — строка
    /// возврата, и всё сохраняется по ходу набора.
    enum Purpose { case firstLaunch, settings }

    @Binding var player: OwnPlayer
    var purpose: Purpose = .firstLaunch
    var onDone: () -> Void = {}
    var onSkip: () -> Void = {}
    var onBack: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            ScreenTitle(title: "What’s your name?",
                        back: purpose == .settings ? "Settings" : nil,
                        onBack: onBack)
                .padding(.top, NavMetrics.titleTopBelowSafeArea
                         + (purpose == .firstLaunch ? OnboardingMetrics.nameTitleExtra : 0))

            ScrollView {
                VStack(alignment: .leading, spacing: OnboardingMetrics.cardGap) {
                    subtitle
                        .padding(.horizontal, Geometry.Nav.titleInset - Geometry.Nav.stackInset)

                    PlayerCard(name: $player.name,
                               glyph: $player.glyph,
                               colorIndex: $player.colorIndex)
                        .padding(OnboardingMetrics.cardPadding)
                        .glassPanel(.g2, radius: OnboardingMetrics.cardRadius)
                        .accessibilityIdentifier("ownPlayerCard")

                    Text("The colour shows in the avatar, the name and on the handoff screen. The boards look the same for everyone: warm is yours, cool is your opponent’s.")
                        .font(.scalable(size: OnboardingMetrics.note))
                        .lineSpacing(OnboardingMetrics.note * 0.5)
                        .foregroundStyle(Color.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, OnboardingMetrics.noteInset)
                }
                .padding(.horizontal, Geometry.Nav.stackInset)
                .padding(.top, OnboardingMetrics.subtitleGap)
                .padding(.bottom, OnboardingMetrics.cardGap)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)

            if purpose == .firstLaunch {
                VStack(spacing: Geometry.Nav.stackGap) {
                    Button("Done", action: onDone)
                        .primaryButton(enabled: !player.trimmedName.isEmpty)
                        .accessibilityIdentifier("nameDone")
                    Button(action: onSkip) {
                        Text("Skip")
                            .font(.scalable(size: OnboardingMetrics.skipText))
                            .foregroundStyle(Color.inkSecondary)
                            .frame(maxWidth: .infinity, minHeight: Geometry.Hit.minTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("nameSkip")
                }
                .padding(.horizontal, Geometry.Nav.stackInset)
                .padBottomFrame()
            }
        }
    }

    /// В настройках вторая фраза («поменять можно в настройках») лишняя.
    private var subtitle: some View {
        (purpose == .firstLaunch
         ? Text("Only the people you play with see your name, icon and colour. You can change them in Settings at any time.")
         : Text("Only the people you play with see your name, icon and colour."))
            .font(.scalable(size: OnboardingMetrics.body))
            .lineSpacing(OnboardingMetrics.bodyLineSpacing)
            .foregroundStyle(Color.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Превью

#Preview("Первый запуск") {
    ZStack {
        SeaBackground()
            .ignoresSafeArea()
        OnboardingFlow(offersRestore: true)
    }
    .preferredColorScheme(.dark)
}

#Preview("Приветствие · светлая") {
    ZStack {
        SeaBackground()
            .ignoresSafeArea()
        WelcomeScreen()
    }
    .preferredColorScheme(.light)
}

#Preview("Приветствие · 375", traits: .fixedLayout(width: 375, height: 667)) {
    ZStack {
        SeaBackground()
            .ignoresSafeArea()
        WelcomeScreen()
    }
    .preferredColorScheme(.dark)
}

private struct NameDemo: View {
    var purpose: PlayerNameScreen.Purpose
    @State private var player = OwnPlayer(name: "Аня", glyph: "sailboat.fill", colorIndex: 0)

    var body: some View {
        ZStack {
            SeaBackground()
                .ignoresSafeArea()
            PlayerNameScreen(player: $player, purpose: purpose)
        }
    }
}

#Preview("Имя") {
    NameDemo(purpose: .firstLaunch)
        .preferredColorScheme(.dark)
}

#Preview("Имя · в настройках, светлая") {
    NameDemo(purpose: .settings)
        .preferredColorScheme(.light)
}
