//
//  TokenGalleryView.swift
//  Sea Battle — проверка дизайн-системы
//
//  Экран-галерея: все токены из `DesignTokens.swift` одним списком, в обеих
//  темах. Нужен затем, чтобы опечатка в имени ассета и разъехавшееся значение
//  были видны глазом, а не всплывали через три экрана. В игре не участвует —
//  открывается из превью Xcode.
//
//  Цвета показаны на морском градиенте, потому что весь интерфейс лежит на нём:
//  прозрачные токены имеют смысл только вместе со своим фоном.
//

import SwiftUI

struct TokenGalleryView: View {

    /// Тема переключается внутри экрана, чтобы сравнивать значения не выходя
    /// в настройки системы. Это инструмент проверки; в самом интерфейсе
    /// решений по теме нет — их принимает ассет-каталог.
    @State private var scheme: ColorScheme

    init(scheme: ColorScheme = .dark) {
        _scheme = State(initialValue: scheme)
    }

    var body: some View {
        ZStack {
            LinearGradient.sea.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    gradients
                    colors
                    cells
                    typography
                    motion
                }
                .padding(Geometry.Inset.phoneSide)
                .padding(.bottom, 40)
            }
        }
        .environment(\.colorScheme, scheme)
    }

    // MARK: - Разделы

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Токены")
                .font(TypeScale.display)
                .foregroundStyle(Color.inkPrimary)
            Text("\(ColorToken.allCases.count) цветов · Colors.xcassets")
                .font(TypeScale.footnote)
                .foregroundStyle(Color.inkSecondary)

            Picker("Тема", selection: $scheme) {
                Text("Тёмная").tag(ColorScheme.dark)
                Text("Светлая").tag(ColorScheme.light)
            }
            .pickerStyle(.segmented)
        }
    }

    private var gradients: some View {
        section("Градиенты") {
            // Море и свечение показаны вместе: в приложении это два слоя одного
            // фона, и второй виден только поверх первого.
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: Geometry.Radius.chip, style: .continuous)
                    .fill(LinearGradient.sea)
                    .frame(height: 68)
                    .overlay {
                        GeometryReader { proxy in
                            RadialGradient.seaGlow(in: proxy.size)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Geometry.Radius.chip,
                                                style: .continuous))
                Text("sea + seaGlow — неподвижный градиент и дышащий слой над ним")
                    .font(TypeScale.caption)
                    .foregroundStyle(Color.inkTertiary)
            }
            gradientBar("LinearGradient.sea", LinearGradient.sea)
            gradientBar("waterCell", LinearGradient.waterCell)
            gradientBar("hullSand", LinearGradient.hullSand)
            gradientBar("hullDenied", LinearGradient.hullDenied)
            gradientBar("steelSunk", LinearGradient.steelSunk)
            gradientBar("glassPanelFill (G2)", LinearGradient.glassPanelFill)
            gradientBar("glassRaisedFill (G3)", LinearGradient.glassRaisedFill)
            gradientBar("buttonBrass — подложка главной кнопки", LinearGradient.buttonBrass)
        }
    }

    private var colors: some View {
        ForEach(ColorToken.groups, id: \.name) { group in
            section(group.name) {
                ForEach(group.tokens, id: \.self) { token in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: Geometry.Radius.chip, style: .continuous)
                            .fill(token.color)
                            .frame(width: 64, height: 30)
                            .overlay(
                                RoundedRectangle(cornerRadius: Geometry.Radius.chip, style: .continuous)
                                    .strokeBorder(Color.glassStroke, lineWidth: 1)
                            )
                        Text(token.shortName)
                            .font(TypeScale.callout)
                            .foregroundStyle(Color.inkPrimary)
                        Spacer(minLength: 0)
                        Text(token.rawValue)
                            .font(TypeScale.caption)
                            .foregroundStyle(Color.inkTertiary)
                    }
                }
            }
        }
    }

    private var cells: some View {
        section("Клетка: размер и радиус") {
            ForEach(Self.cellSizes, id: \.0) { size, label in
                HStack(spacing: 12) {
                    HStack(spacing: Geometry.Cell.gapPhone) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: Geometry.cellRadius(for: size),
                                             style: .continuous)
                                .fill(LinearGradient.waterCell)
                                .frame(width: size, height: size)
                        }
                    }
                    .frame(width: 150, alignment: .leading)

                    Text(label)
                        .font(TypeScale.callout)
                        .foregroundStyle(Color.inkPrimary)
                    Spacer(minLength: 0)
                    Text("\(Int(size)) pt · r \(Int(Geometry.cellRadius(for: size)))")
                        .font(TypeScale.tally)
                        .foregroundStyle(Color.inkTertiary)
                }
            }
        }
    }

    private var typography: some View {
        section("Типографика") {
            typeRow("display · 34 rounded", TypeScale.display)
            typeRow("title · 24 rounded", TypeScale.title)
            typeRow("headline · 17", TypeScale.headline)
            typeRow("body · 16", TypeScale.body)
            typeRow("callout · 15", TypeScale.callout)
            typeRow("footnote · 13", TypeScale.footnote)
            typeRow("caption · 11", TypeScale.caption)
            typeRow("tally · 15 · 1234567890", TypeScale.tally)
        }
    }

    private var motion: some View {
        section("Движение") {
            ForEach(Self.durations, id: \.0) { name, value in
                HStack {
                    Text(name)
                        .font(TypeScale.callout)
                        .foregroundStyle(Color.inkPrimary)
                    Spacer(minLength: 0)
                    Text(value)
                        .font(TypeScale.tally)
                        .foregroundStyle(Color.inkSecondary)
                }
            }
        }
    }

    // MARK: - Кирпичи

    /// Панель G2 с деревянным кантом по верхней кромке — заодно проверка,
    /// что стекло и кант читаются на обеих темах.
    private func section<Content: View>(_ title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(TypeScale.headline)
                .foregroundStyle(Color.inkSecondary)
                .textCase(.uppercase)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Geometry.Radius.panel, style: .continuous)
                .fill(LinearGradient.glassPanelFill)
                .background(Material.glassPanel,
                            in: RoundedRectangle(cornerRadius: Geometry.Radius.panel,
                                                 style: .continuous))
        }
        .overlay(alignment: .top) {
            Color.wood.frame(height: Geometry.woodEdge)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Geometry.Radius.panel, style: .continuous)
                .strokeBorder(Color.glassStroke, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: Geometry.Radius.panel, style: .continuous))
        .shadow(color: .glassShadow, radius: 12, y: 8)
    }

    private func gradientBar(_ name: String, _ gradient: LinearGradient) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            RoundedRectangle(cornerRadius: Geometry.Radius.chip, style: .continuous)
                .fill(gradient)
                .frame(height: 34)
            Text(name)
                .font(TypeScale.caption)
                .foregroundStyle(Color.inkTertiary)
        }
    }

    private func typeRow(_ name: String, _ font: Font) -> some View {
        Text(name)
            .font(font)
            .foregroundStyle(Color.inkPrimary)
    }

    // MARK: - Данные галереи

    private static let cellSizes: [(CGFloat, String)] = [
        (Geometry.Cell.iPhoneSmallCoords, "iPhone SE, координаты"),
        (Geometry.Cell.iPhoneSmall, "iPhone SE 375"),
        (Geometry.Cell.iPhone, "iPhone 393"),
        (Geometry.Cell.iPadPortrait, "iPad вертикально"),
        (Geometry.Cell.iPadLandscape, "iPad горизонтально"),
        (Geometry.Cell.iPadPlacement, "iPad, расстановка"),
    ]

    private static let durations: [(String, String)] = [
        ("Прицел", "120 мс"),
        ("Всплеск", "240 мс"),
        ("Смена состояния клетки", "260 мс"),
        ("Подсветка контура", "520 мс"),
        ("Потопление, на клетку", "60 мс"),
        ("Выстрел по вам", "180 мс"),
        ("Капсула в ленте", "220 мс"),
        ("Смена хода", "160 + 240 мс"),
        ("Бой → итоги", "600 + 320 мс"),
        ("Начисление баллов", "500 мс"),
        ("Передача устройства", "260 + 180 мс"),
        ("Дыхание фона", "18 с"),
    ]
}

#Preview("Токены · тёмная") {
    TokenGalleryView(scheme: .dark)
}

#Preview("Токены · светлая") {
    TokenGalleryView(scheme: .light)
}
