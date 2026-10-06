//
//  LevelScreen.swift
//  Sea Battle — уровень компьютера (R2.1a, шаг 5a порядка сборки)
//
//  Спека 4.3. Шаг между меню и расстановкой: четыре уровня, «Эксперт» под
//  замком, главная кнопка «Начать партию». iPhone (06.10) — капсулы с
//  характеристикой и настройки партии под ними; iPad — строки с описанием и
//  пояснение про сокрытие флота.
//
//  Капсула уровня в бою (`LevelChip`, спека 4.5) лежит здесь же, а не в
//  дизайн-системе: значок и название уровня у списка и у капсулы одни и те же,
//  и держать их в двух файлах — значит однажды показать в бою «бинокль» там,
//  где в списке стоял «прицел».
//

import SwiftUI

// MARK: - Уровень как строка списка

/// Уровень глазами игрока: значок, название и одна строка про поведение ИИ.
/// Уровень описан **поведением**, а не шкалой «легко–сложно» — так игрок видит,
/// чем четвёртый отличается от третьего (лог дизайна, тур 5).
struct LevelChoice: Identifiable {
    let level: AppState.DifficultyLevel
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var id: AppState.DifficultyLevel { level }

    /// Замок — только у «Эксперта» и только без Pro. Строка при этом выглядит
    /// как остальные: закрытый уровень остаётся приглашением, а не запретом.
    func isLocked(isPremium: Bool) -> Bool { level.isPremium && !isPremium }

    /// Порядок как в модели: от слабого к сильному.
    static var all: [LevelChoice] {
        AppState.DifficultyLevel.allCases.map { level in
            switch level {
            case .easy:
                LevelChoice(level: level, icon: "sailboat",
                            title: "Easy",
                            subtitle: "Finishes off a ship it has found, but keeps shooting at the water around a sunk one")
            case .medium:
                LevelChoice(level: level, icon: "safari",
                            title: "Medium",
                            subtitle: "Finishes off a ship it has found and never wastes shots on the water around it")
            case .hard:
                LevelChoice(level: level, icon: "binoculars",
                            title: "Hard",
                            subtitle: "Shoots every other cell and arranges its own fleet so it takes longer to find")
            case .expert:
                LevelChoice(level: level, icon: "scope",
                            title: "Expert",
                            subtitle: "Works out where the ships most likely are, and hides its own fleet even better")
            }
        }
    }

    static func icon(for level: AppState.DifficultyLevel) -> String {
        all.first { $0.level == level }?.icon ?? "target"
    }

    static func title(for level: AppState.DifficultyLevel) -> LocalizedStringKey {
        all.first { $0.level == level }?.title ?? ""
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
    /// Пояснение под списком.
    static let noteRadius: CGFloat = 16
    static let noteVerticalPadding: CGFloat = 12
    static let noteHorizontalPadding: CGFloat = 13
    static let noteSize: CGFloat = 12
    static let sideInset = Geometry.Nav.titleInset - Geometry.Nav.stackInset  // 8
}

// MARK: - Раскладка списка

/// Как экран показывает четыре уровня.
enum LevelLayout: Sendable {
    /// Строки выбора с описанием поведения и пояснение плашкой — iPad.
    case rows
    /// iPhone (выбор заказчика 06.10): капсулы с названием и характеристикой
    /// в два-три слова, под ними — настройки партии капсулами-тумблерами.
    /// Строки с описанием в капсулах выходили толстыми, а пояснение
    /// плашкой — «ни к селу».
    case capsules
}

// MARK: - Экран

struct LevelScreen: View {
    let selected: AppState.DifficultyLevel
    let isPremium: Bool
    var onSelect: (AppState.DifficultyLevel) -> Void = { _ in }
    /// Нажатие на закрытый «Эксперт»: поднимает лист Pro, выбор не меняет.
    var onLocked: () -> Void = {}
    var onStart: () -> Void = {}
    var onBack: () -> Void = {}
    var onMenu: () -> Void = {}
    var layout: LevelLayout = .rows
    /// Ставка, обводка и звук для раскладки `capsules`.
    var options = LevelMatchOptions()

    @Environment(\.shapeFamily) private var shapeFamily
    /// Высота области прокрутки и содержимого в ней — чтобы убрать тумблер
    /// обводки, когда всё не помещается без прокрутки.
    @State private var viewportHeight: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var markWaterSlot: CGFloat = Geometry.Bottom.controlHeight + 8
    @State private var showsMarkWater = true

    var body: some View {
        VStack(spacing: 0) {
            ScreenTitle(title: "Single player", back: "Play", onBack: onBack)
                .padding(.top, NavMetrics.titleTopBelowSafeArea)

            ScrollView {
                VStack(alignment: .leading, spacing: LevelMetrics.listGap) {
                    overline
                    switch layout {
                    case .rows:
                        levels
                        note
                    case .capsules:
                        LevelCapsuleList(selected: selected, isPremium: isPremium, onPick: pick)
                        LevelMatchSection(level: selected, options: options,
                                          showsMarkWater: showsMarkWater,
                                          onMarkWaterHeight: { markWaterSlot = $0 + 8 })
                    }
                }
                .padding(.horizontal, Geometry.Nav.stackInset)
                .padding(.top, Geometry.Nav.titleGap * 2)
                .padding(.bottom, Geometry.Nav.titleGap)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
            }
            .scrollBounceBehavior(.basedOnSize)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { viewportHeight = $0 }
            .onChange(of: contentHeight) { fitMarkWater() }
            .onChange(of: viewportHeight) { fitMarkWater() }

            BottomStack(onMenu: onMenu) {
                // Форма с явной надписью, а не `Button("…", action:)`:
                // инструментирование превью на второй спотыкается внутри
                // своего `@ViewBuilder` («ambiguous use of
                // `__designTimeSelection`»), хотя сборка проходит.
                Button(action: onStart) {
                    Text("Start match")
                }
                .primaryButton()
            }
        }
    }

    /// Тумблер прячется, если с ним экран прокручивался бы, и возвращается,
    /// когда для него снова есть место. Решение по одной и той же сумме в обе
    /// стороны, поэтому туда-обратно не дёргается.
    private func fitMarkWater() {
        guard layout == .capsules, viewportHeight > 0, contentHeight > 0 else { return }
        let fits = Self.markWaterFits(isShown: showsMarkWater, content: contentHeight,
                                      slot: markWaterSlot, viewport: viewportHeight)
        if fits != showsMarkWater { showsMarkWater = fits }
    }

    /// Помещается ли содержимое вместе с тумблером. `content` — как сейчас
    /// на экране: с тумблером, если он показан, без него — если нет.
    static func markWaterFits(isShown: Bool, content: CGFloat, slot: CGFloat,
                              viewport: CGFloat) -> Bool {
        (isShown ? content : content + slot) <= viewport
    }

    private func pick(_ choice: LevelChoice) {
        if choice.isLocked(isPremium: isPremium) { onLocked() } else { onSelect(choice.level) }
    }

    private var overline: some View {
        Text("Opponent level")
            .font(.scalable(size: LevelMetrics.overlineSize, weight: .bold))
            .tracking(LevelMetrics.overlineTracking)
            .textCase(.uppercase)
            .foregroundStyle(Color.inkSecondary)
            .padding(.leading, LevelMetrics.overlineInset)
    }

    private var levels: some View {
        VStack(spacing: LevelMetrics.listGap) {
            ForEach(LevelChoice.all) { choice in
                let locked = choice.isLocked(isPremium: isPremium)
                ChoiceRow(icon: choice.icon,
                          title: choice.title,
                          subtitle: choice.subtitle,
                          isSelected: choice.level == selected && !locked,
                          isLocked: locked) {
                    if locked { onLocked() } else { onSelect(choice.level) }
                }
            }
        }
    }

    private var note: some View {
        // Пояснение говорит про сокрытие флота: это самая сильная ручка в игре
        // и единственное настоящее отличие двух верхних уровней, а в одну
        // строку подписи оно не влезает.
        Text("On Hard and Expert the computer does not just shoot better — it also hides its fleet, so finding its ships takes more shots.")
            .font(.scalable(size: LevelMetrics.noteSize))
            .foregroundStyle(Color.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, LevelMetrics.noteVerticalPadding)
            .padding(.horizontal, LevelMetrics.noteHorizontalPadding)
            .glassPanel(.g2, radius: shapeFamily.radius(.card, legacy: LevelMetrics.noteRadius))
    }
}

// MARK: - Капсулы (iPhone)

/// Отметка справа: галочка у выбранного, замок у закрытого, иначе пусто той
/// же ширины.
private struct LevelMark: View {
    let isSelected: Bool
    let isLocked: Bool

    var body: some View {
        Group {
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.scalable(size: symbolFontSize(inBox: 18), weight: .semibold))
                    .foregroundStyle(Color.roleYou)
            } else if isLocked {
                Image(systemName: "lock.fill")
                    .font(.scalable(size: symbolFontSize(inBox: 16)))
                    .foregroundStyle(Color.inkPrimary)
                    .opacity(ControlMetrics.ModeRow.lockOpacity)
            } else {
                Color.clear
            }
        }
        .frame(width: 22)
    }
}

private extension AppState.DifficultyLevel {
    /// Характеристика в два-три слова вместо описания поведения.
    var trait: LocalizedStringKey {
        switch self {
        case .easy: "A calm game"
        case .medium: "Plays it clean"
        case .hard: "Hides its fleet"
        case .expert: "Counts every shot"
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
                ScaledSymbol(name: choice.icon, box: 26)
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
                                isSelected: choice.level == selected && !locked,
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
                .padding(.top, 14)
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
        .frame(maxWidth: stacked ? nil : .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Звук, музыка и вибрация кружками: латунный — включено, стеклянный с
/// перечёркнутым значком — выключено. Перехода в настройки рядом нет — он
/// в меню (решение заказчика 06.10).
private struct LevelSoundRow: View {
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
            if isOn { HapticService.shared.play(.hit) }
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
            Image(systemName: LevelChoice.icon(for: level))
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
    let layout: LevelLayout
    @State private var markWater = true
    @State private var soundOn = true
    @State private var musicOn = false
    @State private var hapticsOn = true

    init(selected: AppState.DifficultyLevel = .hard, isPremium: Bool = false,
         layout: LevelLayout = .capsules) {
        _selected = State(initialValue: selected)
        self.isPremium = isPremium
        self.layout = layout
    }

    var body: some View {
        ZStack {
            SeaBackground()
            LevelScreen(selected: selected, isPremium: isPremium,
                        onSelect: { selected = $0 }, layout: layout,
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

#Preview("Уровень · iPad, строки") {
    LevelScreenDemo(layout: .rows)
        .phoneStyle(true)
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
