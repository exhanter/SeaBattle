//
//  LevelScreen.swift
//  Sea Battle — уровень компьютера (R2.1a, шаг 5a порядка сборки)
//
//  Спека 4.3. Шаг между меню и расстановкой: четыре строки выбора, «Эксперт»
//  под замком, пояснение про сокрытие флота, главная кнопка «Начать партию».
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

    var body: some View {
        VStack(spacing: 0) {
            ScreenTitle(title: "Single player", back: "Play", onBack: onBack)
                .padding(.top, NavMetrics.titleTopBelowSafeArea)

            ScrollView {
                VStack(alignment: .leading, spacing: LevelMetrics.listGap) {
                    overline
                    levels
                    note
                }
                .padding(.horizontal, Geometry.Nav.stackInset)
                .padding(.top, Geometry.Nav.titleGap * 2)
            }
            .scrollBounceBehavior(.basedOnSize)

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
            .glassPanel(.g2, radius: LevelMetrics.noteRadius)
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
            Capsule(style: .continuous)
                .fill(Color.boardFillFoe)
                .overlay { Capsule(style: .continuous).strokeBorder(Color.boardStrokeFoe, lineWidth: 1) }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Превью

private struct LevelScreenDemo: View {
    @State private var selected: AppState.DifficultyLevel
    let isPremium: Bool

    init(selected: AppState.DifficultyLevel = .hard, isPremium: Bool = false) {
        _selected = State(initialValue: selected)
        self.isPremium = isPremium
    }

    var body: some View {
        ZStack {
            SeaBackground()
            LevelScreen(selected: selected, isPremium: isPremium,
                        onSelect: { selected = $0 })
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
