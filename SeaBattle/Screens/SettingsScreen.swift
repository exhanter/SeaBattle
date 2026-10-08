//
//  SettingsScreen.swift
//  Sea Battle — таб «Настройки» (R4.2)
//
//  Спека 4.11, кадры `screen6Settings` (iPhone, и с раскрытым языком) и
//  `screen11Settings` (iPad, две колонки, группа «Вид»). Одна страница,
//  вложенных экранов нет; язык и уровень выпадают списком из своей строки.
//
//  Отступления от кадров — решения R4.2:
//  - **Строк без состояния в модели нет**: «Тема», «Жребий первого хода»,
//    «Подсказки» (iPad). Выдумывать поведение ради строки не стали.
//    «Вибрация» появилась в R4.3a — и только там, где есть вибромотор.
//    Поэтому на iPhone нет группы «Вид» (в ней была одна «Тема»), а на iPad в
//    ней одна строка — сторона своего поля.
//  - **«Музыка» осталась** рядом со «Звуком»: в кадре её нет, но она есть в
//    игре, и выкинуть её молча значит отнять у игрока выключатель.
//  - Две строки одиночной игры стоят в группе «Игра» под подтверждением
//    выстрела, как велит спека, а не отдельной группой, как в кадре iPad.
//  - **Уровень посреди партии с компьютером не меняется**: партия читает его
//    на каждом ходу (ИИ и награда), и смена перед последним выстрелом
//    превратила бы победу на «Лёгком» в победу на «Эксперте».
//  - На iPad страница шире колонки 520 — 754, как в кадре (834 − 2 × 40):
//    в 520 две колонки не помещают строк с пояснениями.
//

import SwiftUI

/// Страницы внутри таба «Настройки». Таб-бар на них остаётся, как у кошелька.
enum SettingsPage: Hashable, Sendable {
    /// «Pro активен» (кадр `screen12ProActive`) — строка «Pro», когда он куплен.
    case pro
    /// Имя, значок и цвет владельца (R4.4) — тот же экран, что при первом запуске.
    case player
    /// «О приложении» (R4.6): правила, связь, авторы.
    case about
}

enum SettingsMetrics {
    static let bodyTop: CGFloat = 8
    static let groupGap: CGFloat = 16
    static let padGroupGap: CGFloat = 20
    static let padColumnGap: CGFloat = 24
    /// iPad: ширина страницы на две колонки (кадр `screen11Settings`).
    static let padWidth: CGFloat = 754
}

struct SettingsScreen: View {
    let isPremium: Bool
    /// Идёт партия с компьютером — уровень не меняется до её конца.
    var levelLocked: Bool = false
    /// Нажатие на закрытый «Эксперт» в списке уровней.
    var onLevelLocked: () -> Void = {}
    /// Строка «Pro». `nil` — строки нет (iOS 18, решение 8).
    var onPro: (() -> Void)?
    var onAbout: () -> Void = {}
    /// Строка «Ваше имя» (R4.4): подзаголовок первого запуска обещает её.
    var onPlayer: () -> Void = {}
    /// Строка «Вибрация» — только на устройстве с вибромотором (не iPad и не
    /// симулятор). Параметр — ради превью, которое идёт на симуляторе.
    var offersHaptics: Bool = HapticService.isSupported

    @Environment(AppState.self) private var appState
    @Environment(\.usesPadLayout) private var usesPadLayout
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(spacing: 0) {
            ScreenTitle(title: "Settings")
                .padding(.top, NavMetrics.titleTopBelowSafeArea)

            ScrollView {
                Group {
                    if usesPadLayout {
                        HStack(alignment: .top, spacing: SettingsMetrics.padColumnGap) {
                            VStack(spacing: SettingsMetrics.padGroupGap) { gameGroup }
                            VStack(spacing: SettingsMetrics.padGroupGap) {
                                viewGroup
                                soundGroup
                                moreGroup
                            }
                        }
                    } else {
                        VStack(spacing: SettingsMetrics.groupGap) {
                            gameGroup
                            soundGroup
                            moreGroup
                        }
                    }
                }
                .padding(.horizontal, Geometry.Nav.stackInset)
                .padding(.top, SettingsMetrics.bodyTop)
                .padding(.bottom, SettingsMetrics.groupGap)
            }
            .seaScroll()
        }
        .onChange(of: appState.musicOn) { _, isOn in
            // Музыка играет только в партии; выключатель вне партии лишь
            // запоминает выбор.
            if isOn && appState.gameIsActive && !appState.gameIsOver {
                AudioService.shared.startMusic()
            } else {
                AudioService.shared.stopMusic()
            }
        }
        .onChange(of: appState.hapticsOn) { _, isOn in
            // Включили — сразу дать почувствовать, как щелчок у звука.
            if isOn { HapticService.shared.play(.hit) }
        }
    }

    // MARK: Группы

    private var gameGroup: some View {
        @Bindable var appState = appState
        return ListGroup("Game", hostsMenus: true) {
            ListToggleRow(title: "Mark the water around sunk ships",
                          subtitle: "After a sinking the game marks the cells around the ship as misses",
                          isOn: clicking($appState.autoRevealAroundSunk))
                .accessibilityIdentifier("settingsAutoReveal")
            LevelMenu(selected: appState.difficultyLevel,
                      isPremium: isPremium,
                      isLocked: levelLocked,
                      onSelect: select(_:),
                      onLocked: onLevelLocked)
            ListToggleRow(title: "Ask for the level before a match",
                          subtitle: "If off, a single-player match starts right away at the chosen level",
                          isOn: clicking($appState.askLevelBeforeMatch))
                .accessibilityIdentifier("settingsAskLevel")
            ListToggleRow(title: "Confirm ending a match",
                          subtitle: "Ask again before an unfinished match is ended or deleted",
                          isOn: clicking($appState.confirmEndMatch))
                .accessibilityIdentifier("settingsConfirmEnd")
        }
    }

    /// Только iPad: на iPhone поля переключаются сегментами, сторон нет.
    private var viewGroup: some View {
        @Bindable var appState = appState
        return ListGroup("View") {
            ListStackRow(title: "Your board in landscape") {
                SegmentedPick(options: [(false, String(game: "Left", locale: locale)),
                                        (true, String(game: "Right", locale: locale))],
                              selection: clicking($appState.ownBoardOnRight))
                    .accessibilityIdentifier("settingsOwnBoardSide")
            }
        }
    }

    private var soundGroup: some View {
        @Bindable var appState = appState
        return ListGroup("Sound") {
            ListToggleRow(title: "Sound", isOn: clicking($appState.soundOn))
                .accessibilityIdentifier("settingsSound")
            ListToggleRow(title: "Music", isOn: clicking($appState.musicOn))
                .accessibilityIdentifier("settingsMusic")
            if offersHaptics {
                ListToggleRow(title: "Vibration",
                              subtitle: "Shots, sinkings, victory and defeat",
                              isOn: clicking($appState.hapticsOn))
                    .accessibilityIdentifier("settingsHaptics")
            }
        }
    }

    private var moreGroup: some View {
        @Bindable var appState = appState
        return ListGroup("More", hostsMenus: true) {
            ListRow(title: "Your name", value: playerName, action: onPlayer)
                .accessibilityIdentifier("settingsPlayer")
            LanguageMenu(selection: $appState.language)
            if let onPro {
                ListRow(title: "Pro",
                        value: isPremium ? Text("Active") : nil,
                        action: onPro)
                    .accessibilityIdentifier("settingsPro")
            }
            ListRow(title: "About the app", action: onAbout)
                .accessibilityIdentifier("settingsAbout")
        }
    }

    private var playerName: Text {
        if let name = appState.ownPlayer?.trimmedName, !name.isEmpty {
            Text(verbatim: name)
        } else {
            Text("Not set")
        }
    }

    // MARK: Действия

    private func select(_ level: AppState.DifficultyLevel) {
        guard level != appState.difficultyLevel else { return }
        appState.difficultyLevel = level
        click()
    }

    /// Привязка, которая щёлкает при каждом изменении. Щелчок после записи:
    /// включённый только что звук должен прозвучать, выключенный — нет.
    private func clicking<Value>(_ binding: Binding<Value>) -> Binding<Value> {
        Binding(get: { binding.wrappedValue },
                set: { binding.wrappedValue = $0; click() })
    }

    private func click() {
        if appState.soundOn { AudioService.shared.play(named: "click_sound.wav") }
    }
}

// MARK: - Уровень компьютера

/// «Уровень компьютера» — выпадающий список из своей строки, как у языка
/// (спека 4.11). У «Эксперта» без Pro замок: нажатие поднимает Pro, выбор не
/// меняется. Строка видна всегда, независимо от тумблера «Спрашивать уровень».
struct LevelMenu: View {
    let selected: AppState.DifficultyLevel
    let isPremium: Bool
    /// Идёт партия с компьютером: список не раскрывается, пояснение говорит
    /// почему.
    var isLocked: Bool = false
    var onSelect: (AppState.DifficultyLevel) -> Void = { _ in }
    var onLocked: () -> Void = {}

    var body: some View {
        Menu {
            ForEach(LevelChoice.all) { choice in
                let locked = choice.isLocked(isPremium: isPremium)
                Button {
                    if locked { onLocked() } else { onSelect(choice.level) }
                } label: {
                    Text(choice.title)
                    if choice.level == selected {
                        Image(systemName: "checkmark")
                    } else if locked {
                        Image(systemName: "lock.fill")
                    }
                }
            }
        } label: {
            ListMenuLabel(title: "Computer level",
                          subtitle: isLocked ? "Changes once the current match is over" : nil,
                          value: Text(LevelChoice.title(for: selected)))
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .accessibilityIdentifier("settingsLevel")
    }
}

// MARK: - Превью

#Preview("Настройки") {
    ZStack {
        SeaBackground()
            .ignoresSafeArea()
        SettingsScreen(isPremium: false, onPro: {}, offersHaptics: true)
    }
    .environment(AppState())
    .preferredColorScheme(.dark)
}

#Preview("Настройки · партия идёт, светлая") {
    ZStack {
        SeaBackground()
            .ignoresSafeArea()
        SettingsScreen(isPremium: true, levelLocked: true, onPro: {})
    }
    .environment(AppState())
    .preferredColorScheme(.light)
}

#Preview("Настройки · iPad", traits: .fixedLayout(width: 834, height: 1194)) {
    ZStack {
        SeaBackground()
            .ignoresSafeArea()
        SettingsScreen(isPremium: true, onPro: {})
            .frame(maxWidth: SettingsMetrics.padWidth)
    }
    .environment(AppState())
    .environment(\.usesPadLayout, true)
    .phoneStyle(true)
    .preferredColorScheme(.dark)
}
