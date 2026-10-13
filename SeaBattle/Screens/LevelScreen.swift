//
//  LevelScreen.swift
//  Sea Battle — уровень компьютера (R2.1a, шаг 5a порядка сборки)
//
//  Спека 4.3. Шаг между меню и расстановкой: четыре уровня, «Эксперт» под
//  замком, главная кнопка «Начать партию». Капсулы с характеристикой и
//  настройки партии под ними — iPhone с 06.10, iPad с 10.10.
//
//  Капсула уровня в бою (`LevelChip`, спека 4.5) лежит здесь же, а не в
//  дизайн-системе: значок и название уровня у списка и у капсулы одни и те же,
//  и держать их в двух файлах — значит однажды показать в бою «бинокль» там,
//  где в списке стоял «прицел».
//

import SwiftUI

// MARK: - Уровень как строка списка

/// Уровень глазами игрока: значок и название; характеристика в два-три
/// слова — `DifficultyLevel.trait`. Значок — шкала силы (`cellularbars`, 1–4
/// деления; выбор заказчика 07.10 вместо морских значков: по ним порядок
/// уровней не угадать).
struct LevelChoice: Identifiable {
    let level: AppState.DifficultyLevel
    let title: LocalizedStringKey

    var id: AppState.DifficultyLevel { level }

    var icon: String { Self.icon }
    var iconValue: Double { Self.iconValue(for: level) }

    /// Один символ на все уровни — различает их заполненность.
    static let icon = "cellularbars"

    /// Деления шкалы: «Легко» — одно из четырёх, «Эксперт» — все.
    static func iconValue(for level: AppState.DifficultyLevel) -> Double {
        let all = AppState.DifficultyLevel.allCases
        let index = all.firstIndex(of: level).map { all.distance(from: all.startIndex, to: $0) } ?? 0
        return Double(index + 1) / Double(all.count)
    }

    /// Замок — только у «Эксперта» и только без Pro. Строка при этом выглядит
    /// как остальные: закрытый уровень остаётся приглашением, а не запретом.
    func isLocked(isPremium: Bool) -> Bool { level.isPremium && !isPremium }

    /// Порядок как в модели: от слабого к сильному.
    static var all: [LevelChoice] {
        AppState.DifficultyLevel.allCases.map { level in
            switch level {
            case .easy: LevelChoice(level: level, title: "Easy")
            case .medium: LevelChoice(level: level, title: "Medium")
            case .hard: LevelChoice(level: level, title: "Hard")
            case .expert: LevelChoice(level: level, title: "Expert")
            }
        }
    }

    static func title(for level: AppState.DifficultyLevel) -> LocalizedStringKey {
        all.first { $0.level == level }?.title ?? ""
    }
}

// MARK: - Как играет уровень

extension AppState.DifficultyLevel {
    /// Как играет уровень, одной-двумя фразами — под капсулами (выбор
    /// заказчика 13.10) и в «Настройках». В капсуле место на два-три слова, а
    /// «Эксперту» с 13.10 есть что сказать: он замечает, что флот спрятан.
    var blurb: LocalizedStringKey {
        switch self {
        case .easy: "Finishes off a ship it has found, but keeps shooting at the water around a sunk one"
        case .medium: "Finishes off a ship it has found and never wastes shots on the water around it"
        case .hard: "Shoots every other cell, so it finds the big ships sooner"
        case .expert: "Works out where your ships can still be and notices when you hide them along the edges. Now and then hides its own fleet"
        }
    }
}

// MARK: - Показывать ли шаг выбора

/// Что делает нажатие «Одиночная игра» в меню. Вынесено в чистую функцию:
/// правил три, и одно из них — исключение, которое легко потерять.
enum LevelStep: Equatable, Sendable {
    /// Показать экран уровня с этим выбранным.
    case ask(selected: AppState.DifficultyLevel)
    /// Сразу к расстановке на этом уровне.
    case start(AppState.DifficultyLevel)

    static func resolve(remembered: AppState.DifficultyLevel,
                        askBeforeMatch: Bool,
                        isPremium: Bool) -> LevelStep {
        // Запомнен «Эксперт», а Pro нет или истёк: экран показывается **даже
        // при выключенном тумблере**, выбрано «Сложно». Молча понижать нельзя —
        // игрок решит, что компьютер поглупел; сразу поднимать пейволл тоже
        // нельзя — человек пришёл играть (спека 4.3).
        if remembered.isPremium && !isPremium {
            return .ask(selected: .freeFallback)
        }
        return askBeforeMatch ? .ask(selected: remembered) : .start(remembered)
    }
}

// MARK: - Числа экрана

enum LevelMetrics {
    /// Надзаголовок «Уровень соперника».
    static let overlineSize: CGFloat = 11
    static let overlineTracking: CGFloat = 11 * 0.11
    static let overlineInset: CGFloat = 4
    static let listGap: CGFloat = 10
    /// Отступ надзаголовка «Партия» над ставкой.
    static let matchTop: CGFloat = 14
    /// Радиус карточки ставки в семействе форм `legacy`.
    static let noteRadius: CGFloat = 16
    static let sideInset = Geometry.Nav.titleInset - Geometry.Nav.stackInset  // 8
}

// MARK: - Экран

/// iPhone (выбор заказчика 06.10): капсулы с названием и характеристикой в
/// два-три слова, под ними — настройки партии. Строки с описанием поведения в
/// капсулах выходили толстыми, а пояснение плашкой — «ни к селу». На iPad —
/// свой экран двумя колонками (`PadLevelScreen`, выбор заказчика 13.10).
struct LevelScreen: View {
    let selected: AppState.DifficultyLevel
    let isPremium: Bool
    var onSelect: (AppState.DifficultyLevel) -> Void = { _ in }
    /// Нажатие на закрытый «Эксперт»: поднимает лист Pro, выбор не меняет.
    var onLocked: () -> Void = {}
    var onStart: () -> Void = {}
    var onBack: () -> Void = {}
    var onMenu: () -> Void = {}
    /// Ставка, обводка и звук.
    var options = LevelMatchOptions()

    @Environment(\.usesPadLayout) private var usesPadLayout
    /// Высота области прокрутки и содержимого в ней — чтобы убрать тумблер
    /// обводки, когда всё не помещается без прокрутки.
    @State private var viewportHeight: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var markWaterSlot: CGFloat = Geometry.Bottom.controlHeight + 8
    @State private var showsMarkWater = true
    /// Описание выбранного уровня под капсулами и его место (с отступом).
    /// Уходит первым, раньше тумблера обводки: на iPhone SE его нет.
    @State private var blurbSlot: CGFloat = 72
    @State private var showsBlurb = true

    var body: some View {
        if usesPadLayout {
            PadLevelScreen(selected: selected, isPremium: isPremium, onSelect: onSelect,
                           onLocked: onLocked, onStart: onStart, onBack: onBack,
                           onMenu: onMenu, options: options)
                // iPad: квадраты по углам (выбор заказчика 13.10).
                .environment(\.bottomChrome, .tiles)
        } else {
            phoneBody
        }
    }

    private var phoneBody: some View {
        VStack(spacing: 0) {
            ScreenTitle(title: "Single player", back: "Play", onBack: onBack)
                .padding(.top, NavMetrics.titleTopBelowSafeArea)

            ScrollView {
                VStack(alignment: .leading, spacing: LevelMetrics.listGap) {
                    overline
                    capsuleList
                    matchSection
                }
                .padding(.horizontal, Geometry.Nav.stackInset)
                .padding(.top, Geometry.Nav.titleGap * 2)
                .padding(.bottom, Geometry.Nav.titleGap)
                // Своя высота, а не предложенная: иначе рамка по центру
                // растягивает строки на весь экран.
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
                .frame(maxWidth: .infinity)
            }
            .seaScroll()
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { viewportHeight = $0 }
            .onChange(of: contentHeight) { fitOptionalRows() }
            .onChange(of: viewportHeight) { fitOptionalRows() }

            BottomStack(onMenu: onMenu) {
                // Форма с явной надписью, а не `Button("…", action:)`:
                // инструментирование превью на второй спотыкается внутри
                // своего `@ViewBuilder` («ambiguous use of
                // `__designTimeSelection`»), хотя сборка проходит.
                // «Эксперт» без Pro можно выбрать, чтобы прочесть, как он
                // играет (заказчик 13.10), но не начать: кнопка зовёт Pro.
                if selectedIsLocked {
                    Button(action: onLocked) {
                        Text("Unlock with Pro")
                    }
                    .primaryButton()
                } else {
                    Button(action: onStart) {
                        Text("Start match")
                    }
                    .primaryButton()
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var selectedIsLocked: Bool { selected.isPremium && !isPremium }

    /// Описание уровня и тумблер обводки прячутся, если с ними экран
    /// прокручивался бы, и возвращаются, когда для них снова есть место.
    /// Первым уходит описание. Решение — по высоте со всем показанным, одной и
    /// той же в обе стороны, поэтому туда-обратно не дёргается.
    private func fitOptionalRows() {
        guard viewportHeight > 0, contentHeight > 0 else { return }
        let full = contentHeight
            + (showsBlurb ? 0 : blurbSlot)
            + (showsMarkWater ? 0 : markWaterSlot)
        let fits = Self.optionalRows(full: full, blurbSlot: blurbSlot, viewport: viewportHeight)
        if fits.blurb != showsBlurb { showsBlurb = fits.blurb }
        if fits.markWater != showsMarkWater { showsMarkWater = fits.markWater }
    }

    /// Что из необязательного помещается. `full` — высота содержимого со
    /// всем показанным.
    static func optionalRows(full: CGFloat, blurbSlot: CGFloat,
                             viewport: CGFloat) -> (blurb: Bool, markWater: Bool) {
        (blurb: full <= viewport, markWater: full - blurbSlot <= viewport)
    }

    @ViewBuilder
    private var capsuleList: some View {
        LevelCapsuleList(selected: selected, isPremium: isPremium, onPick: pick)
        if showsBlurb {
            LevelBlurb(selected: selected)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                    blurbSlot = $0 + LevelMetrics.listGap
                }
        }
    }

    private var matchSection: some View {
        LevelMatchSection(level: selected, options: options,
                          showsMarkWater: showsMarkWater,
                          onMarkWaterHeight: { markWaterSlot = $0 + 8 })
    }

    /// Закрытый «Эксперт» тоже выбирается — ради описания; начать на нём без
    /// Pro не даёт кнопка внизу.
    private func pick(_ choice: LevelChoice) {
        onSelect(choice.level)
    }

    private var overline: some View {
        Text("Opponent level")
            .font(.scalable(size: LevelMetrics.overlineSize, weight: .bold))
            .tracking(LevelMetrics.overlineTracking)
            .textCase(.uppercase)
            .foregroundStyle(Color.inkSecondary)
            .padding(.leading, LevelMetrics.overlineInset)
    }
}

// MARK: - Описание выбранного уровня

/// Как играет выбранный уровень — под капсулами. Место всегда по самому
/// длинному из четырёх описаний (на этой ширине и этом кегле): иначе при смене
/// уровня всё ниже прыгало бы (заказчик 13.10).
private struct LevelBlurb: View {
    let selected: AppState.DifficultyLevel

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(AppState.DifficultyLevel.allCases, id: \.self) { level in
                text(level)
                    .hidden()
                    .accessibilityHidden(true)
            }
            text(selected)
                .accessibilityIdentifier("levelBlurb")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, LevelMetrics.overlineInset)
    }

    private func text(_ level: AppState.DifficultyLevel) -> some View {
        Text(level.blurb)
            .font(.scalable(size: 13))
            .foregroundStyle(Color.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Капсулы (iPhone)

/// Отметка справа: замок у закрытого, галочка у выбранного, иначе пусто той
/// же ширины.
private struct LevelMark: View {
    let isSelected: Bool
    let isLocked: Bool

    var body: some View {
        Group {
            // Замок важнее галочки: закрытый «Эксперт» выбирают, чтобы
            // прочесть описание, а не чтобы на нём играть.
            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.scalable(size: symbolFontSize(inBox: 16)))
                    .foregroundStyle(Color.inkPrimary)
                    .opacity(ControlMetrics.ModeRow.lockOpacity)
            } else if isSelected {
                Image(systemName: "checkmark")
                    .font(.scalable(size: symbolFontSize(inBox: 18), weight: .semibold))
                    .foregroundStyle(Color.roleYou)
            } else {
                Color.clear
            }
        }
        .frame(width: 22)
    }
}

extension AppState.DifficultyLevel {
    /// Характеристика в два-три слова вместо описания поведения.
    var trait: LocalizedStringKey {
        switch self {
        case .easy: "A calm game"
        case .medium: "Plays it clean"
        case .hard: "Shoots methodically"
        case .expert: "Sees through hiding"
        }
    }
}

/// Капсула уровня высотой со строку меню: значок, название, характеристика.
private struct LevelCapsuleRow: View {
    let choice: LevelChoice
    let isSelected: Bool
    let isLocked: Bool
    let action: () -> Void

    @Environment(\.shapeFamily) private var shapeFamily

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ScaledSymbol(name: choice.icon, box: 26, variableValue: choice.iconValue)
                    .foregroundStyle(Color.inkPrimary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(choice.title)
                        .font(ControlMetrics.ChoiceRow.title)
                        .foregroundStyle(Color.inkPrimary)
                    Text(choice.level.trait)
                        .font(.scalable(size: 12))
                        .foregroundStyle(Color.inkSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                LevelMark(isSelected: isSelected, isLocked: isLocked)
            }
            .padding(.leading, 18)
            .padding(.trailing, 16)
            .frame(minHeight: ControlMetrics.ChoiceRow.minHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassPanel(.g2, radius: shapeFamily.radius(.control, legacy: ControlMetrics.ChoiceRow.radius),
                    highlight: isSelected ? .selected : .none)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct LevelCapsuleList: View {
    let selected: AppState.DifficultyLevel
    let isPremium: Bool
    let onPick: (LevelChoice) -> Void

    var body: some View {
        VStack(spacing: 8) {
            ForEach(LevelChoice.all) { choice in
                let locked = choice.isLocked(isPremium: isPremium)
                LevelCapsuleRow(choice: choice,
                                isSelected: choice.level == selected,
                                isLocked: locked) { onPick(choice) }
            }
        }
    }
}

/// Ставка, настройка партии и звук — под списком уровней (решение заказчика
/// 06.10, вместо убранного «Подтверждать выстрел»). Флаги — те же, что в
/// «Настройках», а не копии: переключённое здесь видно и там.
struct LevelMatchOptions {
    var balance: Int = 0
    var markWater: Binding<Bool> = .constant(true)
    var soundOn: Binding<Bool> = .constant(true)
    var musicOn: Binding<Bool> = .constant(false)
    var hapticsOn: Binding<Bool> = .constant(true)
    /// Кружка вибрации нет там, где её нет и в настройках: iPad, симулятор
    /// (`HapticService.isSupported`).
    var offersHaptics = true
    /// Только iPad (`PadLevelScreen`): настройки из «Настроек», нужные перед
    /// партией, и статистика выбранного уровня.
    var expertRemembers: Binding<Bool> = .constant(false)
    var askLevel: Binding<Bool> = .constant(true)
    var ownBoardOnRight: Binding<Bool> = .constant(false)
    var record: (AppState.DifficultyLevel) -> StatRecord = { _ in StatRecord(wins: 0, losses: 0) }
}

private struct LevelMatchSection: View {
    let level: AppState.DifficultyLevel
    let options: LevelMatchOptions
    /// Тумблер обводки не помещается (маленький экран, крупный шрифт) — им
    /// жертвуем первым: он есть и в «Настройках» (выбор заказчика 06.10).
    let showsMarkWater: Bool
    var onMarkWaterHeight: (CGFloat) -> Void = { _ in }

    @Environment(\.shapeFamily) private var shapeFamily

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Match")
                .font(.scalable(size: LevelMetrics.overlineSize, weight: .bold))
                .tracking(LevelMetrics.overlineTracking)
                .textCase(.uppercase)
                .foregroundStyle(Color.inkSecondary)
                .padding(.leading, LevelMetrics.overlineInset)
                .padding(.top, LevelMetrics.matchTop)
            LevelStakeCard(level: level, balance: options.balance)
            if showsMarkWater {
                markWater
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { onMarkWaterHeight($0) }
            }
            LevelSoundRow(soundOn: options.soundOn, musicOn: options.musicOn,
                          hapticsOn: options.hapticsOn, offersHaptics: options.offersHaptics)
                .padding(.top, 4)
        }
    }

    private var markWater: some View {
        Toggle(isOn: options.markWater) {
            Text("Mark the water around sunk ships")
                .font(.scalable(size: 14.5, weight: .medium))
                .foregroundStyle(Color.inkPrimary)
        }
        .seaToggleStyle()
        .padding(.leading, 18)
        .padding(.trailing, 12)
        .frame(minHeight: Geometry.Bottom.controlHeight)
        .glassPanel(.g2, radius: shapeFamily.radius(.control, legacy: 18))
        .accessibilityIdentifier("levelAutoReveal")
    }
}

/// Что стоит выбранный уровень: сколько даёт победа, сколько стоит подсказка
/// (это одно число — ставка уровня) и сколько баллов у игрока сейчас.
private struct LevelStakeCard: View {
    let level: AppState.DifficultyLevel
    let balance: Int

    @Environment(\.shapeFamily) private var shapeFamily
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// На AX1–AX5 три колонки не помещаются — столбец строк «число — подпись».
    private var stacked: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        let layout = stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(spacing: 0))
        layout {
            cell(value: "+\(level.pointsValue)", caption: "per win", warm: true)
            divider
            cell(value: "\(level.pointsValue)", caption: "per hint", warm: false)
            divider
            cell(value: "\(balance)", caption: "you have", warm: false)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, stacked ? 18 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(.g2, radius: shapeFamily.radius(.card, legacy: LevelMetrics.noteRadius))
        .accessibilityIdentifier("levelStake")
    }

    @ViewBuilder
    private var divider: some View {
        if !stacked {
            Rectangle()
                .fill(Color.glassStroke)
                .frame(width: 1, height: 30)
                .accessibilityHidden(true)
        }
    }

    private func cell(value: String, caption: LocalizedStringKey, warm: Bool) -> some View {
        let layout = stacked
            ? AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 10))
            : AnyLayout(VStackLayout(spacing: 2))
        return layout {
            HStack(spacing: 4) {
                Image(systemName: PointsSymbol.name)
                    .font(.scalable(size: 13, weight: .semibold))
                    .accessibilityHidden(true)
                Text(verbatim: value)
                    .font(.scalable(size: 19, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .foregroundStyle(warm ? Color.roleYou : Color.inkPrimary)
            Text(caption)
                .font(.scalable(size: 11.5))
                .foregroundStyle(Color.inkSecondary)
                .lineLimit(stacked ? nil : 1)
                .minimumScaleFactor(0.8)
        }
        // Колонка — по центру своей трети; столбец на AX — по левому краю.
        .frame(maxWidth: stacked ? nil : .infinity, alignment: stacked ? .leading : .center)
        .accessibilityElement(children: .combine)
    }
}

/// Звук, музыка и вибрация кружками: латунный — включено, стеклянный с
/// перечёркнутым значком — выключено. Перехода в настройки рядом нет — он
/// в меню (решение заказчика 06.10).
struct LevelSoundRow: View {
    @Binding var soundOn: Bool
    @Binding var musicOn: Bool
    @Binding var hapticsOn: Bool
    let offersHaptics: Bool

    var body: some View {
        HStack(spacing: 10) {
            Toggle(isOn: $soundOn) { Text("Sound") }
                .toggleStyle(SoundChipStyle(title: "Sound", on: "speaker.wave.2.fill", off: "speaker.slash.fill"))
                .accessibilityIdentifier("levelSound")
            Toggle(isOn: $musicOn) { Text("Music") }
                .toggleStyle(SoundChipStyle(title: "Music", on: "music.note", off: "music.note", strikesOff: true))
                .accessibilityIdentifier("levelMusic")
            if offersHaptics {
                Toggle(isOn: $hapticsOn) { Text("Vibration") }
                    .toggleStyle(SoundChipStyle(title: "Vibration", on: "iphone.radiowaves.left.and.right",
                                                off: "iphone.slash"))
                    .accessibilityIdentifier("levelHaptics")
            }
            Spacer(minLength: 0)
        }
        .onChange(of: hapticsOn) { _, isOn in
            // Как в настройках: включили — сразу дать почувствовать.
            if isOn { HapticService.shared.play(.ownHit) }
        }
    }
}

/// Круглый выключатель 44 pt. Надпись — только для VoiceOver: значок и цвет
/// говорят сами, а три подписи в ряд на 375 pt не помещаются по-нидерландски.
private struct SoundChipStyle: ToggleStyle {
    let title: LocalizedStringKey
    let on: String
    let off: String
    /// У значка нет перечёркнутой версии — черта рисуется поверх.
    var strikesOff = false

    func makeBody(configuration: Configuration) -> some View {
        let isOn = configuration.isOn
        return Button { configuration.isOn.toggle() } label: {
            ZStack {
                Circle().fill(isOn ? Color.roleYou : Color.clear)
                // Значок в рамке контрола не растёт (правило R4.5d) — вместо
                // этого крупный просмотр по долгому нажатию.
                Image(systemName: isOn ? on : off)
                    .font(.system(size: symbolFontSize(inBox: 18), weight: .semibold))
                    .foregroundStyle(isOn ? Color.inkOnBrass : Color.inkSecondary)
                if !isOn && strikesOff {
                    Capsule()
                        .fill(Color.inkSecondary)
                        .frame(width: 22, height: 1.5)
                        .rotationEffect(.degrees(-45))
                }
            }
            .frame(width: 44, height: 44)
            .glassPanel(.g2, radius: 22)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(isOn ? "On" : "Off"))
        .accessibilityAddTraits(.isToggle)
        .accessibilityShowsLargeContentViewer {
            Label { Text(title) } icon: { Image(systemName: isOn ? on : off) }
        }
    }
}

// MARK: - Капсула уровня в бою

/// Спека 4.5. Стоит справа от подписи «Поле противника» в уже существующей
/// строке и **не выше её**, поэтому раскладка боя от капсулы не меняется.
/// Капсула холодная — это свойство соперника, а не игрока. Не нажимается:
/// уровень посреди партии не меняется.
struct LevelChip: View {
    let level: AppState.DifficultyLevel
    var size: Geometry.SizeClass = .regular

    private var metrics: Metrics { size.isCompact ? .compact : .regular }
    @Environment(\.shapeFamily) private var shapeFamily

    struct Metrics {
        let height: CGFloat
        let verticalPadding: CGFloat
        let horizontalPadding: CGFloat
        let iconSize: CGFloat
        let titleSize: CGFloat
        let spacing: CGFloat

        /// Радиус — половина высоты: капсула, а не плашка.
        var radius: CGFloat { height / 2 }

        static let regular = Metrics(height: 22, verticalPadding: 7, horizontalPadding: 9,
                                     iconSize: 13, titleSize: 11.5, spacing: 5)
        static let compact = Metrics(height: 20, verticalPadding: 6, horizontalPadding: 8,
                                     iconSize: 12, titleSize: 11, spacing: 4)
    }

    /// Зазор между подписью поля и капсулой (спека 4.5).
    static func gap(_ size: Geometry.SizeClass) -> CGFloat { size.isCompact ? 7 : 8 }

    var body: some View {
        HStack(spacing: metrics.spacing) {
            Image(systemName: LevelChoice.icon, variableValue: LevelChoice.iconValue(for: level))
                .font(.system(size: metrics.iconSize))
            Text(LevelChoice.title(for: level))
                .font(.system(size: metrics.titleSize, weight: .semibold))
        }
        .foregroundStyle(Color.inkPrimary)
        .lineLimit(1)
        .fixedSize()
        // Высоту задаёт рамка, а не вертикальные поля: 22 − 2 × 7 оставляли
        // тексту 8 pt, и в тесном месте (центр панели счёта на iPad) название
        // обрезалось до «Med…». Поля 7 / 9 из спеки — это высота строки
        // вокруг текста, при высоте 22 они получаются сами.
        .padding(.horizontal, metrics.horizontalPadding)
        .frame(height: metrics.height)
        .background {
            let chip = RoundedRectangle(cornerRadius: shapeFamily.radius(.chip, legacy: metrics.radius),
                                        style: .continuous)
            chip
                .fill(Color.boardFillFoe)
                .overlay { chip.strokeBorder(Color.boardStrokeFoe, lineWidth: 1) }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Превью

private struct LevelScreenDemo: View {
    @State private var selected: AppState.DifficultyLevel
    let isPremium: Bool
    @State private var markWater = true
    @State private var soundOn = true
    @State private var musicOn = false
    @State private var hapticsOn = true

    init(selected: AppState.DifficultyLevel = .hard, isPremium: Bool = false) {
        _selected = State(initialValue: selected)
        self.isPremium = isPremium
    }

    var body: some View {
        ZStack {
            SeaBackground()
            LevelScreen(selected: selected, isPremium: isPremium,
                        onSelect: { selected = $0 },
                        options: LevelMatchOptions(balance: 42, markWater: $markWater,
                                                   soundOn: $soundOn, musicOn: $musicOn,
                                                   hapticsOn: $hapticsOn, offersHaptics: true))
        }
    }
}

#Preview("Уровень · тёмная") {
    LevelScreenDemo()
        .preferredColorScheme(.dark)
}

#Preview("Уровень · светлая") {
    LevelScreenDemo()
        .preferredColorScheme(.light)
}

#Preview("Уровень · с Pro, выбран Эксперт") {
    LevelScreenDemo(selected: .expert, isPremium: true)
        .preferredColorScheme(.dark)
}

#Preview("Уровень · 375 × 667", traits: .fixedLayout(width: 375, height: 667)) {
    LevelScreenDemo()
        .preferredColorScheme(.dark)
}

#Preview("Уровень · 375 × 812, без Pro, выбран Эксперт",
         traits: .fixedLayout(width: 375, height: 812)) {
    LevelScreenDemo(selected: .expert)
        .preferredColorScheme(.dark)
}


/// Капсула в той строке, в которой она стоит в бою: подпись поля плюс капсула,
/// пара по центру. Так видно главное — что капсула не выше подписи и ничего не
/// сдвигает.
private struct LevelChipDemo: View {
    var body: some View {
        ZStack {
            SeaBackground()

            VStack(spacing: 28) {
                ForEach([Geometry.SizeClass.regular, .compact], id: \.photo) { size in
                    VStack(spacing: 10) {
                        ForEach(AppState.DifficultyLevel.allCases, id: \.self) { level in
                            HStack(spacing: LevelChip.gap(size)) {
                                Text("Enemy field")
                                    .font(TypeScale.headline)
                                    .foregroundStyle(Color.inkPrimary)
                                LevelChip(level: level, size: size)
                            }
                        }
                    }
                    .padding(14)
                    .glassPanel(.g2)
                }
            }
            .padding(Geometry.Inset.phoneSide)
        }
    }
}

#Preview("Капсула уровня · тёмная") {
    LevelChipDemo()
        .preferredColorScheme(.dark)
}

#Preview("Капсула уровня · светлая") {
    LevelChipDemo()
        .preferredColorScheme(.light)
}
