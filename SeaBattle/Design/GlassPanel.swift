//
//  GlassPanel.swift
//  Sea Battle — стекло над морем
//
//  Три уровня стекла из спеки 2.2. Различаются только значениями, поэтому
//  геометрия и порядок слоёв здесь одни на все панели и на обе темы: ни одной
//  проверки `colorScheme`, разницу тем делает ассет-каталог.
//
//  Про Liquid Glass. Дизайн-база — нормы iOS 26, но реализация предписана
//  системными материалами (`Material.glassPanel` / `.glassRaised` в пакете
//  токенов): минимум у приложения iOS 18, а `glassEffect(_:in:)` появился в
//  iOS 26 и приносит свои заливку, обводку и реакцию на касание — они спорили
//  бы с утверждёнными значениями токенов. Поэтому ветвлений по версии ОС нет,
//  раскладка одинаковая везде.
//
//  Порядок слоёв снизу вверх: материал → заливка → обводка → блик → деревянный
//  кант → обрезка по форме → тень наружу. Тень ставится после обрезки, иначе
//  она повторяла бы прямоугольник, а не скруглённую форму.
//

import SwiftUI

// MARK: - Уровни

enum GlassLevel: String, CaseIterable, Sendable {
    /// Глухой слой: передача устройства, шторки. Ни блюра, ни блика, ни тени —
    /// сквозь него не должно просвечивать ничего.
    case g1
    /// Все обычные панели.
    case g2
    /// Приподнятый слой: листы, поповеры, окошки выбора.
    case g3

    var spec: GlassSpec {
        switch self {
        case .g1: GlassSpec(strokeWidth: 1, sheenWidth: 0,
                            shadowRadius: 0, shadowOffsetY: 0, hasMaterial: false)
        case .g2: GlassSpec(strokeWidth: 1, sheenWidth: 1,
                            shadowRadius: 12, shadowOffsetY: 8, hasMaterial: true)
        case .g3: GlassSpec(strokeWidth: 1.5, sheenWidth: 2,
                            shadowRadius: 15, shadowOffsetY: 10, hasMaterial: true)
        }
    }
}

/// Числа уровня отдельно от вида — чтобы таблицу из спеки можно было сверить
/// тестом, а не рендером. Радиусы тени переведены из CSS: `0 8 24` даёт
/// `radius 12, y 8` (в CSS размытие считается по диаметру, в SwiftUI — по радиусу).
struct GlassSpec: Equatable, Sendable {
    let strokeWidth: CGFloat
    /// 0 — блика нет (G1).
    let sheenWidth: CGFloat
    /// 0 — тени нет (G1).
    let shadowRadius: CGFloat
    let shadowOffsetY: CGFloat
    /// G1 глухой, блюра под ним нет.
    let hasMaterial: Bool

    var hasSheen: Bool { sheenWidth > 0 }
    var hasShadow: Bool { shadowRadius > 0 }
}

/// Деревянный кант 2 pt на кромке, которая смотрит в море: у верхней панели это
/// низ, у нижней — верх. Левых и правых кантов нет нигде (спека, правило 2).
enum WoodEdge: Sendable {
    case none
    /// Кант по верхней кромке — для нижних панелей.
    case top
    /// Кант по нижней кромке — для верхних панелей.
    case bottom

    var alignment: Alignment {
        switch self {
        case .top, .none: .top
        case .bottom: .bottom
        }
    }
}

// MARK: - Чем рисовать стекло

/// На iOS 26 стекло рисует система: настоящее преломление, блик по кромке и
/// подстройка под то, что лежит под панелью. На iOS 18 такого нет, остаются
/// системные материалы — раскладка и токены при этом те же, отличается только
/// материал. Ветвление ровно одно и живёт здесь.
enum GlassTreatment: Sendable {
    /// Системное стекло, где оно есть; материалы, где нет.
    case automatic
    /// Принудительно системное стекло — для сравнения в превью.
    case liquid
    /// Принудительно материалы — для сравнения в превью и для G1.
    case material

    /// Решение вынесено в чистую функцию, чтобы правило «G1 стеклом не бывает»
    /// проверялось тестом, а не полагалось на память.
    ///
    /// G1 — глухая шторка передачи устройства: сквозь неё не должно просвечивать
    /// поле соперника. Системное стекло прозрачно по определению, поэтому для G1
    /// оно запрещено независимо от версии ОС.
    static func usesSystemGlass(_ treatment: GlassTreatment,
                                level: GlassLevel,
                                systemGlassAvailable: Bool) -> Bool {
        guard level != .g1 else { return false }
        switch treatment {
        case .material: return false
        case .liquid: return systemGlassAvailable
        case .automatic: return systemGlassAvailable
        }
    }
}

// MARK: - Панель

extension View {
    /// Оборачивает содержимое в стеклянную панель. Отступы внутри панели задаёт
    /// вызывающий: у строки режима и у панели счёта они разные.
    func glassPanel(_ level: GlassLevel = .g2,
                    radius: CGFloat = Geometry.Radius.panel,
                    wood: WoodEdge = .none,
                    treatment: GlassTreatment = .automatic) -> some View {
        modifier(GlassPanelModifier(level: level, radius: radius,
                                    wood: wood, treatment: treatment))
    }
}

struct GlassPanelModifier: ViewModifier {
    let level: GlassLevel
    let radius: CGFloat
    let wood: WoodEdge
    var treatment: GlassTreatment = .automatic

    func body(content: Content) -> some View {
        Group {
            if #available(iOS 26, *),
               GlassTreatment.usesSystemGlass(treatment, level: level,
                                              systemGlassAvailable: true) {
                systemGlass(content)
            } else {
                materials(content)
            }
        }
    }

    /// iOS 26+. Заливку, обводку и блик рисует система, поэтому своих здесь нет —
    /// иначе они удвоились бы. Тон задаётся `Glass/Fill`: без тонировки белая
    /// краска на светлом море теряет контраст, а тонировка берётся из ассета и
    /// потому по-прежнему не требует проверки темы в коде.
    @available(iOS 26, *)
    private func systemGlass(_ content: Content) -> some View {
        content
            .glassEffect(.regular.tint(Color.glassFill), in: shape)
            .overlay { woodEdge }
    }

    /// Кант рисуется во весь размер панели и обрезается её формой, а не сам по
    /// себе: полоску 2 pt скруглением не обрезать — она обрежется по своей
    /// высоте и повиснет отдельной чертой мимо углов.
    @ViewBuilder
    private var woodEdge: some View {
        if wood != .none {
            shape
                .fill(.clear)
                .overlay(alignment: wood.alignment) {
                    Color.wood.frame(height: Geometry.woodEdge)
                }
                .clipShape(shape)
        }
    }

    /// iOS 18 и всё, что не стекло: материал плюс наши заливка, обводка, блик и
    /// тень по таблице спеки 2.2.
    private func materials(_ content: Content) -> some View {
        let spec = level.spec
        return content
            .background {
                shape
                    .fill(fill)
                    .background {
                        if spec.hasMaterial {
                            shape.fill(material)
                        }
                    }
            }
            .overlay {
                shape.strokeBorder(stroke, lineWidth: spec.strokeWidth)
            }
            .overlay {
                if spec.hasSheen {
                    // «Блик внутрь сверху»: в макете это inset-тень без размытия,
                    // то есть светлая линия по верхней кромке. Здесь — обводка
                    // градиентом, который гаснет к четверти высоты: так блик и
                    // повторяет скругление, и не светит по низу панели.
                    shape
                        .inset(by: spec.strokeWidth)
                        .strokeBorder(sheenGradient, lineWidth: spec.sheenWidth)
                }
            }
            .overlay { woodEdge }
            .clipShape(shape)
            .shadow(color: spec.hasShadow ? shadowColor : .clear,
                    radius: spec.shadowRadius,
                    y: spec.shadowOffsetY)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }

    private var fill: AnyShapeStyle {
        switch level {
        // G1 заливается ровным цветом: это не стекло, а глухая шторка.
        case .g1: AnyShapeStyle(Color.glassSolid)
        case .g2: AnyShapeStyle(LinearGradient.glassPanelFill)
        case .g3: AnyShapeStyle(LinearGradient.glassRaisedFill)
        }
    }

    private var material: Material {
        level == .g3 ? .glassRaised : .glassPanel
    }

    private var stroke: Color {
        switch level {
        case .g1: .glassSolidStroke
        case .g2: .glassStroke
        case .g3: .glassRaisedStroke
        }
    }

    private var sheenGradient: LinearGradient {
        let sheen: Color = level == .g3 ? .glassRaisedSheen : .glassSheen
        return LinearGradient(stops: [.init(color: sheen, location: 0),
                                      .init(color: .clear, location: 0.25)],
                              startPoint: .top, endPoint: .bottom)
    }

    private var shadowColor: Color {
        level == .g3 ? .glassRaisedShadow : .glassShadow
    }
}

// MARK: - Превью: проверка шага 2 порядка сборки

/// Пустой экран с верхней и нижней панелями — ровно та проверка, которой
/// заканчивается шаг 2: видно фон, дыхание свечения, стекло и деревянный кант.
private struct GlassPanelDemo: View {
    var body: some View {
        ZStack {
            SeaBackground()

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Ваш ход")
                        .font(TypeScale.headline)
                        .foregroundStyle(Color.inkPrimary)
                    Text("ход 14 · 02:41")
                        .font(TypeScale.footnote)
                        .foregroundStyle(Color.inkSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .glassPanel(.g2, wood: .bottom)

                Spacer()

                VStack(spacing: 12) {
                    Text("G3 — приподнятый слой")
                        .font(TypeScale.callout)
                        .foregroundStyle(Color.inkPrimary)
                        .padding(14)
                        .glassPanel(.g3, radius: Geometry.Radius.button)

                    Text("G1 — глухая шторка")
                        .font(TypeScale.callout)
                        .foregroundStyle(Color.inkPrimary)
                        .padding(14)
                        .glassPanel(.g1, radius: Geometry.Radius.button)
                }

                Spacer()

                HStack(spacing: 28) {
                    ForEach(["Играть", "Статистика", "Настройки"], id: \.self) { title in
                        Text(title)
                            .font(TypeScale.caption)
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .glassPanel(.g2, radius: Geometry.Radius.panelLarge, wood: .top)
            }
            .padding(.horizontal, Geometry.Inset.phoneSide)
            .padding(.vertical, 54)
        }
    }
}

/// Сравнение двух трактовок в одном кадре: слева то, что увидят на iOS 26,
/// справа — то, что останется на iOS 18. Раскладка, радиусы, кант и краска
/// одинаковы, отличается только материал.
private struct GlassTreatmentComparison: View {
    var body: some View {
        ZStack {
            SeaBackground()

            VStack(spacing: 18) {
                Text("iOS 26 · системное стекло  ↔  iOS 18 · материалы")
                    .font(TypeScale.footnote)
                    .foregroundStyle(Color.inkSecondary)

                ForEach([GlassLevel.g2, .g3, .g1], id: \.self) { level in
                    HStack(spacing: 12) {
                        panel(level, .liquid)
                        panel(level, .material)
                    }
                }

                HStack(spacing: 12) {
                    tabBar(.liquid)
                    tabBar(.material)
                }

                Spacer()
            }
            .padding(.horizontal, Geometry.Inset.phoneSide)
            .padding(.vertical, 54)
        }
    }

    private func panel(_ level: GlassLevel, _ treatment: GlassTreatment) -> some View {
        VStack(spacing: 4) {
            Text(level.rawValue.uppercased())
                .font(TypeScale.headline)
                .foregroundStyle(Color.inkPrimary)
            Text("ход 14 · 02:41")
                .font(TypeScale.footnote)
                .foregroundStyle(Color.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .glassPanel(level, treatment: treatment)
    }

    private func tabBar(_ treatment: GlassTreatment) -> some View {
        Text("нижняя панель")
            .font(TypeScale.caption)
            .foregroundStyle(Color.inkSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .glassPanel(.g2, radius: Geometry.Radius.panelLarge,
                        wood: .top, treatment: treatment)
    }
}

#Preview("Стекло · тёмная") {
    GlassPanelDemo()
        .preferredColorScheme(.dark)
}

#Preview("Стекло · светлая") {
    GlassPanelDemo()
        .preferredColorScheme(.light)
}

#Preview("iOS 26 против iOS 18 · тёмная") {
    GlassTreatmentComparison()
        .preferredColorScheme(.dark)
}

#Preview("iOS 26 против iOS 18 · светлая") {
    GlassTreatmentComparison()
        .preferredColorScheme(.light)
}
