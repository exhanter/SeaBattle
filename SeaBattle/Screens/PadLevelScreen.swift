//
//  PadLevelScreen.swift
//  Sea Battle — экран уровня на iPad (выбор заказчика 13.10)
//
//  Две колонки одной высоты. Слева четыре уровня с полным описанием — строки
//  одной высоты, по самой высокой. Справа карточка партии (что даёт уровень,
//  сколько баллов у игрока, как он играл на этом уровне) и настройки, нужные
//  перед партией: обводка, память «Эксперта», спрашивать ли уровень. Ниже
//  блоков, под правой колонкой, — сторона своего поля и звук; горизонтально
//  они стоят в пустой середине нижней линии. Низ — квадраты по углам,
//  при своём поле справа зеркально.
//
//  Вибрации здесь нет: у iPad нет вибромотора, её нет и в «Настройках».
//  «Подтверждать завершение партии», имя и Pro — только в «Настройках».
//

import SwiftUI

private enum PadLevelMetrics {
    static let columnGap: CGFloat = 24
    /// Вся раскладка — не шире этого, по центру экрана.
    static let maxWidth: CGFloat = 1000
    static let rowGap: CGFloat = 8
    static let levelRadius: CGFloat = 20
    static let cardRadius: CGFloat = 24
    static let optionsRadius: CGFloat = 18
    /// Горизонтально левая колонка шире — описание «Эксперта» в две строки;
    /// вертикально поровну: правой нужна ширина под числа и тумблеры.
    static let wideLeftShare: CGFloat = 0.54
    /// Сторона поля: своя ширина, а не вся колонка — горизонтально ряд стоит
    /// на нижней линии и не должен доставать до углового квадрата.
    static let sidePickWidth: CGFloat = 240
}

struct PadLevelScreen: View {
    let selected: AppState.DifficultyLevel
    let isPremium: Bool
    var onSelect: (AppState.DifficultyLevel) -> Void = { _ in }
    var onLocked: () -> Void = {}
    var onStart: () -> Void = {}
    var onBack: () -> Void = {}
    var onMenu: () -> Void = {}
    var options = LevelMatchOptions()

    @State private var viewportHeight: CGFloat = 0
    @State private var screenWidth: CGFloat = 0
    @State private var isWide = false
    @Environment(\.locale) private var locale

    private typealias M = PadLevelMetrics

    private var selectedIsLocked: Bool { selected.isPremium && !isPremium }

    var body: some View {
        VStack(spacing: 0) {
            ScreenTitle(title: "Single player", back: "Home", onBack: onBack)
                .padding(.top, NavMetrics.titleTopBelowSafeArea)
                .frame(maxWidth: M.maxWidth)
                .padding(.horizontal, Geometry.Inset.padFrame)
            ScrollView {
                VStack(spacing: 18) {
                    // Две колонки одной высоты: строки уровней и карточка
                    // партии тянутся, низ колонок вровень.
                    HStack(alignment: .top, spacing: M.columnGap) {
                        levels
                            .frame(width: leftWidth)
                        VStack(alignment: .leading, spacing: 14) {
                            overline("Match")
                            matchCard
                                .frame(maxHeight: .infinity)
                            optionRows
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    if !isWide { underRightColumn }
                }
                .frame(maxWidth: M.maxWidth)
                .padding(.horizontal, Geometry.Inset.padFrame + Geometry.Nav.stackInset)
                .padding(.vertical, Geometry.Nav.titleGap)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .frame(minHeight: viewportHeight, alignment: .center)
            }
            .seaScroll()
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { viewportHeight = $0 }

            BottomStack(onMenu: onMenu) {
                // Форма с явной надписью: на `Button("…", action:)` спотыкается
                // инструментирование превью. «Эксперт» без Pro можно выбрать
                // ради описания, но не начать: кнопка зовёт Pro.
                if selectedIsLocked {
                    Button { onLocked() } label: { Text("Unlock with Pro") }
                        .primaryButton()
                } else {
                    Button { onStart() } label: { Text("Start match") }
                        .primaryButton()
                }
            }
            // Горизонтально высоты не хватает: сторона поля и звук — в пустой
            // середине нижней линии, под правой колонкой.
            .overlay {
                if isWide {
                    underRightColumn
                        .frame(maxWidth: M.maxWidth)
                        .padding(.horizontal, Geometry.Inset.padFrame + Geometry.Nav.stackInset)
                        .padding(.bottom, Geometry.Inset.padFrame)
                }
            }
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
            isWide = size.width > size.height
            screenWidth = size.width
        }
    }

    /// Ширина левой колонки. Считается от экрана, а не от замера колонок:
    /// иначе ширина зависела бы сама от себя.
    private var leftWidth: CGFloat {
        let content = min(M.maxWidth,
                          screenWidth - 2 * (Geometry.Inset.padFrame + Geometry.Nav.stackInset))
        return max(0, (content - M.columnGap) * (isWide ? M.wideLeftShare : 0.5))
    }

    // MARK: Уровни

    private var levels: some View {
        VStack(alignment: .leading, spacing: M.rowGap) {
            overline("Opponent level")
            // Строки одной высоты — по самой высокой (описание «Эксперта»
            // целиком), и вместе до высоты правой колонки.
            EqualRowsColumn(spacing: M.rowGap) {
                ForEach(LevelChoice.all) { choice in
                    LevelBlurbRow(choice: choice, isSelected: choice.level == selected,
                                  isLocked: choice.isLocked(isPremium: isPremium)) {
                        onSelect(choice.level)
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Карточка партии

    /// Тянется до высоты колонки уровней: название вверху, числа посередине,
    /// итоги на уровне внизу — воздух между ними, а не по краям.
    private var matchCard: some View {
        let record = options.record(selected)
        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                ScaledSymbol(name: LevelChoice.icon, box: 26,
                             variableValue: LevelChoice.iconValue(for: selected))
                    .foregroundStyle(Color.roleYou)
                Text(LevelChoice.title(for: selected))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.inkPrimary)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            HStack(spacing: 0) {
                number("+\(selected.pointsValue)", caption: "per win", warm: true)
                divider
                number("\(selected.pointsValue)", caption: "per hint", warm: false)
                divider
                number("\(options.balance)", caption: "you have", warm: false)
            }
            .accessibilityIdentifier("levelStake")
            Spacer(minLength: 0)
            Rectangle()
                .fill(Color.glassStroke)
                .frame(height: 1)
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("All games · \(Text(LevelChoice.title(for: selected)))")
                        .font(.system(size: ResultMetrics.capLabel, weight: .bold))
                        .tracking(ResultMetrics.capTracking)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.inkSecondary)
                    Text("\(Text("\(record.wins) wins")) · \(Text("\(record.losses) losses"))")
                        .font(.system(size: 14))
                        .monospacedDigit()
                        .foregroundStyle(Color.inkPrimary)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(verbatim: record.winShare.map { StatBar.percent($0) } ?? "—")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.roleYou)
                    Text("win rate")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color.inkSecondary)
                }
            }
            .accessibilityElement(children: .combine)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .frame(maxHeight: .infinity)
        .glassPanel(.g2, radius: M.cardRadius, highlight: .selected)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.glassStroke)
            .frame(width: 1, height: 40)
            .accessibilityHidden(true)
    }

    private func number(_ value: String, caption: LocalizedStringKey, warm: Bool) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: PointsSymbol.name)
                    .font(.system(size: 17, weight: .semibold))
                    .accessibilityHidden(true)
                Text(verbatim: value)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(warm ? Color.roleYou : Color.inkPrimary)
            Text(caption)
                .font(.system(size: 12.5))
                .foregroundStyle(Color.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: Настройки партии

    private var optionRows: some View {
        VStack(spacing: 0) {
            ListToggleRow(title: "Mark the water around sunk ships", isOn: options.markWater)
                .accessibilityIdentifier("levelAutoReveal")
            ListDivider()
            // Без Pro строка видна, но закрыта: нажатие поднимает Pro, как
            // закрытый «Эксперт» в списке.
            ListToggleRow(title: "Expert remembers my fleets", isOn: options.expertRemembers,
                          onLocked: isPremium ? nil : onLocked)
                .accessibilityIdentifier("levelExpertMemory")
            ListDivider()
            ListToggleRow(title: "Ask for the level before a match", isOn: options.askLevel)
                .accessibilityIdentifier("levelAskLevel")
        }
        .glassPanel(.g2, radius: M.optionsRadius)
    }

    /// Ниже блоков, под правой колонкой: сторона своего поля и звук одной
    /// строкой.
    private var underRightColumn: some View {
        HStack(alignment: .top, spacing: M.columnGap) {
            Color.clear
                .frame(width: leftWidth, height: 1)
            VStack(alignment: .leading, spacing: 8) {
                overline("Your board in landscape")
                HStack(spacing: 16) {
                    SegmentedPick(options: [(false, String(game: "Left", locale: locale)),
                                            (true, String(game: "Right", locale: locale))],
                                  selection: options.ownBoardOnRight)
                        .frame(width: M.sidePickWidth)
                        .accessibilityIdentifier("levelOwnBoardSide")
                    LevelSoundRow(soundOn: options.soundOn, musicOn: options.musicOn,
                                  hapticsOn: options.hapticsOn, offersHaptics: options.offersHaptics)
                        .fixedSize()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func overline(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.system(size: LevelMetrics.overlineSize, weight: .bold))
            .tracking(LevelMetrics.overlineTracking)
            .textCase(.uppercase)
            .foregroundStyle(Color.inkSecondary)
            .padding(.leading, LevelMetrics.overlineInset)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Столбик строк одной высоты

/// Строки одной высоты: каждая не ниже самой высокой при этой ширине, весь
/// столбик — до предложенной высоты, если её больше.
private struct EqualRowsColumn: Layout {
    var spacing: CGFloat

    private func rowHeight(_ width: CGFloat?, _ subviews: Subviews) -> CGFloat {
        subviews.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).height }.max() ?? 0
    }

    private func gaps(_ subviews: Subviews) -> CGFloat {
        spacing * CGFloat(max(0, subviews.count - 1))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width
            ?? subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        let natural = rowHeight(width, subviews) * CGFloat(subviews.count) + gaps(subviews)
        return CGSize(width: width, height: max(natural, proposal.height ?? natural))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews,
                       cache: inout ()) {
        guard !subviews.isEmpty else { return }
        let height = max(rowHeight(bounds.width, subviews),
                         (bounds.height - gaps(subviews)) / CGFloat(subviews.count))
        var y = bounds.minY
        for subview in subviews {
            subview.place(at: CGPoint(x: bounds.minX, y: y), anchor: .topLeading,
                          proposal: ProposedViewSize(width: bounds.width, height: height))
            y += height + spacing
        }
    }
}

// MARK: - Строка уровня с полным описанием

private struct LevelBlurbRow: View {
    let choice: LevelChoice
    let isSelected: Bool
    let isLocked: Bool
    let action: () -> Void

    var body: some View {
        Button { action() } label: {
            HStack(alignment: .top, spacing: 14) {
                ScaledSymbol(name: choice.icon, box: 26, variableValue: choice.iconValue)
                    .foregroundStyle(Color.inkPrimary)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(choice.title)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.inkPrimary)
                    Text(choice.level.blurb)
                        .font(.system(size: 13.5))
                        .foregroundStyle(Color.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                mark
                    .padding(.top, 2)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassPanel(.g2, radius: PadLevelMetrics.levelRadius, highlight: isSelected ? .selected : .none)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityValue(isLocked ? Text("Pro") : Text(""))
    }

    @ViewBuilder
    private var mark: some View {
        if isLocked {
            Image(systemName: "lock.fill")
                .font(.system(size: symbolFontSize(inBox: 16)))
                .foregroundStyle(Color.inkPrimary)
                .opacity(ControlMetrics.ModeRow.lockOpacity)
                .frame(width: 22)
        } else if isSelected {
            Image(systemName: "checkmark")
                .font(.system(size: symbolFontSize(inBox: 18), weight: .semibold))
                .foregroundStyle(Color.roleYou)
                .frame(width: 22)
        } else {
            Color.clear.frame(width: 22, height: 1)
        }
    }
}

// MARK: - Превью

private struct PadLevelDemo: View {
    var onRight = false

    @State private var selected: AppState.DifficultyLevel = .hard
    @State private var markWater = true
    @State private var expertMemory = false
    @State private var askLevel = true
    @State private var ownOnRight = false
    @State private var soundOn = true
    @State private var musicOn = false

    var body: some View {
        ZStack {
            SeaBackground()
                .ignoresSafeArea()
            PadLevelScreen(selected: selected, isPremium: false,
                           onSelect: { selected = $0 },
                           options: LevelMatchOptions(balance: 42, markWater: $markWater,
                                                      soundOn: $soundOn, musicOn: $musicOn,
                                                      offersHaptics: false,
                                                      expertRemembers: $expertMemory,
                                                      askLevel: $askLevel,
                                                      ownBoardOnRight: $ownOnRight,
                                                      record: { _ in StatRecord(wins: 21, losses: 11) }))
                .environment(\.mirrorsBottomTiles, ownOnRight)
        }
        .environment(\.usesPadLayout, true)
        .environment(\.bottomChrome, .tiles)
        .preferredColorScheme(.dark)
        .onAppear { ownOnRight = onRight }
    }
}

struct PadLevel1_Previews: PreviewProvider {
    static var previews: some View {
        PadLevelDemo()
            .padPreview(.portrait, "Уровень iPad · вертикально")
    }
}

struct PadLevel2_Previews: PreviewProvider {
    static var previews: some View {
        PadLevelDemo()
            .padPreview(.landscapeLeft, "Уровень iPad · горизонтально")
    }
}

struct PadLevel3_Previews: PreviewProvider {
    static var previews: some View {
        PadLevelDemo(onRight: true)
            .padPreview(.landscapeLeft, "Уровень iPad · своё поле справа")
    }
}
