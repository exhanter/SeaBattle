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
//  ПЕРЕХОДНОЕ. Новые экраны статистики и настроек приходят позже
//  (R4.1–R4.2). До тех пор оболочка отдаёт управление старым экранам: они
//  работают, просто выглядят по-старому. Всё, что помечено `ПЕРЕХОДНОЕ`,
//  уходит вместе с ними в R4.6.
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

/// Все размеры таб-бара приходят из `Geometry.SizeClass` (таблица 3.3 спеки).
enum TabBarMetrics {
    /// Невыбранный таб гаснет **целиком** — это непрозрачность элемента как
    /// состояния, а не альфа внутри цвета, поэтому правило 8 не нарушено.
    static let inactiveOpacity: Double = 0.62
}

/// Нижняя панель навигации: стекло G2 с деревянным кантом по верхней кромке —
/// той, что смотрит в море.
struct SeaTabBar: View {
    @Binding var selection: ShellTab
    var size: Geometry.SizeClass = .regular

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ShellTab.allCases, id: \.self) { tab in
                let isSelected = tab == selection
                // Кнопка, а не жест: таб должен быть кнопкой и для VoiceOver,
                // а выбранный — сообщать о себе, что он выбран.
                Button {
                    withAnimation(Motion.quick) { selection = tab }
                } label: {
                    VStack(spacing: size.isCompact ? 3 : 5) {
                        Image(systemName: tab.icon)
                            .font(.system(size: symbolFontSize(inBox: size.tabIcon)))
                            .frame(height: size.tabIcon)
                            .foregroundStyle(Color.inkPrimary)
                        Text(tab.title)
                            .font(.system(size: size.tabLabel,
                                          weight: isSelected ? .bold : .medium,
                                          design: .rounded))
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
        .frame(height: size.tabHeight)
        .glassPanel(.g2, radius: size.tabRadius, wood: .top)
        .padding(.horizontal, size.tabInset)
        .padding(.bottom, size.tabBottom)
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
    /// Игра на бумаге (R3.1) — в памяти или в своём сохранении.
    case paper
    /// Незакрытых партий больше одной: спросить, что продолжаем.
    case ask

    static func resolve(isPlaying: Bool,
                        hasVsComputer: Bool,
                        hasHotSeat: Bool,
                        hasPaper: Bool = false) -> ContinueTarget {
        // Партия против компьютера в памяти свежее её же сохранения, поэтому
        // идёт первой; игра на бумаге — отдельная партия, и молча выбрать
        // одну из двух значит спрятать другую.
        if isPlaying { return hasPaper ? .ask : .resume }
        return switch (hasVsComputer, hasHotSeat, hasPaper) {
        case (false, false, false): .none
        case (true, false, false): .vsComputer
        case (false, true, false): .hotSeat
        case (false, false, true): .paper
        default: .ask
        }
    }

    var isAvailable: Bool { self != .none }
}

/// Экраны партии: открываются из меню и идут «вглубь», поэтому таб-бара на них
/// нет, а сверху стоит заголовок со строкой возврата (спека 3.1).
enum ShellRoute: Equatable, Sendable {
    case level
    /// Расстановка. Помнит, откуда пришли: строка возврата ведёт на уровень,
    /// если он показывался, иначе в меню, и подпись меняется вместе с этим
    /// (спека 3.1).
    case arrangement(cameFromLevel: Bool)
    /// Игра на бумаге (R3.1): расстановка своего флота, затем сама партия.
    /// Уровня у неё нет, поэтому возврат с расстановки — в меню.
    case paperArrangement
    case paper
}

// MARK: - Оболочка

struct AppShell: View {

    @Environment(AppState.self) private var appState
    @Environment(PremiumManager.self) private var premiumManager
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.usesPadLayout) private var usesPadLayout

    /// Бой живёт в оболочке, а не в экране: партия и ход компьютера не должны
    /// теряться от того, что игрок вышел в меню посмотреть статистику. Поля
    /// партии — `battle.player` и `battle.enemy`.
    @State private var battle = BattleController()
    private var player: PlayerData { battle.player }
    private var enemy: PlayerData { battle.enemy }

    @State private var tab: ShellTab = .play
    @State private var askWhichGameToContinue = false
    @State private var modeNotBuiltYet: MenuMode?

    /// Экран партии до боя, открытый поверх таба «Играть»: уровень или
    /// расстановка. Бой открывается по `AppState.selectedTab`, итоги — слой
    /// поверх боя (`BattleScreen`), своего маршрута у них нет.
    @State private var route: ShellRoute?
    /// Что выбрано на экране уровня. Живёт в оболочке, а не в экране: после
    /// покупки Pro прямо с него выбор должен стать «Экспертом».
    @State private var levelSelection: AppState.DifficultyLevel = .hard
    /// Расстановка. Тоже в оболочке: уход в меню и возврат не должны
    /// перемешивать флот, который игрок только что выставил руками.
    @State private var fleet = FleetEditor()
    /// Игра на бумаге. Живёт в оболочке, как бой: выход в меню её не
    /// закрывает, «Продолжить партию» возвращает в неё же.
    @State private var paper: PaperMatch?

    private var continueTarget: ContinueTarget {
        .resolve(isPlaying: appState.gameIsActive && !appState.gameIsOver,
                 hasVsComputer: GameStore.hasSavedGame,
                 hasHotSeat: HotSeatStore.hasSession,
                 hasPaper: hasPaperGame)
    }

    /// Партия на бумаге сохраняется после каждого хода, поэтому идущая в
    /// памяти всегда лежит и на диске; память проверяется первой только ради
    /// того, чтобы не читать файл на каждой перерисовке меню.
    private var hasPaperGame: Bool {
        if let paper { return !paper.game.isOver }
        return PaperStore.hasSavedGame
    }

    var body: some View {
        @Bindable var appState = appState
        return Group {
            if appState.selectedTab != .menu {
                ZStack {
                    SeaBackground()
                        .ignoresSafeArea()
                    BattleScreen(battle: battle,
                                 onLeave: leaveBattle,
                                 onPlayAgain: playAgain,
                                 onMenuAfterResult: closeFinishedMatch)
                }
            } else if let route {
                ZStack {
                    SeaBackground()
                        .ignoresSafeArea()
                    screen(for: route)
                }
            } else {
                shell
            }
        }
        .onAppear { battle.configure(appState: appState) }
        .onChange(of: scenePhase) { _, phase in
            // Сохранение в стабильной точке — при уходе из приложения посреди
            // партии и не на ходу компьютера.
            if phase != .active && appState.gameIsActive && !appState.enemysTurn {
                GameStore.save(battle.snapshot(of: appState))
            }
            if phase == .active {
                Task { await CloudSyncManager.shared.refresh() }
            }
        }
        .confirmationDialog("Continue game", isPresented: $askWhichGameToContinue,
                            titleVisibility: .visible) {
            if continueTarget == .ask {
                if appState.gameIsActive || GameStore.hasSavedGame {
                    Button("Play vs computer") { continueComputerGame() }
                }
                if HotSeatStore.hasSession {
                    Button("Two players") { appState.showHotSeat = true }
                }
                if hasPaperGame {
                    Button("Paper game") { continuePaper() }
                }
            }
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
                appState.difficultyLevel = .expert
                // Пейволл мог подняться с экрана уровня — тогда после покупки
                // выбранным должен стать «Эксперт», а не «Сложно», на котором
                // экран открылся.
                levelSelection = .expert
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

            GeometryReader { proxy in
                if usesPadLayout {
                    padShell(proxy.size)
                } else {
                    VStack(spacing: 0) {
                        tabContent
                        SeaTabBar(selection: $tab,
                                  size: .forWidth(proxy.size.width))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
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
    }

    /// iPad (спека 3 после раунда 7): таб-бара нет. Меню — свой экран
    /// (22a / 22b), корни «Статистика» и «Настройки» — колонка 520 по центру,
    /// внизу квадраты по углам на рамке 24.
    @ViewBuilder
    private func padShell(_ size: CGSize) -> some View {
        if tab == .play {
            PadMenuScreen(isPremium: premiumManager.isPremium,
                          canContinue: continueTarget.isAvailable,
                          continueLevel: continueLevel,
                          onMode: open(_:),
                          onContinue: continueGame,
                          onTab: selectTab)
        } else {
            let frame = Geometry.Inset.padFrame
            ZStack(alignment: .bottom) {
                tabContent
                    .frame(maxWidth: Geometry.Nav.padColumn)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, Geometry.Inset.padTile + Geometry.Nav.stackGap)
                PadCornerTabs(current: tab, onSelect: selectTab)
                    .padding(.horizontal, frame)
                    .padding(.bottom, frame)
                    .ignoresSafeArea(edges: .bottom)
            }
        }
    }

    private func selectTab(_ newTab: ShellTab) {
        if appState.soundOn { AppState.playSound(sound: "click_sound.wav") }
        withAnimation(Motion.quick) { tab = newTab }
    }

    /// Подпись под «Продолжить партию» на iPad — уровень партии, которая идёт
    /// прямо сейчас. У сохранённой партии уровень лежит в файле, читать его на
    /// каждой перерисовке меню незачем — там подписи нет.
    private var continueLevel: AppState.DifficultyLevel? {
        continueTarget == .resume ? appState.difficultyLevel : nil
    }

    // MARK: Экраны партии

    @ViewBuilder
    private func screen(for route: ShellRoute) -> some View {
        switch route {
        case .level:
            LevelScreen(selected: levelSelection,
                        isPremium: premiumManager.isPremium,
                        onSelect: { levelSelection = $0 },
                        onLocked: {
                            appState.pendingPremiumIntent = .expert
                            appState.showPaywall = true
                        },
                        onStart: startAfterLevel,
                        onBack: { self.route = nil },
                        // До начала боя «Меню» выходит без вопроса (спека 3.1).
                        onMenu: { self.route = nil })
                // iPad: колонка 520 pt по центру (4.3).
                .frame(maxWidth: usesPadLayout ? Geometry.Nav.padColumn : .infinity)

        case .arrangement(let cameFromLevel):
            ArrangementScreen(editor: $fleet,
                              backTitle: cameFromLevel ? "Level" : "Play",
                              onStart: startBattle,
                              onBack: { self.route = cameFromLevel ? .level : nil },
                              onMenu: { self.route = nil })

        case .paperArrangement:
            ArrangementScreen(editor: $fleet,
                              backTitle: "Play",
                              onStart: startPaper,
                              onBack: { self.route = nil },
                              onMenu: { self.route = nil })

        case .paper:
            if let paper {
                PaperScreen(match: paper,
                            onLeave: { self.route = nil },
                            onPlayAgain: {
                                self.paper = nil
                                openPaperArrangement()
                            },
                            onMenuAfterResult: {
                                self.paper = nil
                                self.route = nil
                            })
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
        case .computer: openSinglePlayer()
        case .hotSeat: appState.showHotSeat = true
        case .nearby: appState.showNearby = true
        case .online: appState.showOnline = true
        case .paper:
            // ПЕРЕХОДНОЕ до R3.1b: на iPad игра на бумаге встанет на стол
            // третьей фазой, отдельного экрана там не будет.
            if usesPadLayout { modeNotBuiltYet = item } else { openPaperArrangement() }
        }
    }

    // MARK: Игра на бумаге

    /// Новая партия на бумаге — с расстановки своего флота. Прежняя
    /// незакрытая перезаписывается, как и сохранение против компьютера.
    private func openPaperArrangement() {
        fleet = FleetEditor()
        route = .paperArrangement
    }

    /// «Старт» на расстановке: партия начинается с этим флотом и сразу
    /// сохраняется — «Продолжить» должна найти её даже без единого хода.
    private func startPaper() {
        let game = PaperGame(fleet: fleet.ships, revealsRing: appState.autoRevealAroundSunk)
        let match = PaperMatch(game: game)
        match.soundOn = appState.soundOn
        PaperStore.save(game)
        paper = match
        route = .paper
    }

    private func continuePaper() {
        if paper?.game.isOver ?? true {
            guard let game = PaperStore.load() else { return }
            let match = PaperMatch(game: game)
            match.soundOn = appState.soundOn
            paper = match
        }
        route = .paper
    }

    /// Шаг выбора уровня показывается по умолчанию; тумблер в настройках его
    /// снимает, но исключение с «Экспертом» без Pro сильнее тумблера (4.3).
    private func openSinglePlayer() {
        switch LevelStep.resolve(remembered: appState.difficultyLevel,
                                 askBeforeMatch: appState.askLevelBeforeMatch,
                                 isPremium: premiumManager.isPremium) {
        case .ask(let selected):
            levelSelection = selected
            route = .level
        case .start(let level):
            appState.difficultyLevel = level
            openArrangement(cameFromLevel: false)
        }
    }

    /// «Начать партию» на экране уровня: выбранный уровень запоминается — в том
    /// числе когда это «Сложно», подставленное вместо закрытого «Эксперта».
    private func startAfterLevel() {
        appState.difficultyLevel = levelSelection
        openArrangement(cameFromLevel: true)
    }

    /// Расстановка открывается с новым случайным флотом: это новая партия, а не
    /// продолжение прошлой.
    private func openArrangement(cameFromLevel: Bool) {
        fleet = FleetEditor()
        route = .arrangement(cameFromLevel: cameFromLevel)
    }

    private func intent(for mode: GameMode) -> AppState.PremiumIntent? {
        switch mode {
        case .hotSeat: .hotSeat
        case .nearby: .nearby
        case .online: .online
        case .computer, .paper: nil
        }
    }

    /// «Старт» на расстановке: партия начинается с тем флотом, который игрок
    /// только что видел на экране.
    ///
    /// Флот компьютера расставляет `ComputerOpponent` — по уровню, со сокрытием
    /// у двух верхних. До R2.2 здесь стояло `enemy.shipsRandomArrangement()`, и
    /// сокрытие не применялось в живой партии вообще.
    private func startBattle() {
        appState.resetData(player: player, enemy: enemy)
        player.place(fleet.ships)
        ComputerOpponent.arrangeFleet(for: appState.difficultyLevel, on: enemy)

        if appState.musicOn {
            AppState.playMusic(sound: "Battles_on_the_High_Seas.mp3")
        }
        appState.gameIsActive = true
        appState.manualShipArrangement = false
        battle.beginMatch()
        route = nil
        appState.selectedTab = .enemyView
    }

    /// «Выйти» в окне «Выйти из партии?». Партия остаётся в памяти и в меню
    /// появляется «Продолжить партию» (3.1); на диск она пишется здесь же,
    /// если сейчас стабильная точка, — иначе её сохранит ход компьютера,
    /// когда доиграет.
    private func leaveBattle() {
        if appState.gameIsActive && !appState.enemysTurn {
            GameStore.save(battle.snapshot(of: appState))
        }
        battle.leave()
        appState.selectedTab = .menu
    }

    /// «Ещё партия» / «Отыграться» на итогах — новая расстановка на том же
    /// уровне, без шага выбора: игрок только что сыграл на нём и просит ещё.
    private func playAgain() {
        closeFinishedMatch()
        openArrangement(cameFromLevel: false)
    }

    private func closeFinishedMatch() {
        battle.beginMatch()
        appState.resetData(player: player, enemy: enemy)
    }

    private func continueGame() {
        if appState.soundOn { AppState.playSound(sound: "click_sound.wav") }
        switch continueTarget {
        case .none: break
        case .resume: resumeBattle()
        case .vsComputer: continueVsComputer()
        case .hotSeat: appState.showHotSeat = true
        case .paper: continuePaper()
        case .ask: askWhichGameToContinue = true
        }
    }

    /// Компьютер мог ещё доигрывать ход, пока игрок был в меню, — тогда
    /// возвращаемся на своё поле, туда он и стреляет.
    private func resumeBattle() {
        appState.selectedTab = appState.enemysTurn ? .playerView : .enemyView
    }

    /// «Против компьютера» в вопросе, что продолжаем: партия в памяти, если
    /// она есть, иначе сохранение.
    private func continueComputerGame() {
        if appState.gameIsActive && !appState.gameIsOver {
            resumeBattle()
        } else {
            continueVsComputer()
        }
    }

    private func continueVsComputer() {
        guard let snapshot = GameStore.load() else { return }
        snapshot.apply(to: appState, player: player, enemy: enemy)
        battle.beginMatch(tally: snapshot.tally ?? MatchTally())
        if appState.musicOn {
            AppState.playMusic(sound: "Battles_on_the_High_Seas.mp3")
        }
        appState.selectedTab = .enemyView
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
