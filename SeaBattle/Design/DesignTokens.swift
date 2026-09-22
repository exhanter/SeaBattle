//
//  DesignTokens.swift
//  Sea Battle — дизайн-система «Стекло и латунь»
//
//  Единственный источник значений для интерфейса. Правило реализации:
//  цвет живёт в Colors.xcassets с вариантами Any/Dark (альфа входит в цвет),
//  в коде нет ни одной проверки `colorScheme`. Геометрия и длительности —
//  здесь, литералами.
//
//  Требуется: iOS 18+. Нормы iOS 26 Liquid Glass — база, ниже фолбэк
//  на системные материалы (см. Material.glassPanel).
//
//  Источник значений: docs/design/SPEC.md (таблица 15b) и исходник макетов
//  docs/design/mockups.html. В `ColorToken` у каждой группы помечено, откуда
//  взяты числа: «15b» — утверждённая таблица, «макеты» — значения, которые в
//  таблицу не попали и вынуты из кода макета (вариант огня P4, корпус K2).
//

import SwiftUI

// MARK: - Цвет

/// Каждый токен — путь внутри `Colors.xcassets`. Перечисление существует,
/// чтобы галерея показывала все цвета до единого, а тест проверял, что каждый
/// из них есть в каталоге: опечатка в имени ассета иначе молчит до рантайма.
enum ColorToken: String, CaseIterable, Sendable {

    // Море: единственный фон приложения (15b).
    case seaTop    = "Sea/Top"
    case seaMid    = "Sea/Mid"
    case seaBottom = "Sea/Bottom"

    // Роли: тёплый акцент — всегда «ты», холодный — всегда противник (15b).
    case roleYou     = "Role/You"
    case roleFoe     = "Role/Foe"
    case roleYouSoft = "Role/YouSoft"

    // Хром (15b).
    case wood = "Chrome/Wood"
    case fire = "Chrome/Fire"

    // Стекло G2 — все обычные панели (15b; тень — макеты).
    case glassFill   = "Glass/Fill"
    case glassFill2  = "Glass/Fill2"
    case glassStroke = "Glass/Stroke"
    case glassSheen  = "Glass/Sheen"
    case glassShadow = "Glass/Shadow"

    // Стекло G1 — глухие слои: передача устройства, шторки (15b; обводка — макеты).
    case glassSolid       = "Glass/Solid"
    case glassSolidStroke = "Glass/SolidStroke"

    // Стекло G3 — листы, поповеры, окошки выбора (макеты).
    case glassRaisedFill   = "Glass/RaisedFill"
    case glassRaisedFill2  = "Glass/RaisedFill2"
    case glassRaisedStroke = "Glass/RaisedStroke"
    case glassRaisedSheen  = "Glass/RaisedSheen"
    case glassRaisedShadow = "Glass/RaisedShadow"

    // Краска на стекле: в обеих темах панели тёмные, поэтому набор текста один (15b).
    case inkPrimary   = "Ink/Primary"
    case inkSecondary = "Ink/Secondary"
    case inkTertiary  = "Ink/Tertiary"
    case inkOnBrass   = "Ink/OnBrass"

    // Клетка · вода W1 / L2 (15b).
    case waterTop    = "Cell/WaterTop"
    case waterBottom = "Cell/WaterBottom"
    case waterSheen  = "Cell/WaterSheen"
    case waterShade  = "Cell/WaterShade"

    // Клетка · корпус K2 «Песок» — свой корабль (15b).
    case hullSandLight = "Cell/HullSandLight"
    case hullSand      = "Cell/HullSand"
    case hullSandDark  = "Cell/HullSandDark"

    // Клетка · холодный корпус — чужой флот в разборе партии (макеты).
    case hullFoeLight = "Cell/HullFoeLight"
    case hullFoe      = "Cell/HullFoe"
    case hullFoeDark  = "Cell/HullFoeDark"

    // Клетка · запрещённая позиция при расстановке (15b).
    case hullDeniedLight = "Cell/HullDeniedLight"
    case hullDenied      = "Cell/HullDenied"
    case hullDeniedDark  = "Cell/HullDeniedDark"

    // Клетка · бевель корпуса и белый крест поверх него (макеты).
    case hullSheen = "Cell/HullSheen"
    case hullShade = "Cell/HullShade"
    case hullCross = "Cell/HullCross"

    // Клетка · промах M1 «воронка» (15b).
    case missPit = "Cell/MissPit"
    case missRim = "Cell/MissRim"

    // Клетка · пробоина F4 на поле противника (свечение и крест — 15b,
    // четыре кромки, внутренние свечения и обводка креста — макеты, вариант P4).
    case fireHalo       = "Cell/FireHalo"
    case fireEdgeTop    = "Cell/FireEdgeTop"
    case fireEdgeLeft   = "Cell/FireEdgeLeft"
    case fireEdgeRight  = "Cell/FireEdgeRight"
    case fireEdgeBottom = "Cell/FireEdgeBottom"
    case fireEdgeSheen  = "Cell/FireEdgeSheen"
    case fireEdgeShade  = "Cell/FireEdgeShade"
    case fireGlowIn     = "Cell/FireGlowIn"
    case fireGlowOut    = "Cell/FireGlowOut"
    case fireDarken     = "Cell/FireDarken"
    case fireCross      = "Cell/FireCross"
    case fireCrossEdge  = "Cell/FireCrossEdge"
    case fireCrossHalo  = "Cell/FireCrossHalo"

    // Клетка · огонь F1 поверх своего корпуса: три слоя тинта (макеты).
    // В обеих темах одинаковы — под ними всегда песочный корпус, а не море.
    case fireTintTop     = "Cell/FireTintTop"
    case fireTintBottom  = "Cell/FireTintBottom"
    case fireSatTop      = "Cell/FireSatTop"
    case fireSatBottom   = "Cell/FireSatBottom"
    case fireWarmIn      = "Cell/FireWarmIn"
    case fireWarmOut     = "Cell/FireWarmOut"
    case fireCrossShadow = "Cell/FireCrossShadow"

    // Клетка · уничтожен S4 «выгоревшая сталь» (рампа — 15b, остальное — макеты).
    case steelTop      = "Cell/SteelTop"
    case steelMid      = "Cell/SteelMid"
    case steelBottom   = "Cell/SteelBottom"
    case steelSheen    = "Cell/SteelSheen"
    case steelShade    = "Cell/SteelShade"
    case sunkCross     = "Cell/SunkCross"
    case sunkCrossEdge = "Cell/SunkCrossEdge"

    var color: Color { Color(rawValue) }

    /// Первая часть пути: Sea · Role · Chrome · Glass · Ink · Cell.
    var group: String { String(rawValue.prefix(while: { $0 != "/" })) }

    /// Имя без группы — подпись в галерее.
    var shortName: String { String(rawValue.drop(while: { $0 != "/" }).dropFirst()) }
}

extension Color {

    // Море
    static let seaTop    = ColorToken.seaTop.color
    static let seaMid    = ColorToken.seaMid.color
    static let seaBottom = ColorToken.seaBottom.color

    // Роли
    static let roleYou     = ColorToken.roleYou.color
    static let roleFoe     = ColorToken.roleFoe.color
    static let roleYouSoft = ColorToken.roleYouSoft.color

    // Хром
    static let wood = ColorToken.wood.color
    static let fire = ColorToken.fire.color

    // Стекло
    static let glassFill         = ColorToken.glassFill.color
    static let glassFill2        = ColorToken.glassFill2.color
    static let glassStroke       = ColorToken.glassStroke.color
    static let glassSheen        = ColorToken.glassSheen.color
    static let glassShadow       = ColorToken.glassShadow.color
    static let glassSolid        = ColorToken.glassSolid.color
    static let glassSolidStroke  = ColorToken.glassSolidStroke.color
    static let glassRaisedFill   = ColorToken.glassRaisedFill.color
    static let glassRaisedFill2  = ColorToken.glassRaisedFill2.color
    static let glassRaisedStroke = ColorToken.glassRaisedStroke.color
    static let glassRaisedSheen  = ColorToken.glassRaisedSheen.color
    static let glassRaisedShadow = ColorToken.glassRaisedShadow.color

    // Краска
    static let inkPrimary   = ColorToken.inkPrimary.color
    static let inkSecondary = ColorToken.inkSecondary.color
    static let inkTertiary  = ColorToken.inkTertiary.color
    static let inkOnBrass   = ColorToken.inkOnBrass.color

    // Клетка · вода
    static let waterTop    = ColorToken.waterTop.color
    static let waterBottom = ColorToken.waterBottom.color
    static let waterSheen  = ColorToken.waterSheen.color
    static let waterShade  = ColorToken.waterShade.color

    // Клетка · корпус
    static let hullSandLight   = ColorToken.hullSandLight.color
    static let hullSand        = ColorToken.hullSand.color
    static let hullSandDark    = ColorToken.hullSandDark.color
    static let hullFoeLight    = ColorToken.hullFoeLight.color
    static let hullFoe         = ColorToken.hullFoe.color
    static let hullFoeDark     = ColorToken.hullFoeDark.color
    static let hullDeniedLight = ColorToken.hullDeniedLight.color
    static let hullDenied      = ColorToken.hullDenied.color
    static let hullDeniedDark  = ColorToken.hullDeniedDark.color
    static let hullSheen       = ColorToken.hullSheen.color
    static let hullShade       = ColorToken.hullShade.color
    static let hullCross       = ColorToken.hullCross.color

    // Клетка · промах
    static let missPit = ColorToken.missPit.color
    static let missRim = ColorToken.missRim.color

    // Клетка · огонь
    static let fireHalo       = ColorToken.fireHalo.color
    static let fireEdgeTop    = ColorToken.fireEdgeTop.color
    static let fireEdgeLeft   = ColorToken.fireEdgeLeft.color
    static let fireEdgeRight  = ColorToken.fireEdgeRight.color
    static let fireEdgeBottom = ColorToken.fireEdgeBottom.color
    static let fireEdgeSheen  = ColorToken.fireEdgeSheen.color
    static let fireEdgeShade  = ColorToken.fireEdgeShade.color
    static let fireGlowIn     = ColorToken.fireGlowIn.color
    static let fireGlowOut    = ColorToken.fireGlowOut.color
    static let fireDarken     = ColorToken.fireDarken.color
    static let fireCross      = ColorToken.fireCross.color
    static let fireCrossEdge  = ColorToken.fireCrossEdge.color
    static let fireCrossHalo  = ColorToken.fireCrossHalo.color

    static let fireTintTop     = ColorToken.fireTintTop.color
    static let fireTintBottom  = ColorToken.fireTintBottom.color
    static let fireSatTop      = ColorToken.fireSatTop.color
    static let fireSatBottom   = ColorToken.fireSatBottom.color
    static let fireWarmIn      = ColorToken.fireWarmIn.color
    static let fireWarmOut     = ColorToken.fireWarmOut.color
    static let fireCrossShadow = ColorToken.fireCrossShadow.color

    // Клетка · уничтожен
    static let steelTop      = ColorToken.steelTop.color
    static let steelMid      = ColorToken.steelMid.color
    static let steelBottom   = ColorToken.steelBottom.color
    static let steelSheen    = ColorToken.steelSheen.color
    static let steelShade    = ColorToken.steelShade.color
    static let sunkCross     = ColorToken.sunkCross.color
    static let sunkCrossEdge = ColorToken.sunkCrossEdge.color
}

// MARK: - Градиенты

extension LinearGradient {

    /// Фон всего приложения. Дышит 18 с (см. Motion.breathe), рисунка волн нет.
    /// Середина стоит на 46 % в обеих темах: в макете у светлой она на 48 %,
    /// но разницу в 2 % не видно, а зависимость от темы стоила бы проверки
    /// `colorScheme` в коде — она запрещена правилом дизайна.
    static var sea: LinearGradient {
        LinearGradient(stops: [.init(color: .seaTop, location: 0),
                               .init(color: .seaMid, location: 0.46),
                               .init(color: .seaBottom, location: 1)],
                       startPoint: .top, endPoint: .bottom)
    }

    /// Вода в клетке: диагональ 160°, как в макете.
    static var waterCell: LinearGradient {
        LinearGradient(colors: [.waterTop, .waterBottom],
                       startPoint: .init(x: 0.15, y: 0), endPoint: .init(x: 0.85, y: 1))
    }

    /// Корпус своего корабля K2 «Песок».
    static var hullSand: LinearGradient { hullRamp(.hullSandLight, .hullSand, .hullSandDark) }

    /// Холодный корпус — чужой флот, показывается только в разборе партии.
    static var hullFoe: LinearGradient { hullRamp(.hullFoeLight, .hullFoe, .hullFoeDark) }

    /// Корабль в запрещённой позиции: в руке — с прозрачностью 0.62, после
    /// отпускания плотный. Геометрия та же, что у hullSand.
    static var hullDenied: LinearGradient { hullRamp(.hullDeniedLight, .hullDenied, .hullDeniedDark) }

    /// Уничтоженный корпус S4 «Выгоревшая сталь».
    static var steelSunk: LinearGradient { hullRamp(.steelTop, .steelMid, .steelBottom, mid: 0.45) }

    /// Заливка панели G2 и приподнятого слоя G3 — две точки по диагонали 135°.
    static var glassPanelFill: LinearGradient {
        LinearGradient(colors: [.glassFill, .glassFill2],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var glassRaisedPanelFill: LinearGradient {
        LinearGradient(colors: [.glassRaisedFill, .glassRaisedFill2],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Все корпуса собраны одной рампой: три точки, середина на 46 %.
    private static func hullRamp(_ light: Color, _ base: Color, _ dark: Color,
                                 mid: CGFloat = 0.46) -> LinearGradient {
        LinearGradient(stops: [.init(color: light, location: 0),
                               .init(color: base, location: mid),
                               .init(color: dark, location: 1)],
                       startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - Геометрия

enum Geometry {
    /// Радиус клетки — доля её размера, а не константа.
    static let cellRadiusRatio: CGFloat = 0.26
    /// Радиус рамки поля = радиус клетки + отступ рамки.
    static let boardInset: CGFloat = 6

    enum Cell {
        static let iPhone: CGFloat = 32          // 393 pt, без координат
        static let iPhoneCoords: CGFloat = 30    // 393 pt, обвязка B2
        static let iPhoneSmall: CGFloat = 30     // 375 pt
        static let iPhoneSmallCoords: CGFloat = 28
        static let iPadPortrait: CGFloat = 42
        static let iPadLandscape: CGFloat = 44
        static let iPadPlacement: CGFloat = 46
        static let iPadTable: CGFloat = 40       // стол на два поля
        static let gapPhone: CGFloat = 3
        static let gapPad: CGFloat = 4
    }

    enum Radius {
        static let panel: CGFloat = 22
        static let panelLarge: CGFloat = 26
        static let button: CGFloat = 18
        static let segment: CGFloat = 14
        static let chip: CGFloat = 12
        static let sheet: CGFloat = 38
    }

    enum Inset {
        static let phoneSide: CGFloat = 12
        static let padFrame: CGFloat = 24        // одна рамка от всех четырёх краёв
        static let boardGapPad: CGFloat = 34     // между полями в горизонтали
        static let railWidth: CGFloat = 104      // вертикальный iPad
        static let feedWidthPortrait: CGFloat = 128
        static let feedWidthLandscape: CGFloat = 124
        static let hintHeightLandscape: CGFloat = 68  // по высоте нижней панели
    }

    enum Hit {
        static let minTarget: CGFloat = 44       // всё, кроме клетки поля
    }

    /// Кант между стеклом панели и морем: верх нижней панели, низ верхней.
    static let woodEdge: CGFloat = 2

    /// Радиус клетки от её размера. Минимум 4 pt, иначе на 28 pt скругление
    /// вырождается в квадрат.
    static func cellRadius(for size: CGFloat) -> CGFloat {
        max(4, (size * cellRadiusRatio).rounded())
    }
}

// MARK: - Материал

extension Material {
    /// G2 — основной материал панелей: blur 18, saturate 1.6.
    /// На iOS 18 подменяется на .ultraThinMaterial с той же раскладкой.
    static var glassPanel: Material { .ultraThinMaterial }
    /// G3 — приподнятый слой (листы, поповеры): blur 26, saturate 2.
    static var glassRaised: Material { .thinMaterial }
}

// MARK: - Типографика

enum TypeScale {
    static let display   = Font.system(size: 34, weight: .semibold, design: .rounded)
    static let title     = Font.system(size: 24, weight: .semibold, design: .rounded)
    static let headline  = Font.system(size: 17, weight: .semibold)
    static let body      = Font.system(size: 16, weight: .regular)
    static let callout   = Font.system(size: 15, weight: .regular)
    static let footnote  = Font.system(size: 13, weight: .regular)
    static let caption   = Font.system(size: 11, weight: .semibold)
    /// Координаты поля и числа счёта: моноширинные цифры, чтобы не дёргались.
    static let tally     = Font.system(size: 15, weight: .semibold).monospacedDigit()
}

// MARK: - Движение

enum Motion {
    // Клетка. В момент выстрела всплеск, смена состояния и подсветка
    // контура стартуют одновременно — отложенных фаз нет.
    static let splash: Double  = 0.240   // два расходящихся кольца
    static let stateSwap: Double = 0.260 // вода → воронка / огонь / сталь
    static let contourGlow: Double = 0.520
    static let aim: Double = 0.120
    static let sinkPerCell: Double = 0.060   // волна по корпусу, максимум 0.240
    static let missRing: Double = 0.200      // обводка потопленного промахами
    static let incomingShot: Double = 0.180
    static let feedChip: Double = 0.220
    static let tallyRoll: Double = 0.200     // число в шапке перекатывается
    static let aimContourFade: Double = 0.060 // латунный контур гаснет в момент выстрела

    // Экраны
    static let turnFade: Double = 0.160     // рамка гаснет
    static let turnRaise: Double = 0.240    // разгорается вторая
    static let toResults: Double = 0.600
    static let resultsFill: Double = 0.320
    static let pointsCounter: Double = 0.500
    static let handoverIn: Double = 0.260
    static let handoverOut: Double = 0.180

    // Бесконечны ровно два движения
    static let breathe: Double = 18.0       // дыхание фона
    static let jiggleRange: ClosedRange<Double> = 0.40...0.51 // дрожание клеток
    static let jiggleAngle: Double = 1.4    // градусы, ±
    static let jigglePhase: ClosedRange<Double> = 0...0.24

    static let standard = Animation.easeInOut(duration: stateSwap)
    static let quick = Animation.easeOut(duration: aim)

    /// Reduce Motion: перемещения и масштаб → прозрачность, длительности × 0,5,
    /// дыхание фона и дрожание выключены. Состояния клеток не меняются.
    static func scaled(_ d: Double, reduceMotion: Bool) -> Double {
        reduceMotion ? d * 0.5 : d
    }
}

// MARK: - Правила, которые нельзя выразить значением

/*
 1. Анимации не копятся: новое действие обрывает предыдущее и ставит конечное
    состояние. Очереди нет.
 2. Свечение рамки горит на поле, по которому сейчас стреляют.
 3. Цвет кольца и подсветки закреплён за полем: свои клетки — латунь,
    клетки противника — огонь. Белого в палитре нет.
 4. Латунный контур («выстрел назван, ждём ответ») гаснет в момент выстрела
    за 60 мс и в анимации не участвует.
 5. Верхняя панель показывает и не нажимается. Всё нажимаемое — внизу.
 6. Главная кнопка одна на всю игру: стекло с бевелем, латунный кант 1 pt,
    латунная подложка, белая надпись. Плоских заливок без бевеля нет.
 7. Передача устройства — не sheet, а непрозрачный слой в том же контейнере.
 */
