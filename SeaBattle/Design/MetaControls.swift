//
//  MetaControls.swift
//  Sea Battle — контролы мета-экранов
//
//  Полоса сводки, строка достижения, карточка игрока с окошками значка и цвета,
//  выбор языка. Живут на статистике, в достижениях, при первом запуске и в игре
//  вдвоём — то есть вне боя, поэтому вынесены из `Controls.swift`.
//

import SwiftUI

// MARK: - Палитра игрока

/// Значок и цвет аватара — это **содержимое**, которое выбирает игрок, а не
/// хром интерфейса, поэтому списки живут здесь, а не в ассет-каталоге: они
/// одинаковы в обеих темах и подписаны в макете как данные (10 значков и
/// 16 цветов, блок 4c). Первый в макете — `anchor`, такого символа в SF
/// Symbols нет (пустой кружок), заменён штурвалом `helm` (вопрос В30).
enum PlayerAvatar {
    static let glyphs = ["helm", "sailboat.fill", "ferry.fill", "water.waves",
                         "fish.fill", "shield.fill", "bolt.fill", "star.fill",
                         "crown.fill", "flag.fill"]

    /// Порядок как в макете: тёплые, красные, фиолетово-синие, зелёные,
    /// нейтральные. Первый — латунь, он же по умолчанию.
    static let colors: [Color] = [
        Color(hex: 0xD19A3C), Color(hex: 0xE2BD6F), Color(hex: 0xA8752E), Color(hex: 0xC1554E),
        Color(hex: 0xE08A6A), Color(hex: 0xB0603F), Color(hex: 0x8F6FBD), Color(hex: 0x6F80C4),
        Color(hex: 0x3C7FBF), Color(hex: 0x4AA6C9), Color(hex: 0x4FB3A0), Color(hex: 0x5AA87F),
        Color(hex: 0x8AB04A), Color(hex: 0xC98FB0), Color(hex: 0xD9D2C4), Color(hex: 0x7B8794),
    ]

    static let buttonSide: CGFloat = 46

    static func color(_ index: Int) -> Color {
        colors.indices.contains(index) ? colors[index] : .roleYou
    }
}

// MARK: - Аватар

/// Круг аватара (`avatarDot` в макетах): кольцо 2 pt в цвете игрока, внутри
/// мягкая заливка тем же цветом сверху и значок. Цвет игрока — содержимое, а
/// не токен (см. `PlayerAvatar`), поэтому доля заливки задаётся здесь:
/// правило 8 про альфу в ассете касается токенов хрома.
struct AvatarDot: View {
    let glyph: String
    let colorIndex: Int
    var size: CGFloat = 40

    /// Заливка `#…44` макета — 27 %; значок — 45 % стороны круга.
    static let fillShare: Double = 0x44 / 255
    static let glyphShare: CGFloat = 0.45

    var body: some View {
        let color = PlayerAvatar.color(colorIndex)
        Image(systemName: glyph)
            .font(.system(size: symbolFontSize(inBox: size * Self.glyphShare), weight: .semibold))
            .foregroundStyle(Color.inkPrimary)
            .frame(width: size, height: size)
            .background {
                Circle().fill(RadialGradient(colors: [color.opacity(Self.fillShare), .clear],
                                             center: UnitPoint(x: 0.5, y: 0.25),
                                             startRadius: 0, endRadius: size * 0.7))
            }
            .overlay { Circle().strokeBorder(color, lineWidth: 2) }
            .accessibilityHidden(true)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

// MARK: - Полоса сводки

/// Партии, победы и доля побед в строку, под ними полоса в цветах роли:
/// тёплое — ваши победы, холодное — поражения. Других диаграмм в игре нет,
/// поэтому эта одна должна читаться без легенды.
struct StatBar: View {
    let wins: Int
    let losses: Int

    var total: Int { wins + losses }
    /// Доля побед. У пустой истории полоса не рисуется вовсе — ноль из нуля
    /// это не «половина», а «ещё не играли».
    var winShare: Double { total == 0 ? 0 : Double(wins) / Double(total) }

    var body: some View {
        VStack(alignment: .leading, spacing: StatBarMetrics.gap) {
            HStack(alignment: .top, spacing: StatBarMetrics.columnGap) {
                figure("games", "\(total)")
                figure("wins", "\(wins)")
                figure("win rate", total == 0 ? "—" : Self.percent(winShare))
            }
            bar
            HStack {
                Text("^[\(wins) win](inflect: true)")
                Spacer()
                Text("^[\(losses) loss](inflect: true)")
            }
            .font(.system(size: StatBarMetrics.legend))
            .monospacedDigit()
            .foregroundStyle(Color.inkSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    /// «58 %» по правилам языка: где ставится пробел перед знаком, решает
    /// формат, а не строка.
    static func percent(_ share: Double) -> String {
        share.formatted(.percent.precision(.fractionLength(0)))
    }

    /// Значение над подписью, три колонки поровну (`metric10` в макете).
    private func figure(_ caption: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(verbatim: value)
                .font(.system(size: StatBarMetrics.value, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.inkPrimary)
            Text(caption)
                .font(.system(size: StatBarMetrics.caption))
                .foregroundStyle(Color.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bar: some View {
        GeometryReader { proxy in
            HStack(spacing: StatBarMetrics.barGap) {
                if total == 0 {
                    Capsule().fill(Color.inkTertiary.opacity(0.35))
                } else {
                    // Без поражений и без побед полоса одна, зазора нет.
                    let gap = wins > 0 && losses > 0 ? StatBarMetrics.barGap : 0
                    if wins > 0 {
                        UnevenRoundedRectangle(cornerRadii: corners(leading: true, alone: losses == 0))
                            .fill(Color.roleYou)
                            .shadow(color: .roleYouSoft, radius: StatBarMetrics.glow)
                            .frame(width: max(0, (proxy.size.width - gap) * winShare))
                    }
                    if losses > 0 {
                        UnevenRoundedRectangle(cornerRadii: corners(leading: false, alone: wins == 0))
                            .fill(Color.roleFoe)
                    }
                }
            }
        }
        .frame(height: StatBarMetrics.barHeight)
    }

    /// Снаружи полоса круглая, на стыке двух цветов — почти прямая (4 pt).
    private func corners(leading: Bool, alone: Bool) -> RectangleCornerRadii {
        let round = StatBarMetrics.barHeight / 2
        let joint = alone ? round : StatBarMetrics.jointRadius
        return leading
            ? RectangleCornerRadii(topLeading: round, bottomLeading: round, bottomTrailing: joint, topTrailing: joint)
            : RectangleCornerRadii(topLeading: joint, bottomLeading: joint, bottomTrailing: round, topTrailing: round)
    }
}

/// Числа полосы сводки из кадра `screen10Stats`.
enum StatBarMetrics {
    static let gap: CGFloat = 8
    static let columnGap: CGFloat = 12
    static let value: CGFloat = 19
    static let caption: CGFloat = 11.5
    static let legend: CGFloat = 11.5
    static let barHeight: CGFloat = 10
    static let barGap: CGFloat = 3
    static let jointRadius: CGFloat = 4
    /// CSS 0 0 14.
    static let glow: CGFloat = 7
}

// MARK: - Строка достижения

/// Полученное достижение и недостигнутое — одна строка в двух состояниях.
/// Полученное показывает начисление латунной капсулой, недостигнутое — полосу
/// прогресса: игрок должен видеть, сколько осталось, а не только что не успел.
struct AchievementRow: View {
    enum State: Equatable {
        case earned(points: Int)
        case inProgress(current: Int, total: Int)
    }

    let icon: String
    let title: String
    let subtitle: String
    let state: State

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(isEarned ? Color.roleYou : Color.inkTertiary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(TypeScale.headline)
                    .foregroundStyle(Color.inkPrimary)
                Text(subtitle)
                    .font(TypeScale.footnote)
                    .foregroundStyle(Color.inkSecondary)
                    .lineLimit(1)
                if case let .inProgress(current, total) = state {
                    progress(current: current, total: total)
                }
            }

            Spacer(minLength: 8)

            switch state {
            case let .earned(points):
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                    Text("+\(points)")
                        .font(TypeScale.tally)
                }
                .foregroundStyle(Color.inkOnBrass)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.roleYou))
            case let .inProgress(current, total):
                Text("\(current) / \(total)")
                    .font(TypeScale.tally)
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassPanel(.g2, radius: Geometry.Radius.button)
    }

    private var isEarned: Bool { if case .earned = state { true } else { false } }

    private func progress(current: Int, total: Int) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.inkTertiary.opacity(0.3))
                Capsule().fill(Color.roleYou)
                    .frame(width: proxy.size.width * min(1, Double(current) / Double(max(1, total))))
            }
        }
        .frame(height: 4)
        .padding(.top, 2)
    }
}

// MARK: - Карточка игрока

struct RecentPlayer: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let glyph: String
    let colorIndex: Int
}

/// Поле имени и две кнопки 46 × 46: значок и цвет. Ряда сватчей в самой
/// карточке нет намеренно — пестрило; каждая кнопка открывает своё окошко.
struct PlayerCard: View {
    @Binding var name: String
    @Binding var glyph: String
    @Binding var colorIndex: Int
    var recent: [RecentPlayer] = []
    /// Подсказка в пустом поле имени: в игре вдвоём — «Игрок 1» / «Игрок 2»,
    /// под этим именем игрок и пойдёт в партию, если ничего не наберёт.
    var placeholder: LocalizedStringKey = "Name"
    var onPickRecent: ((RecentPlayer) -> Void)?

    @State private var showsGlyphs = false
    @State private var showsColors = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                TextField(placeholder, text: $name)
                    .font(TypeScale.body)
                    .foregroundStyle(Color.inkPrimary)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .frame(height: PlayerAvatar.buttonSide)
                    .glassPanel(.g2, radius: Geometry.Radius.segment)

                avatarButton(isOpen: showsGlyphs) { showsGlyphs = true } label: {
                    AvatarDot(glyph: glyph, colorIndex: colorIndex, size: 32)
                }
                .accessibilityLabel(Text("Icon"))
                .popover(isPresented: $showsGlyphs, arrowEdge: .top) {
                    glyphPicker
                }

                avatarButton(isOpen: showsColors) { showsColors = true } label: {
                    Circle()
                        .fill(PlayerAvatar.color(colorIndex))
                        .frame(width: 24, height: 24)
                }
                .accessibilityLabel(Text("Colour"))
                .popover(isPresented: $showsColors, arrowEdge: .top) {
                    colorPicker
                }
            }

            if !recent.isEmpty {
                Text("Played before")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.inkSecondary)
                HStack(spacing: 8) {
                    ForEach(recent) { player in
                        recentChip(player)
                    }
                }
            }
        }
    }

    /// Кнопка с открытым окошком обведена цветом игрока (кадр `screen4TwoSetup`).
    private func avatarButton<Label: View>(isOpen: Bool,
                                           _ action: @escaping () -> Void,
                                           @ViewBuilder label: () -> Label) -> some View {
        Button(action: action) {
            label()
                .frame(width: PlayerAvatar.buttonSide, height: PlayerAvatar.buttonSide)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassPanel(.g2, radius: Geometry.Radius.segment)
        .overlay {
            if isOpen {
                RoundedRectangle(cornerRadius: Geometry.Radius.segment, style: .continuous)
                    .strokeBorder(PlayerAvatar.color(colorIndex), lineWidth: 1)
            }
        }
    }

    /// Окошки — уровень G3: они лежат над карточкой, а карточка сама на стекле.
    private var glyphPicker: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(44), spacing: 6), count: 5),
                  spacing: 6) {
            ForEach(PlayerAvatar.glyphs, id: \.self) { symbol in
                Image(systemName: symbol)
                    .font(.system(size: 20))
                    .foregroundStyle(symbol == glyph ? Color.inkOnBrass : Color.inkPrimary)
                    .frame(width: 44, height: 44)
                    .background {
                        if symbol == glyph {
                            RoundedRectangle(cornerRadius: Geometry.Radius.chip, style: .continuous)
                                .fill(Color.roleYou)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { glyph = symbol; showsGlyphs = false }
            }
        }
        .padding(12)
        .presentationCompactAdaptation(.popover)
    }

    private var colorPicker: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(36), spacing: 6), count: 8),
                  spacing: 6) {
            ForEach(PlayerAvatar.colors.indices, id: \.self) { index in
                Circle()
                    .fill(PlayerAvatar.colors[index])
                    .frame(width: 30, height: 30)
                    .overlay {
                        if index == colorIndex {
                            Circle().strokeBorder(Color.inkPrimary, lineWidth: 2)
                                .padding(-3)
                        }
                    }
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
                    .onTapGesture { colorIndex = index; showsColors = false }
            }
        }
        .padding(12)
        .presentationCompactAdaptation(.popover)
    }

    /// Нажатие на чип подставляет игрока **целиком** — имя, значок и цвет:
    /// это возврат к прежнему игроку, а не выбор одного поля.
    private func recentChip(_ player: RecentPlayer) -> some View {
        Button {
            name = player.name
            glyph = player.glyph
            colorIndex = player.colorIndex
            onPickRecent?(player)
        } label: {
            HStack(spacing: 6) {
                AvatarDot(glyph: player.glyph, colorIndex: player.colorIndex, size: 22)
                Text(player.name)
                    .font(TypeScale.footnote)
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)
            }
            // Кадр `prevChip`: аватар 22 почти у кромки, текст с полем 10.
            .padding(.leading, 3)
            .padding(.trailing, 10)
            .padding(.vertical, 3)
            .frame(minHeight: 28)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassPanel(.g2, radius: 14)
    }
}

// MARK: - Выбор языка

/// Выпадающий список прямо из своей строки. В пунктах указаны буквы поля:
/// от языка зависит не только текст, но и разметка координат, и игрок должен
/// увидеть это до переключения, а не после.
struct LanguageMenu: View {
    struct Language: Identifiable, Equatable {
        let id: String
        let title: String
        var alphabet: BoardAlphabet { BoardAlphabet.forLanguage(id) }
        var letters: String { alphabet == .cyrillic ? "А–К" : "A–J" }
    }

    static let languages = [Language(id: "ru", title: "Русский"),
                            Language(id: "en", title: "English"),
                            Language(id: "nl", title: "Nederlands")]

    @Binding var selection: String

    var body: some View {
        Menu {
            ForEach(Self.languages) { language in
                Button {
                    selection = language.id
                } label: {
                    Text("\(language.title) · \(language.letters)")
                    if language.id == selection { Image(systemName: "checkmark") }
                }
            }
        } label: {
            HStack {
                Text("Язык")
                    .font(TypeScale.body)
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                Text(current.title)
                    .font(TypeScale.body)
                    .foregroundStyle(Color.inkSecondary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.inkTertiary)
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .contentShape(Rectangle())
        }
        .glassPanel(.g2, radius: Geometry.Radius.button)
    }

    private var current: Language {
        Self.languages.first { $0.id == selection } ?? Self.languages[0]
    }
}

// MARK: - Превью

private struct MetaControlsDemo: View {
    @State private var name = "Аня"
    @State private var glyph = "sailboat.fill"
    @State private var colorIndex = 0
    @State private var language = "ru"

    var body: some View {
        ZStack {
            SeaBackground()

            ScrollView {
                VStack(spacing: 14) {
                    StatBar(wins: 37, losses: 21)
                        .padding(14)
                        .glassPanel(.g2)

                    AchievementRow(icon: "flame.fill", title: "Первая кровь",
                                   subtitle: "Победить, не потеряв ни одного корабля",
                                   state: .earned(points: 40))
                    AchievementRow(icon: "scope", title: "Снайпер",
                                   subtitle: "Потопить флот за 40 выстрелов",
                                   state: .inProgress(current: 3, total: 10))

                    PlayerCard(name: $name, glyph: $glyph, colorIndex: $colorIndex,
                               recent: [RecentPlayer(name: "Дед", glyph: "shield.fill", colorIndex: 2),
                                        RecentPlayer(name: "Семён", glyph: "bolt.fill", colorIndex: 12),
                                        RecentPlayer(name: "Игрок 2", glyph: "ferry.fill", colorIndex: 15)])
                        .padding(14)
                        .glassPanel(.g2)

                    LanguageMenu(selection: $language)
                }
                .padding(Geometry.Inset.phoneSide)
                .padding(.top, 60)
            }
        }
    }
}

#Preview("Мета-контролы · тёмная") {
    MetaControlsDemo()
        .preferredColorScheme(.dark)
}

#Preview("Мета-контролы · светлая") {
    MetaControlsDemo()
        .preferredColorScheme(.light)
}
