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
//  - `Geometry.cellRadius(for:)` — радиус клетки от её размера.
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
