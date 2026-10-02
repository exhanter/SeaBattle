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
//  ПЕРЕХОДНОЕ. Пейволл и «Об игре» пока старые: оболочка отдаёт им
//  управление листом, они работают, просто выглядят по-старому. Всё, что
//  помечено `ПЕРЕХОДНОЕ`, уходит вместе с ними в R4.3 и R4.6.
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
    /// Вдвоём на устройстве (R3.2): настройка, затем вся партия одним
    /// контейнером — расстановки, слой передачи и бой (4.7).
    case duelSetup
    case duel
    /// Рядом без сети (R3.3): поиск устройств, затем партия.
    case nearby
    /// По сети (R3.3b): выбор, поиск, код, «Нет соединения» — до партии.
    case online
    /// Сетевая партия — рядом или по сети, один экран на оба транспорта.
    case network
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
    /// Экран внутри таба «Статистика»; `nil` — сама страница статистики.
    @State private var statsPage: StatsPage?
    /// Счёт серии сохранённой партии вдвоём — читается с диска при входе в
    /// статистику, а не на каждой перерисовке.
    @State private var duelSeries: [Int]?
    @State private var askWhichGameToContinue = false

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
    /// Вдвоём на устройстве: набранное на настройке переживает уход на
    /// расстановку и возврат; партия живёт в оболочке, как бой.
    @State private var duelSetup = DuelSetup()
    @State private var duel: DuelMatch?
    /// Поиск устройств рядом. Транспорт переходит в партию, когда соперник
    /// подключился.
    @State private var nearbyTransport: MultipeerTransport?
    /// Вход в «По сети». Живёт и во время партии приглашающего, пока соперник
    /// не пришёл: код ещё ищется, а флот уже расставляют.
    @State private var online: OnlineLobby?
    /// Код «вечеринки», пришедший по ссылке или из приложения «Игры», пока
    /// игрок занят другой партией или покупает Pro: «По сети» откроется с ним.
    @State private var linkCode: InviteCode?
    /// Окно «Pro — на iOS 26» вместо пейволла на iOS 18 (решение 01.10).
    @State private var proUnavailable = false
    /// Короткий лист Pro про режим, на который нажали (спека 4.12).
    @State private var lockedIntent: AppState.PremiumIntent?
    /// Страница внутри таба «Настройки» («Pro активен»).
    @State private var settingsPage: SettingsPage?
    /// «О приложении» из настроек.
    @State private var showAbout = false
    /// Сетевая партия. Продолжить её из меню нельзя: выход из неё — сдача
    /// или конец связи, поэтому она живёт ровно столько, сколько экран.
    @State private var net: NetMatch?

    private var continueTarget: ContinueTarget {
        .resolve(isPlaying: appState.gameIsActive && !appState.gameIsOver,
                 hasVsComputer: GameStore.hasSavedGame,
                 hasHotSeat: hasHotSeatGame,
                 hasPaper: hasPaperGame)
    }

    /// Партия на бумаге сохраняется после каждого хода, поэтому идущая в
    /// памяти всегда лежит и на диске; память проверяется первой только ради
    /// того, чтобы не читать файл на каждой перерисовке меню.
    private var hasPaperGame: Bool {
        if let paper { return !paper.game.isOver }
        return PaperStore.hasSavedGame
    }

    private var hasHotSeatGame: Bool {
        if let duel { return !duel.game.isOver }
        return DuelStore.hasSavedGame
    }

    var body: some View {
        @Bindable var appState = appState
        return Group {
            if !appState.onboardingDone {
                ZStack {
                    SeaBackground()
                        .ignoresSafeArea()
                    OnboardingFlow(isPremium: premiumManager.isPremium,
                                   onRestore: restorePro,
                                   onFinish: finishOnboarding)
                        // iPad: колонка 520 pt по центру, как экран уровня.
                        .frame(maxWidth: usesPadLayout ? Geometry.Nav.padColumn : .infinity)
                }
                .transition(.opacity)
            } else if appState.selectedTab != .menu {
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
                if hasHotSeatGame {
                    Button("Two players") { continueHotSeat() }
                }
                if hasPaperGame {
                    Button("Paper game") { continuePaper() }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .proLockedSheet(intent: lockedIntent, onDismiss: closeLockedSheet) { intent in
            ProLockedSheet(intent: intent,
                           offers: premiumManager.offers,
                           hasLoaded: premiumManager.hasLoadedProducts,
                           onBuy: { await premiumManager.purchase($0) },
                           onMore: {
                               // Намерение остаётся: купив на полном экране,
                               // человек всё равно попадёт в свой режим.
                               lockedIntent = nil
                               appState.showPaywall = true
                           })
        }
        .fullScreenCover(isPresented: $appState.showPaywall) {
            ZStack {
                SeaBackground()
                    .ignoresSafeArea()
                ProPaywallScreen(offers: premiumManager.offers,
                                 hasLoaded: premiumManager.hasLoadedProducts,
                                 onBuy: { await premiumManager.purchase($0) },
                                 onRestore: restorePro,
                                 onClose: { appState.showPaywall = false })
                    .frame(maxWidth: usesPadLayout ? Geometry.Nav.padColumn : .infinity)
            }
            .task {
                if !premiumManager.hasLoadedProducts || premiumManager.offers.isEmpty {
                    await premiumManager.loadProducts()
                }
            }
        }
        // ПЕРЕХОДНОЕ: старый экран «Об игре» — правила, авторы картинок и
        // звуков (их лицензии требуют упоминания) и контакты. Своего кадра у
        // «О приложении» нет; уйдёт со старыми представлениями в R4.6.
        .sheet(isPresented: $showAbout) { AboutView() }
        .modalDialog(isPresented: proUnavailable) {
            NoticeDialog.proNeedsNewerSystem { proUnavailable = false }
        }
        .modifier(GameActivityLinks(onCode: openFromLink))
        .onChange(of: premiumManager.isPremium) { _, isPremium in
            // Докончить то, из-за чего открывался пейволл.
            guard isPremium else { return }
            // Лист и полный экран закрываются сами, как только Pro появился —
            // в том числе после покупки на другом устройстве.
            lockedIntent = nil
            appState.showPaywall = false
            guard let intent = appState.pendingPremiumIntent else { return }
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
                    case .hotSeat: openHotSeat()
                    case .nearby: openNearby()
                    case .online: openOnline()
                    case .expert: break
                    }
                }
            }
        }
        // Таб-бар iPhone меняет таб напрямую, мимо `selectTab`.
        .onChange(of: tab) {
            statsPage = nil
            settingsPage = nil
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
                        if !hidesTabs {
                            SeaTabBar(selection: $tab,
                                      size: .forWidth(proxy.size.width))
                        }
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
            statistics
        case .settings:
            switch settingsPage {
            case nil:
                SettingsScreen(isPremium: premiumManager.isPremium,
                               levelLocked: appState.gameIsActive && !appState.gameIsOver,
                               onLevelLocked: { openPro(intent: .expert) },
                               // На iOS 18 строки Pro нет (решение 8). С Pro строка
                               // ведёт на «Pro активен», без него — на полный экран.
                               onPro: PremiumManager.isOffered ? {
                                   if premiumManager.isPremium { settingsPage = .pro } else { openPro(intent: nil) }
                               } : nil,
                               onAbout: { showAbout = true },
                               onPlayer: { settingsPage = .player })
            case .player:
                PlayerNameScreen(player: Binding(get: { appState.ownPlayer ?? .starter },
                                                 set: { appState.ownPlayer = $0 }),
                                 purpose: .settings,
                                 onBack: { settingsPage = nil })
            case .pro:
                ProActiveScreen(entitlement: premiumManager.entitlement,
                                onBack: { settingsPage = nil },
                                onRestore: restorePro)
            }
        }
    }

    /// Сброс прячет таб-бар (на iPad — квадраты по углам): внизу у него свои
    /// две кнопки (кадр `screen10Reset`).
    private var hidesTabs: Bool { tab == .statistics && statsPage?.hidesTabBar == true }

    @ViewBuilder
    private var statistics: some View {
        let progress = ProgressStore.shared
        switch statsPage {
        case nil:
            StatsScreen(stats: progress.stats,
                        isPremium: premiumManager.isPremium,
                        duelSeries: duelSeries,
                        onPlay: { selectTab(.play) },
                        onWallet: { statsPage = .wallet },
                        onReset: { statsPage = .reset })
                .onAppear { duelSeries = DuelStore.load()?.series }
        case .wallet:
            WalletScreen(points: progress.points,
                         entries: progress.ledger,
                         onBack: { statsPage = nil },
                         onHistory: { statsPage = .history })
        case .history:
            PointsHistoryScreen(entries: progress.ledger,
                                onBack: { statsPage = .wallet })
        case .reset:
            ResetScreen(onReset: { selection in
                            progress.reset(selection)
                            statsPage = nil
                        },
                        onCancel: { statsPage = nil })
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
                    // Настройки — в две колонки, им 520 мало (4.11).
                    .frame(maxWidth: tab == .settings && settingsPage == nil
                           ? SettingsMetrics.padWidth : Geometry.Nav.padColumn)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, hidesTabs ? 0 : Geometry.Inset.padTile + Geometry.Nav.stackGap)
                if !hidesTabs {
                    PadCornerTabs(current: tab, onSelect: selectTab)
                        .padding(.horizontal, frame)
                        .padding(.bottom, frame)
                        .ignoresSafeArea(edges: .bottom)
                }
            }
        }
    }

    private func selectTab(_ newTab: ShellTab) {
        if appState.soundOn { AppState.playSound(sound: "click_sound.wav") }
        withAnimation(Motion.quick) { tab = newTab }
        // Нажатие на таб возвращает на его корень, как в системных табах.
        statsPage = nil
        settingsPage = nil
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
                        onLocked: { openPro(intent: .expert) },
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
                              onMenu: { self.route = nil },
                              isPaper: true)

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

        case .duelSetup:
            DuelSetupScreen(setup: $duelSetup,
                            recent: recentPlayers,
                            onStart: startDuel,
                            onBack: { self.route = nil })
                // iPad: колонка 520 pt по центру, как экран уровня.
                .frame(maxWidth: usesPadLayout ? Geometry.Nav.padColumn : .infinity)

        case .duel:
            if let duel {
                DuelScreen(match: duel,
                           onBackToSetup: {
                               // Партия ещё не начата — к настройке, без сохранения.
                               DuelStore.clear()
                               self.duel = nil
                               self.route = .duelSetup
                           },
                           onLeave: {
                               // Кто возьмёт устройство в меню, неизвестно:
                               // партия закрывается слоем сразу.
                               duel.relock()
                               self.route = nil
                           },
                           onPlayAgain: { duel.playAgain() },
                           onMenuAfterResult: {
                               // «В меню» после итогов кончает серию (4.9).
                               DuelStore.clear()
                               self.duel = nil
                               self.route = nil
                           })
            }

        case .nearby:
            if let nearbyTransport {
                NearbyScreen(transport: nearbyTransport, onBack: closeNearby)
                    // iPad: колонка 520 pt по центру, как экран уровня.
                    .frame(maxWidth: usesPadLayout ? Geometry.Nav.padColumn : .infinity)
            }

        case .online:
            if let online {
                OnlineScreen(lobby: online,
                             hasArrangedAhead: net != nil,
                             onArrangeAhead: arrangeAhead,
                             onNearby: {
                                 closeOnline()
                                 openNearby()
                             },
                             onSinglePlayer: {
                                 closeOnline()
                                 openSinglePlayer()
                             },
                             onBack: closeOnline)
                    // iPad: колонка 520 pt по центру, как «Рядом».
                    .frame(maxWidth: usesPadLayout ? Geometry.Nav.padColumn : .infinity)
            }

        case .network:
            if let net {
                NetScreen(match: net,
                          onExit: {
                              self.net = nil
                              self.nearbyTransport = nil
                              closeOnline()
                          },
                          onBackToCode: isArrangingAhead ? { self.route = .online } : nil)
            }
        }
    }

    // MARK: Сетевые режимы

    /// Как игрок назван у соперника: владелец устройства (R4.4). Пропустил
    /// имя — первый из «Играли раньше», так было до онбординга; иначе «Игрок».
    private var localPlayer: (name: String, glyph: String, colorIndex: Int) {
        if let own = appState.ownPlayer, !own.trimmedName.isEmpty {
            return (own.trimmedName, own.glyph, own.colorIndex)
        }
        let profile = ProfileStore.shared.profiles.first
        let name = profile?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return (name.isEmpty ? String(game: "Player") : name,
                profile?.avatar ?? "sailboat.fill",
                profile?.colorIndex ?? 0)
    }

    private func openNearby() {
        let transport = MultipeerTransport(displayName: localPlayer.name,
                                           model: usesPadLayout ? "iPad" : "iPhone")
        transport.onConnectionChange = { connected in
            guard connected, self.net == nil else { return }
            self.startNetwork(transport, key: .nearby, accountID: AccountID.current(),
                              name: self.localPlayer.name)
        }
        nearbyTransport = transport
        route = .nearby
    }

    private func closeNearby() {
        nearbyTransport?.disconnect()
        nearbyTransport = nil
        route = nil
    }

    /// «По сети» — только iOS 26+: на iOS 18 Pro не продаётся, а купленный
    /// на другом устройстве Pro сюда всё равно не пускает (Game Center party
    /// codes есть только с iOS 26).
    private func openOnline() {
        guard #available(iOS 26.0, *) else {
            proUnavailable = true
            return
        }
        let code = linkCode
        linkCode = nil
        let lobby = OnlineLobby(service: GameCenterService(), joining: code)
        lobby.onFound = { transport in self.onlineFound(transport) }
        // Код истёк, пока приглашающий расставлял флот: назад к коду, флот
        // остаётся в партии.
        lobby.onInviteEnded = {
            if self.route == .network { self.route = .online }
        }
        online = lobby
        route = .online
    }

    /// Партия приглашающего создана заранее на отложенном транспорте, и
    /// соперник ещё не пришёл.
    private var isArrangingAhead: Bool {
        guard let online, let host = online.hostTransport else { return false }
        return net != nil && !host.isAttached
    }

    /// Соперник найден. Если флот уже расставлялся заранее, партия есть —
    /// транспорт под ней только что подключился, остаётся показать её.
    private func onlineFound(_ transport: any NetworkTransport) {
        if net != nil {
            route = .network
            return
        }
        guard let online else {
            transport.disconnect()
            return
        }
        startNetwork(transport, key: .online, accountID: online.service.playerID,
                     name: online.service.playerName)
    }

    /// «Расставить флот заранее»: партия на транспорте кода, соперника пока нет.
    private func arrangeAhead() {
        guard let online, let host = online.hostTransport else { return }
        if net == nil {
            startNetwork(host, key: .online, accountID: online.service.playerID,
                         name: online.service.playerName)
        } else {
            route = .network
        }
    }

    /// Код пришёл по ссылке или из «Игр». Без Pro — сначала пейволл, «По сети»
    /// откроется после покупки с этим же кодом. Посреди другой партии код
    /// ждёт, пока игрок сам откроет «По сети», — партию не обрываем.
    private func openFromLink(_ code: InviteCode) {
        if let online {
            online.joinFromLink(code)
            route = .online
            return
        }
        linkCode = code
        guard premiumManager.isPremium else {
            openPro(intent: .online)
            return
        }
        let inMenu = route == nil && appState.selectedTab == .menu
        if inMenu { openOnline() }
    }

    private func closeOnline() {
        online?.leave()
        online = nil
        route = nil
    }

    private func startNetwork(_ transport: any NetworkTransport, key: StatKey,
                              accountID: String, name: String) {
        let me = localPlayer
        let match = NetMatch(transport: transport, statKey: key,
                             me: NetMatch.hello(name: name, glyph: me.glyph,
                                                colorIndex: me.colorIndex, accountID: accountID),
                             revealsRing: appState.autoRevealAroundSunk)
        match.soundOn = appState.soundOn
        match.confirmShot = appState.confirmShot
        match.start()
        net = match
        route = .network
    }

    // MARK: Что делают строки меню

    /// Pro (спека 4.12): с режимом — короткий лист про него, без режима
    /// (строка «Pro» в настройках) — полный экран. На iOS 18 — окно «Pro — на
    /// iOS 26» (решение 8).
    private func openPro(intent: AppState.PremiumIntent?) {
        guard PremiumManager.isOffered else {
            proUnavailable = true
            return
        }
        appState.pendingPremiumIntent = intent
        if let intent {
            lockedIntent = intent
        } else {
            appState.showPaywall = true
        }
    }

    /// Лист закрыт мимо покупки: режим после неё открывать уже незачем.
    private func closeLockedSheet() {
        lockedIntent = nil
        if !premiumManager.isPremium { appState.pendingPremiumIntent = nil }
    }

    /// «Восстановить покупку»; вернуть — нашёлся ли Pro.
    private func restorePro() async -> Bool {
        await premiumManager.restore()
        return premiumManager.isPremium
    }

    private func open(_ item: MenuMode) {
        if appState.soundOn { AppState.playSound(sound: "click_sound.wav") }

        if item.isLocked(isPremium: premiumManager.isPremium) {
            openPro(intent: intent(for: item.mode))
            return
        }

        switch item.mode {
        case .computer: openSinglePlayer()
        case .hotSeat: openHotSeat()
        case .nearby: openNearby()
        case .online: openOnline()
        case .paper: openPaperArrangement()
        }
    }

    // MARK: Вдвоём на устройстве

    private func openHotSeat() {
        if let own = appState.ownPlayer { duelSetup.seat(own) }
        route = .duelSetup
    }

    /// Конец первого запуска: «Готово» отдаёт игрока, «Пропустить» — `nil`.
    private func finishOnboarding(_ own: OwnPlayer?) {
        if let own { appState.ownPlayer = own }
        withAnimation(Motion.standard) { appState.onboardingDone = true }
    }

    /// «Играли раньше» — последние сыгравшие первыми.
    private var recentPlayers: [RecentPlayer] {
        ProfileStore.shared.profiles.reversed().map {
            RecentPlayer(name: $0.name, glyph: $0.avatar, colorIndex: $0.colorIndex ?? 0)
        }
    }

    /// Главная кнопка настройки. Набранные имена запоминаются для «Играли
    /// раньше»; «Игрок 1» и «Игрок 2» — нет. Новая серия перезаписывает
    /// прежнюю незакрытую, как и сохранение против компьютера.
    private func startDuel() {
        for player in duelSetup.players {
            let name = player.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            ProfileStore.shared.upsert(name: name, avatar: player.glyph, colorIndex: player.colorIndex)
        }
        let match = DuelMatch(game: DuelGame(setup: duelSetup,
                                             revealsRing: appState.autoRevealAroundSunk))
        configure(match)
        DuelStore.save(match.game)
        duel = match
        route = .duel
    }

    private func configure(_ match: DuelMatch) {
        match.soundOn = appState.soundOn
        match.confirmShot = appState.confirmShot
    }

    private func continueHotSeat() {
        if duel?.game.isOver ?? true {
            guard let game = DuelStore.load() else { return }
            let match = DuelMatch(game: game)
            configure(match)
            duel = match
        }
        // Поля открывает только слой: кто взял устройство в меню, неизвестно.
        duel?.relock()
        route = .duel
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
        case .hotSeat: continueHotSeat()
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

// MARK: - Ссылки на партию

/// Принимает коды «вечеринок» извне (iOS 26+): при запуске и при каждом
/// возвращении в приложение спрашивает Game Center, не ждёт ли активность,
/// и отдаёт пришедший код оболочке.
private struct GameActivityLinks: ViewModifier {
    let onCode: (InviteCode) -> Void
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            let router = GameActivityRouter.shared
            content
                .task { await router.checkPending() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await router.checkPending() } }
                }
                .onChange(of: router.pendingCode) { _, code in
                    guard let code else { return }
                    router.pendingCode = nil
                    onCode(code)
                }
        } else {
            content
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
