//
//  AppShell.swift
//  Sea Battle — корневая оболочка (R2.1, шаг 5 порядка сборки)
//
//  Здесь дизайн-система впервые попадает в приложение: `SeaBackground` стоит
//  одним экземпляром на корневом контейнере, а не по одному на экран.
//
//  Три таба вне боя: Играть · Статистика · Настройки (спека 3). Премиума в
//  навигации нет — пейволл открывается из строки с замком и из настроек.
//  В бою табы заменяются на переключатель полей и действия фазы, поэтому
//  таб-бар живёт не в приложении целиком, а только в этой оболочке.
//
//  ПЕРЕХОДНОЕ. Новые экраны боя, статистики и настроек приходят позже
//  (R2.2–R2.3, R4.1–R4.2). До тех пор оболочка отдаёт управление старым
//  экранам: они работают, просто выглядят по-старому. Всё, что помечено
//  `ПЕРЕХОДНОЕ`, уходит вместе с ними в R4.6.
//

import SwiftUI

// MARK: - Табы

enum ShellTab: String, CaseIterable, Hashable, Sendable {
    case play, statistics, settings

    var icon: String {
        switch self {
        case .play: "target"
        case .statistics: "chart.bar"
        case .settings: "gearshape"
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .play: "Play"
        case .statistics: "Statistics"
        case .settings: "Settings"
        }
    }
}

/// Числа таб-бара из макета. Отдельным типом — чтобы сверялись тестом.
enum TabBarMetrics {
    static let height: CGFloat = 66
    static let radius = Geometry.Radius.panelLarge    // 26
    static let sideInset = Geometry.Inset.phoneSide   // 12
    static let bottomInset: CGFloat = 10
    static let iconSize: CGFloat = 24
    static let labelSize: CGFloat = 10
    static let iconLabelGap: CGFloat = 4
    /// Невыбранный таб гаснет **целиком** — это непрозрачность элемента как
    /// состояния, а не альфа внутри цвета, поэтому правило 8 не нарушено.
    static let inactiveOpacity: Double = 0.6
}

/// Нижняя панель навигации: стекло G2 с деревянным кантом по верхней кромке —
/// той, что смотрит в море.
struct SeaTabBar: View {
    @Binding var selection: ShellTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ShellTab.allCases, id: \.self) { tab in
                let isSelected = tab == selection
                // Кнопка, а не жест: таб должен быть кнопкой и для VoiceOver,
                // а выбранный — сообщать о себе, что он выбран.
                Button {
                    withAnimation(Motion.quick) { selection = tab }
                } label: {
                    VStack(spacing: TabBarMetrics.iconLabelGap) {
                        Image(systemName: tab.icon)
                            .font(.system(size: TabBarMetrics.iconSize * 0.75))
                            .frame(height: TabBarMetrics.iconSize)
                            .foregroundStyle(Color.inkPrimary)
                        Text(tab.title)
                            .font(.system(size: TabBarMetrics.labelSize,
                                          weight: isSelected ? .bold : .medium))
                            .foregroundStyle(isSelected ? Color.roleYou : Color.inkPrimary)
                    }
                    .frame(maxWidth: .infinity, minHeight: Geometry.Hit.minTarget)
                    .opacity(isSelected ? 1 : TabBarMetrics.inactiveOpacity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tab_\(tab.rawValue)")
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .frame(height: TabBarMetrics.height)
        .glassPanel(.g2, radius: TabBarMetrics.radius, wood: .top)
        .padding(.horizontal, TabBarMetrics.sideInset)
        .padding(.bottom, TabBarMetrics.bottomInset)
    }
}

// MARK: - Что открывает «Продолжить партию»

/// Незакрытых партий может быть три вида сразу: идущая прямо сейчас (она в
/// памяти), сохранённая против компьютера и начатая серия «вдвоём на
/// устройстве». Решение вынесено из вёрстки в чистую функцию — сетевую партию
/// продолжить нельзя вовсе, и перебор вариантов тут легко сократить не подумав.
enum ContinueTarget: Equatable, Sendable {
    /// Продолжать нечего — ссылки на экране нет.
    case none
    /// Партия идёт прямо сейчас: она живёт в памяти оболочки, и «Продолжить»
    /// просто возвращает на поле. Без этого случая партия становилась
    /// недоступной от одного выхода в меню: сохранение пишется только при
    /// уходе из приложения, поэтому в `GameStore` её ещё нет.
    case resume
    case vsComputer
    case hotSeat
    /// Есть и то и другое: спросить, что продолжаем.
    case ask

    static func resolve(isPlaying: Bool,
                        hasVsComputer: Bool,
                        hasHotSeat: Bool) -> ContinueTarget {
        // Партия в памяти свежее любого сохранения, поэтому идёт первой.
        if isPlaying { return .resume }
        return switch (hasVsComputer, hasHotSeat) {
        case (true, true): .ask
        case (true, false): .vsComputer
        case (false, true): .hotSeat
        case (false, false): .none
        }
    }

    var isAvailable: Bool { self != .none }
}

// MARK: - Оболочка

struct AppShell: View {

    @Environment(AppState.self) private var appState
    @Environment(PremiumManager.self) private var premiumManager
    @Environment(\.scenePhase) private var scenePhase

    /// Поля живут в оболочке, а не в экране боя: партия не должна теряться от
    /// того, что игрок вышел в меню посмотреть статистику.
    @State private var player = PlayerData(name: "Player")
    @State private var enemy = PlayerData(name: "Enemy")

    @State private var tab: ShellTab = .play
    @State private var askWhichGameToContinue = false
    @State private var modeNotBuiltYet: MenuMode?

    private var continueTarget: ContinueTarget {
        .resolve(isPlaying: appState.gameIsActive && !appState.gameIsOver,
                 hasVsComputer: GameStore.hasSavedGame,
                 hasHotSeat: HotSeatStore.hasSession)
    }

    var body: some View {
        @Bindable var appState = appState
        return Group {
            if appState.selectedTab == .menu {
                shell
            } else {
                // ПЕРЕХОДНОЕ: старый бой со своим фоном и деревянными панелями.
                LegacyBattleShell(player: player, enemy: enemy)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // Сохранение в стабильной точке — при уходе из приложения посреди
            // партии и не на ходу компьютера.
            if phase != .active && appState.gameIsActive && !appState.enemysTurn {
                GameStore.save(GameSnapshot(appState: appState, player: player, enemy: enemy))
            }
            if phase == .active {
                Task { await CloudSyncManager.shared.refresh() }
            }
        }
        .confirmationDialog("Continue game", isPresented: $askWhichGameToContinue,
                            titleVisibility: .visible) {
            Button("Play vs computer") { continueVsComputer() }
            Button("Two players") { appState.showHotSeat = true }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Not in this build yet", isPresented: .init(
            get: { modeNotBuiltYet != nil },
            set: { if !$0 { modeNotBuiltYet = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            // ПЕРЕХОДНОЕ: снимается, когда режим получит свой экран (R3.1).
            Text("This mode is still being built.")
        }
        .fullScreenCover(isPresented: $appState.showHotSeat) { HotSeatContainerView() }
        .fullScreenCover(isPresented: $appState.showNearby) { NearbyGameView() }
        .fullScreenCover(isPresented: $appState.showOnline) { OnlineGameView() }
        .sheet(isPresented: $appState.showPaywall) { PaywallView() }
        .onChange(of: premiumManager.isPremium) { _, isPremium in
            // Докончить то, из-за чего открывался пейволл.
            guard isPremium, let intent = appState.pendingPremiumIntent else { return }
            appState.pendingPremiumIntent = nil
            switch intent {
            case .expert:
                appState.difficulty = 3
                UserDefaults.standard.set(3, forKey: "difficulty")
            case .hotSeat, .nearby, .online:
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.4)) // дать пейволлу закрыться
                    switch intent {
                    case .hotSeat: appState.showHotSeat = true
                    case .nearby: appState.showNearby = true
                    case .online: appState.showOnline = true
                    case .expert: break
                    }
                }
            }
        }
        .onChange(of: appState.showPaywall) { _, shown in
            if !shown && !premiumManager.isPremium { appState.pendingPremiumIntent = nil }
        }
    }

    // MARK: Три таба

    private var shell: some View {
        ZStack {
            SeaBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                switch tab {
                case .play:
                    MenuScreen(isPremium: premiumManager.isPremium,
                               canContinue: continueTarget.isAvailable,
                               onMode: open(_:),
                               onContinue: continueGame)
                case .statistics:
                    // ПЕРЕХОДНОЕ: свой экран приходит в R4.1. Старый рисует
                    // собственный фон, поэтому моря под ним не видно.
                    StatsView()
                case .settings:
                    // ПЕРЕХОДНОЕ: свой экран приходит в R4.2.
                    SettingsView()
                }

                SeaTabBar(selection: $tab)
            }
        }
    }

    // MARK: Что делают строки меню

    private func open(_ item: MenuMode) {
        if appState.soundOn { AppState.playSound(sound: "click_sound.wav") }

        if item.isLocked(isPremium: premiumManager.isPremium) {
            appState.pendingPremiumIntent = intent(for: item.mode)
            appState.showPaywall = true
            return
        }

        switch item.mode {
        case .computer: startVsComputer()
        case .hotSeat: appState.showHotSeat = true
        case .nearby: appState.showNearby = true
        case .online: appState.showOnline = true
        case .paper: modeNotBuiltYet = item   // ПЕРЕХОДНОЕ до R3.1
        }
    }

    private func intent(for mode: GameMode) -> AppState.PremiumIntent? {
        switch mode {
        case .hotSeat: .hotSeat
        case .nearby: .nearby
        case .online: .online
        case .computer, .paper: nil
        }
    }

    /// ПЕРЕХОДНОЕ: пока нет своего экрана расстановки (R2.2), одиночная партия
    /// начинается так же, как в старом меню — со случайной расстановки.
    private func startVsComputer() {
        appState.resetData(player: player, enemy: enemy)
        player.shipsRandomArrangement()
        enemy.shipsRandomArrangement()
        appState.selectedTab = .playerView
    }

    private func continueGame() {
        if appState.soundOn { AppState.playSound(sound: "click_sound.wav") }
        switch continueTarget {
        case .none: break
        case .resume: appState.selectedTab = .enemyView
        case .vsComputer: continueVsComputer()
        case .hotSeat: appState.showHotSeat = true
        case .ask: askWhichGameToContinue = true
        }
    }

    private func continueVsComputer() {
        guard let snapshot = GameStore.load() else { return }
        snapshot.apply(to: appState, player: player, enemy: enemy)
        if appState.musicOn {
            AppState.playMusic(sound: "Battles_on_the_High_Seas.mp3")
        }
        appState.selectedTab = .enemyView
    }
}

// MARK: - ПЕРЕХОДНОЕ: старый бой

/// Старые экраны боя вместе с их деревянными панелями — ровно то, что раньше
/// рисовал `ContentView` вне меню. Поля приходят снаружи, из оболочки, поэтому
/// выход в меню партию не роняет. Уходит целиком в R2.3.
private struct LegacyBattleShell: View {
    @Environment(AppState.self) private var appState
    let player: PlayerData
    let enemy: PlayerData

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                switch appState.selectedTab {
                case .playerView:
                    PlayerFieldView(player: player, enemy: enemy)
                case .enemyView:
                    EnemyFieldView(player: player, enemy: enemy)
                case .about:
                    AboutView()
                case .menu, .iPadBattleView:
                    EmptyView()
                }

                VStack(spacing: 0) {
                    ZStack {
                        Image("wood")
                            .resizable()
                            .renderingMode(.original)
                            .frame(height: geometry.size.height * 0.10)
                        if appState.selectedTab == .playerView
                            || appState.selectedTab == .enemyView {
                            GameScoreView(
                                numberOfPlayersShipsDestroyed: player.numberShipsDestroyed,
                                numberOfEnemyShipsDestroyed: enemy.numberShipsDestroyed)
                                .padding(.horizontal, geometry.size.width * 0.04)
                        }
                    }
                    Spacer()
                    CustomTabView(relativeFontSize: geometry.size.width * 0.13,
                                  height: geometry.size.height * 0.11)
                }
                .ignoresSafeArea()
                .statusBar(hidden: true)
            }
        }
    }
}

// MARK: - Превью

#Preview("Оболочка · тёмная") {
    AppShell()
        .environment(AppState())
        .environment(PremiumManager())
        .preferredColorScheme(.dark)
}

#Preview("Оболочка · светлая") {
    AppShell()
        .environment(AppState())
        .environment(PremiumManager())
        .preferredColorScheme(.light)
}
