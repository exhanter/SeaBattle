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

/// Подсветка панели. Выбранная строка выбора (`ChoiceRow`, спека 2.13)
/// отличается от обычной ровно двумя вещами: обводка становится латунной и
/// вместо тени панель даёт свечение. Это свойство панели, а не строки, поэтому
/// живёт здесь — иначе `ChoiceRow` пришлось бы рисовать обводку поверх готовой
/// панели, и их стало бы две.
enum GlassHighlight: Equatable, Sendable {
    case none
    /// Выбрано: обводка `Role/You`, свечение `Role/YouSoft` вместо тени.
    case selected
    /// Рамка результата на итогах (4.9, кадр `screen10Result`): та же схема —
    /// обводка и свечение вместо тени, — но в цвете исхода: победа тёплая,
    /// поражение холодное.
    case outcome(Side)

    var isSelected: Bool { self == .selected }
    /// Есть ли подсветка вообще: у подсвеченной панели свечение **вместо**
    /// тени.
    var isLit: Bool { self != .none }

    var stroke: Color? {
        switch self {
        case .none: nil
        case .selected, .outcome(.you): .roleYou
        case .outcome(.foe): .roleFoe
        }
    }

    /// Свечение поражения в макете — `rgba(60,127,191,.24)`, а токена
    /// «холодное мягкое» в пакете нет (есть только тёплый `Role/YouSoft`).
    /// До ответа дизайна (В18) — `Board/FillFoe`, ближайший холодный токен:
    /// он тише макета, а не громче.
    var glow: Color {
        switch self {
        case .none: .clear
        case .selected, .outcome(.you): .roleYouSoft
        case .outcome(.foe): .boardFillFoe
        }
    }

    var glowRadius: CGFloat {
        switch self {
        case .none, .selected: ControlMetrics.ChoiceRow.selectedGlow
        case .outcome: ResultMetrics.frameGlow
        }
    }
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
                    highlight: GlassHighlight = .none,
                    treatment: GlassTreatment = .automatic) -> some View {
        modifier(GlassPanelModifier(level: level, radius: radius,
                                    wood: wood, highlight: highlight,
                                    treatment: treatment))
    }
}

struct GlassPanelModifier: ViewModifier {
    let level: GlassLevel
    let radius: CGFloat
    let wood: WoodEdge
    var highlight: GlassHighlight = .none
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
    /// иначе они удвоились бы. Тонировка нужна по двум причинам: без неё белая
    /// краска на светлом море теряет контраст, и без неё приподнятый слой не
    /// отличается от обычной панели — системное стекло само по себе про уровни
    /// ничего не знает. Тон берётся из ассета, поэтому проверки темы в коде
    /// по-прежнему нет.
    @available(iOS 26, *)
    private func systemGlass(_ content: Content) -> some View {
        let tint: Color = level == .g3 ? .glassRaisedFill : .glassFill
        return content
            .glassEffect(.regular.tint(tint), in: shape)
            .overlay { woodEdge }
            .overlay { selectedStroke }
            .shadow(color: highlight.glow, radius: highlight.glowRadius)
    }

    /// Латунная обводка выбранной панели. Рисуется поверх и на ветке системного
    /// стекла тоже: обводку там ставит система, но роль она не знает.
    @ViewBuilder
    private var selectedStroke: some View {
        if let stroke = highlight.stroke {
            shape.strokeBorder(stroke, lineWidth: level.spec.strokeWidth)
        }
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
            // У выбранной панели свечение **вместо** тени, а не вдобавок к ней
            // (спека 2.13): иначе латунный ободок тонет в тёмном ореоле.
            .shadow(color: highlight.isLit ? highlight.glow
                           : (spec.hasShadow ? shadowColor : .clear),
                    radius: highlight.isLit ? highlight.glowRadius : spec.shadowRadius,
                    y: highlight.isLit ? 0 : spec.shadowOffsetY)
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
        if let stroke = highlight.stroke { return stroke }
        switch level {
        case .g1: return .glassSolidStroke
        case .g2: return .glassStroke
        case .g3: return .glassRaisedStroke
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

                // G2 и G1 показаны панелью, G3 — листом: у каждого уровня свой
                // настоящий размер. На плашке размером с кнопку обводка G3
                // в 1,5 pt читается жирным кантом, хотя на листе это тонкий
                // ободок, — сравнивать надо в том размере, в каком применяется.
                HStack(spacing: 12) {
                    panel(.g2, .liquid, height: 64)
                    panel(.g2, .material, height: 64)
                }
                HStack(spacing: 12) {
                    panel(.g3, .liquid, height: 190, caption: "лист или поповер")
                    panel(.g3, .material, height: 190, caption: "лист или поповер")
                }
                HStack(spacing: 12) {
                    panel(.g1, .liquid, height: 64, caption: "передача устройства")
                    panel(.g1, .material, height: 64, caption: "передача устройства")
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

    private func panel(_ level: GlassLevel, _ treatment: GlassTreatment,
                       height: CGFloat, caption: String = "ход 14 · 02:41") -> some View {
        VStack(spacing: 4) {
            Text(level.rawValue.uppercased())
                .font(TypeScale.headline)
                .foregroundStyle(Color.inkPrimary)
            Text(caption)
                .font(TypeScale.footnote)
                .foregroundStyle(Color.inkSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: height)
        .padding(14)
        .glassPanel(level,
                    radius: level == .g3 ? Geometry.Radius.sheet : Geometry.Radius.panel,
                    treatment: treatment)
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
