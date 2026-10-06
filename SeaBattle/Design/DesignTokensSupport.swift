//
//  DesignTokensSupport.swift
//  Sea Battle — надстройка над дизайн-системой
//
//  `DesignTokens.swift` приходит из пакета дизайна и заменяется целиком при
//  каждом обновлении, поэтому наших правок в нём быть не должно. Всё, что
//  нужно нам, а не дизайну, живёт здесь:
//
//  - `ColorToken` — все имена ассетов одним перечислением. Из него строится
//    галерея (значит, ни один токен нельзя забыть показать) и по нему идёт
//    тест (значит, опечатка в имени ассета — красный тест, а не странный
//    оттенок на экране: `Color("Sea/Tpo")` не падает, а рисует не тем цветом);
//  - заливки панелей G1/G2/G3 как готовые градиенты;
//  - `Geometry.cellRadius(for:)` — радиус клетки от её размера;
//  - `Animation.reduced(_:)` — правило Reduce Motion «длительности × 0,5» для
//    готовых анимаций (`Motion.quick`, `Motion.standard`);
//  - `Font.scalable(size:weight:design:)` — кегль макета под Dynamic Type.
//
//  Исключение одно — `TypeScale` в `DesignTokens.swift` (R4.5d): его кегли
//  обёрнуты в `Font.scalable`. С 30.09 пакеты дизайна больше не приходят, а
//  две параллельные шкалы шрифтов разошлись бы быстрее, чем одна правка.
//  Если пакет всё же придёт — вернуть обёртку в `TypeScale`.
//
//  При обновлении пакета список ниже надо сверить с каталогом:
//  `find SeaBattle/Colors.xcassets -name '*.colorset'` против `ColorToken.allCases`.
//  Расхождение поймает тест `everyTokenResolves`.
//

import SwiftUI

// MARK: - Все токены списком

/// Каждый токен — путь внутри `Colors.xcassets`. Порядок как в `TOKENS.md`.
enum ColorToken: String, CaseIterable, Sendable {

    // Море: неподвижный градиент плюс дышащее свечение над ним.
    case seaTop    = "Sea/Top"
    case seaMid    = "Sea/Mid"
    case seaBottom = "Sea/Bottom"
    case seaGlow   = "Sea/Glow"

    // Роли: тёплый акцент — всегда «ты», холодный — всегда противник.
    case roleYou     = "Role/You"
    case roleFoe     = "Role/Foe"
    case roleYouSoft = "Role/YouSoft"
    /// Свечение рамки поражения на итогах — пара к `YouSoft` (раунд 6).
    case roleFoeSoft = "Role/FoeSoft"

    // Хром. `WoodDeep` — низ градиента мата вокруг фотографии и больше нигде:
    // кант панелей 2 pt остаётся ровным `Chrome/Wood`.
    case wood     = "Chrome/Wood"
    case woodDeep = "Chrome/WoodDeep"
    case fire     = "Chrome/Fire"
    /// Свечение капсулы «Убит» в игре на бумаге (раунд 8).
    case fireSoft = "Chrome/FireSoft"

    // Стекло G2 — все панели. Заливка всегда градиент `Fill → Fill2` под 135°;
    // в тёмной теме точки равны, поэтому выглядит ровной.
    case glassFill   = "Glass/Fill"
    case glassFill2  = "Glass/Fill2"
    case glassStroke = "Glass/Stroke"
    case glassSheen  = "Glass/Sheen"
    case glassShadow = "Glass/Shadow"

    // Стекло G3 — приподнятый слой: листы, поповеры, окошки выбора.
    case glassRaisedFill   = "Glass/RaisedFill"
    case glassRaisedFill2  = "Glass/RaisedFill2"
    case glassRaisedStroke = "Glass/RaisedStroke"
    case glassRaisedSheen  = "Glass/RaisedSheen"
    case glassRaisedShadow = "Glass/RaisedShadow"

    // Стекло G1 — глухой слой: ни блюра, ни блика, ни тени.
    case glassSolid       = "Glass/Solid"
    case glassSolidStroke = "Glass/SolidStroke"

    // Краска на стекле: в обеих темах панели тёмные, поэтому набор текста один.
    case inkPrimary   = "Ink/Primary"
    case inkSecondary = "Ink/Secondary"
    case inkTertiary  = "Ink/Tertiary"
    case inkOnBrass   = "Ink/OnBrass"
    /// Тень заголовка экрана. В тёмной теме прозрачная, в светлой держит белый
    /// текст на светлом море, поэтому тень рисуется всегда и ветки по теме нет.
    case inkTitleShadow = "Ink/TitleShadow"

    // Клетка · вода W1 / L2.
    case waterTop    = "Cell/WaterTop"
    case waterBottom = "Cell/WaterBottom"
    case waterSheen  = "Cell/WaterSheen"
    case waterShade  = "Cell/WaterShade"

    // Клетка · корпус K2 «Песок» и его бевель.
    case hullSandLight = "Cell/HullSandLight"
    case hullSand      = "Cell/HullSand"
    case hullSandDark  = "Cell/HullSandDark"
    case hullSheen     = "Cell/HullSheen"
    case hullShade     = "Cell/HullShade"

    // Клетка · запрещённая позиция при расстановке.
    case hullDeniedLight = "Cell/HullDeniedLight"
    case hullDenied      = "Cell/HullDenied"
    case hullDeniedDark  = "Cell/HullDeniedDark"

    // Клетка · промах M1 «воронка».
    case missPit = "Cell/MissPit"
    case missRim = "Cell/MissRim"

    // Клетка · пробоина F4 на поле противника, вариант огня P4. Кромок четыре и
    // они разного тона: изображают объём пробоины, свет сверху, тень снизу-справа.
    case fireHalo       = "Cell/FireHalo"
    case fireEdgeTop    = "Cell/FireEdgeTop"
    case fireEdgeLeft   = "Cell/FireEdgeLeft"
    case fireEdgeRight  = "Cell/FireEdgeRight"
    case fireEdgeBottom = "Cell/FireEdgeBottom"
    case fireEdgeHi     = "Cell/FireEdgeHi"
    case fireEdgeShadow = "Cell/FireEdgeShadow"
    case fireGlowIn     = "Cell/FireGlowIn"
    case fireGlowOut    = "Cell/FireGlowOut"
    case fireDarken     = "Cell/FireDarken"
    case fireCross      = "Cell/FireCross"
    case fireCrossEdge  = "Cell/FireCrossEdge"

    // Клетка · огонь F1 поверх своего корпуса: три слоя, снизу вверх
    // multiply → screen → обычный, плюс белый крест с тенью.
    case hitTintMulTop    = "Cell/HitTintMulTop"
    case hitTintMulBottom = "Cell/HitTintMulBottom"
    case hitTintScrTop    = "Cell/HitTintScrTop"
    case hitTintScrBottom = "Cell/HitTintScrBottom"
    case hitWarmIn        = "Cell/HitWarmIn"
    case hitWarmOut       = "Cell/HitWarmOut"
    case hitCross         = "Cell/HitCross"
    case hitCrossShadow   = "Cell/HitCrossShadow"

    // Клетка · уничтожен S4 «выгоревшая сталь». Крест лежит на тёмной стали и
    // в обеих темах оранжевый — это не тот же токен, что крест пробоины.
    case steelTop      = "Cell/SteelTop"
    case steelMid      = "Cell/SteelMid"
    case steelBottom   = "Cell/SteelBottom"
    case steelSheen    = "Cell/SteelSheen"
    case steelShade    = "Cell/SteelShade"
    case sunkCross     = "Cell/SunkCross"
    case sunkCrossEdge = "Cell/SunkCrossEdge"

    // Подложка поля: тёплая у своего, холодная у чужого. Отдельные токены, а не
    // `.opacity()` от цветов ролей: при перекраске ролей производные цвета
    // пришлось бы искать по коду (правило 8 спеки — альфа входит в цвет).
    case boardFillYou   = "Board/FillYou"
    case boardFillFoe   = "Board/FillFoe"
    case boardStrokeYou = "Board/StrokeYou"
    case boardStrokeFoe = "Board/StrokeFoe"
    /// Метка последнего попадания соперника на своём поле (игра на бумаге, раунд 8).
    case boardMarkFoe     = "Board/MarkFoe"
    case boardMarkFoeGlow = "Board/MarkFoeGlow"

    // Главная кнопка: кант — Role/You, ореол — Role/YouSoft, надпись — Ink/Primary.
    // Латунь подложки **разная по темам** (раунд 4): прежняя полупрозрачная не
    // держала белую надпись на светлом море.
    case buttonBrassTop    = "Button/BrassTop"
    case buttonBrassBottom = "Button/BrassBottom"
    case buttonSheen       = "Button/Sheen"
    case buttonShade       = "Button/Shade"
    case buttonShadow      = "Button/Shadow"
    case buttonTextShadow  = "Button/TextShadow"

    // Предупреждение при расстановке (`WarningLine`, спека 2.16): строка текста
    // со значком, без фона и рамки — с ними она читается как кнопка.
    case warnIcon = "Warn/Icon"
    case warnText = "Warn/Text"

    // Затемнение под модальным окном G3 (раунд 5, спека 2.17)
    case overlayScrim = "Overlay/Scrim"

    var color: Color { Color(rawValue) }

    /// Первая часть пути: Sea · Role · Chrome · Glass · Ink · Cell · Board ·
    /// Button · Warn.
    var group: String { String(rawValue.prefix(while: { $0 != "/" })) }

    /// Имя без группы — подпись в галерее.
    var shortName: String { String(rawValue.drop(while: { $0 != "/" }).dropFirst()) }

    /// Токены по группам, в том же порядке, в каком объявлены.
    static var groups: [(name: String, tokens: [ColorToken])] {
        var order: [String] = []
        var byGroup: [String: [ColorToken]] = [:]
        for token in allCases {
            if byGroup[token.group] == nil { order.append(token.group) }
            byGroup[token.group, default: []].append(token)
        }
        return order.map { ($0, byGroup[$0] ?? []) }
    }
}

// MARK: - Заливки панелей

extension LinearGradient {
    /// G2 — все обычные панели. Градиент в обеих темах: в тёмной точки равны,
    /// поэтому заливка выглядит ровной. Ветки по теме здесь запрещены.
    static var glassPanelFill: LinearGradient {
        LinearGradient(colors: [.glassFill, .glassFill2],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// G3 — приподнятый слой: листы, поповеры, окошки выбора.
    static var glassRaisedFill: LinearGradient {
        LinearGradient(colors: [.glassRaisedFill, .glassRaisedFill2],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Латунная подложка главной кнопки.
    static var buttonBrass: LinearGradient {
        LinearGradient(colors: [.buttonBrassTop, .buttonBrassBottom],
                       startPoint: .top, endPoint: .bottom)
    }

    /// Вода клетки — строго сверху вниз, как `cellStart` / `cellEnd` у корпуса.
    /// В макетах 160° (а в пакете `waterCell` ещё круче), но под вертикальным
    /// бевелем косая заливка делала клетку на вид повёрнутой (05.10).
    static let waterCellCSS = LinearGradient(
        colors: [.waterTop, .waterBottom],
        startPoint: .top, endPoint: .bottom)
}

// MARK: - Reduce Motion

extension Animation {
    /// Та же анимация вдвое быстрее при Reduce Motion — `Motion.scaled` для
    /// готовых анимаций, у которых длительность снаружи не видна. Задержка
    /// тоже сокращается вдвое. Перемещение и масштаб этим не убираются: их
    /// заменяют прозрачностью на месте.
    func reduced(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? speed(2) : self
    }
}

// MARK: - Dynamic Type

extension Font {
    /// Кегль макета, который растёт с Dynamic Type. При стандартном размере
    /// текста — ровно `size`, как в макете; крупнее — по кривой системного
    /// стиля с ближайшим базовым кеглем (`DynamicTypeAnchor`): мелкая подпись
    /// растёт заметнее, крупный заголовок — сдержаннее, как у системы.
    ///
    /// `Font.scaled(by:)` есть только с iOS 26. На iOS 18–25 — сам опорный
    /// стиль: текст растёт и там, а при стандартном размере кегль отходит от
    /// макета на 1–2 pt (24 → 22, 30 → 28). Доступность на старых системах
    /// важнее точности до пункта. Где текст расти не должен (поле, счёт боя,
    /// значки в рамках) — по-прежнему `.system(size:)`.
    static func scalable(size: CGFloat, weight: Font.Weight? = nil,
                         design: Font.Design? = nil) -> Font {
        let anchor = DynamicTypeAnchor.nearest(to: size)
        let font = Font.system(anchor.style, design: design, weight: weight)
        if #available(iOS 26.0, *) {
            return font.scaled(by: size / anchor.baseSize)
        }
        return font
    }
}

/// Значок в квадратной рамке, который растёт вместе с текстом строки: при
/// стандартном размере — ровно `box` из макета, крупнее — по кривой `body`,
/// но не больше чем вдвое (на AX5 тот бы вырос втрое и спорил с текстом).
/// Для значков в рамках с фиксированной геометрией (поле, плитки iPad) — нет.
struct ScaledSymbol: View {
    let name: String
    let box: CGFloat
    /// Квадрат, по которому считается кегль символа, если он меньше рамки
    /// (значок на плашке: рамка 38, символ как в 22).
    var glyphBox: CGFloat?
    var weight: Font.Weight?

    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    static let maxScale: CGFloat = 2

    var body: some View {
        let factor = min(scale, Self.maxScale)
        Image(systemName: name)
            .font(.system(size: symbolFontSize(inBox: (glyphBox ?? box) * factor), weight: weight))
            .frame(width: box * factor, height: box * factor)
    }
}

/// Ряд «текст · хвост» (значение, тумблер, цифры). На размерах AX1–AX5 —
/// столбец по левому краю: сбоку от хвоста текст сжимался в колонку в пару
/// слов на строку.
struct AdaptiveRow<Content: View>: View {
    var spacing: CGFloat
    var accessibilitySpacing: CGFloat = 6
    @ViewBuilder var content: Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: accessibilitySpacing))
            : AnyLayout(HStackLayout(spacing: spacing))
        layout { content }
    }
}

extension View {
    /// Потолок Dynamic Type на экранах партии (поле, расстановка, бой — во
    /// всех режимах). Геометрия там задана полем 10 × 10, кегли поля и
    /// панели счёта фиксированы, а у кнопок и предупреждений выше xxxLarge
    /// растёт только то, что отнимает место у поля. Элементы фиксированного
    /// размера на этих экранах показывают Large Content Viewer.
    /// Итоги и окна поверх партии в потолок не входят — ставить **под**
    /// `.matchResults` и `.modalDialog`.
    func battleTypeSize() -> some View {
        dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

/// Системный стиль и его кегль при стандартном размере текста (Large).
/// `headline` нет намеренно: он жирный сам по себе, а вес задаёт макет.
struct DynamicTypeAnchor: Equatable {
    let style: Font.TextStyle
    let baseSize: CGFloat

    static let all: [DynamicTypeAnchor] = [
        .init(style: .caption2, baseSize: 11),
        .init(style: .caption, baseSize: 12),
        .init(style: .footnote, baseSize: 13),
        .init(style: .subheadline, baseSize: 15),
        .init(style: .callout, baseSize: 16),
        .init(style: .body, baseSize: 17),
        .init(style: .title3, baseSize: 20),
        .init(style: .title2, baseSize: 22),
        .init(style: .title, baseSize: 28),
        .init(style: .largeTitle, baseSize: 34),
    ]

    /// Ближайший по отношению кеглей, а не по разности: 11 → 12 — это
    /// столько же, сколько 31 → 34.
    static func nearest(to size: CGFloat) -> DynamicTypeAnchor {
        all.min { abs(log($0.baseSize / size)) < abs(log($1.baseSize / size)) } ?? all[5]
    }
}

// MARK: - Два размера iPhone

extension Geometry.SizeClass {
    /// Часть токенов принимает **флаг** компактности, а не сам размер
    /// (`TypeScale.gameTitle(compact:)`), поэтому нужен обратный вопрос: какой
    /// из двух размеров перед нами. Отдельного признака в таблице пакета нет, а
    /// синтез `==` вне файла объявления Swift не делает, поэтому сравнивается
    /// одно значение из таблицы — сторона фотографии, 252 против 170. Оно
    /// годится как признак: размеров ровно два и оба заданы литералами.
    var isCompact: Bool { photo == Self.compact.photo }
}

// MARK: - Геометрия, считаемая от размера

extension Geometry {
    /// Радиус клетки — 26 % её размера. Минимум 4 pt: на 28 pt скругление
    /// иначе вырождается в квадрат.
    static func cellRadius(for size: CGFloat) -> CGFloat {
        max(4, (size * cellRadiusRatio).rounded())
    }
}

// MARK: - Значок баллов

/// Один значок баллов на всю игру — панель счёта, итоги, кошелёк (спека 2.5,
/// раунд 6, В19). Одной константой, потому что в макетах их было два и они
/// уже однажды разошлись: шестигранники при 16–19 pt сливаются в пятно.
enum PointsSymbol {
    static let name = "star.circle"
}

// MARK: - Семейство форм

extension Geometry {
    /// Семейство форм. До 05.10 радиус задавался по месту, и скруглённость
    /// прыгала от капсулы до почти прямоугольника: панель «Меню» 44 / 20
    /// соседствовала с переключателем полей 56 / 18 (замечание заказчика
    /// 05.10). Решение 06.10: на iPhone всё, что нажимается, — капсула, как в
    /// iOS 26; iPad пока на прежних радиусах (`legacy`).
    enum ShapeFamily: Sendable {
        /// Радиус по месту, как до 05.10, — iPad.
        case legacy
        /// Всё, что нажимается, — капсула; карточки с содержимым — 22. iPhone.
        case capsule

        /// Капсула через радиус: `RoundedRectangle` сам урезает его до
        /// половины меньшей стороны.
        static let pill: CGFloat = 1000

        /// `legacy` — радиус, который стоит на этом месте у iPad.
        func radius(_ role: ShapeRole, legacy: CGFloat) -> CGFloat {
            switch self {
            case .legacy: legacy
            case .capsule:
                switch role {
                case .control, .inner, .chip, .dock: Self.pill
                case .card: 22
                }
            }
        }
    }

    /// Роль формы. `control` — то, что нажимается одной строкой: кнопки,
    /// строки меню, таб-бар, переключатель, подсказка. `inner` — выбранный
    /// сегмент внутри обоймы. `card` — панель с содержимым: табло, заметки.
    /// `chip` — метки состояния. `dock` — нижняя панель, внутри которой стоят
    /// контролы (`BottomChrome.dock`).
    enum ShapeRole: Sendable {
        case control, inner, card, chip, dock
    }

    /// Низ экранов партии. До 06.10 «Меню» занимало отдельную строку во всю
    /// ширину ради одной кнопки, а таб-бар меню был шире строк режимов
    /// (замечание заказчика 06.10).
    enum BottomChrome: Sendable {
        /// Строка «Меню» во всю ширину под действиями (`NavRow`) — iPad.
        case legacy
        /// iPhone: последний ряд лежит в стеклянной панели на месте и в
        /// размер таб-бара, «Меню» в ней — круглой кнопкой-значком.
        case dock
    }

    enum Bottom {
        /// Одна высота у всего, что стоит внизу: главная, второстепенная,
        /// переключатель полей, подсказка, кнопка меню.
        static let controlHeight: CGFloat = 50
        /// Поле дока вокруг контролов: 50 + 2 × 9 = 68 — высота таб-бара.
        static let dockPadding: CGFloat = 9
        /// Док и таб-бар одной высоты на любом iPhone: переход из меню в
        /// партию не двигает низ экрана.
        static let dockHeight: CGFloat = controlHeight + 2 * dockPadding
    }
}

extension EnvironmentValues {
    /// Какое семейство форм рисуют контролы (`Geometry.ShapeFamily`). По
    /// умолчанию — iPhone, поэтому превью экранов показывают его; iPad ставит
    /// `legacy` через `phoneStyle(_:)`.
    @Entry var shapeFamily: Geometry.ShapeFamily = .capsule
    /// Как устроен низ экранов партии (`Geometry.BottomChrome`).
    @Entry var bottomChrome: Geometry.BottomChrome = .dock
}

extension View {
    /// Стиль iPhone, выбранный заказчиком 06.10: низ — док, формы — капсулы.
    /// iPad пока остаётся на прежнем (`legacy`): у него свой подход к низу.
    func phoneStyle(_ isPad: Bool) -> some View {
        environment(\.shapeFamily, isPad ? .legacy : .capsule)
            .environment(\.bottomChrome, isPad ? .legacy : .dock)
    }
}
