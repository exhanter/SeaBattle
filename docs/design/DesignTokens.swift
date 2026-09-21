//
//  DesignTokens.swift
//  Sea Battle — дизайн-система «Стекло и латунь»
//
//  Единственный источник значений для интерфейса. Правило реализации:
//  цвет живёт в ассет-каталоге с вариантами Any/Dark (альфа входит в цвет),
//  в коде нет ни одной проверки `colorScheme`. Геометрия и длительности —
//  здесь, литералами.
//
//  Требуется: iOS 18+. Нормы iOS 26 Liquid Glass — база, ниже фолбэк
//  на системные материалы (см. Material.glassPanel).
//

import SwiftUI

// MARK: - Цвет

/// Имена соответствуют папкам и ассетам в Colors.xcassets.
/// Каждый ассет содержит Any Appearance (светлая тема) и Dark Appearance.
extension Color {

    // Море: единственный фон приложения. Один LinearGradient на всю игру.
    static let seaTop    = Color("Sea/Top")     // dark #061729 · light #1F5474
    static let seaMid    = Color("Sea/Mid")     // dark #0D3450 · light #2E7A92
    static let seaBottom = Color("Sea/Bottom")  // dark #12566B · light #45A3A8

    // Роли. Тёплый акцент — всегда «ты», холодный — всегда противник,
    // одинаково у всех игроков и во всех режимах.
    static let roleYou     = Color("Role/You")      // #D19A3C — латунь
    static let roleFoe     = Color("Role/Foe")      // #3C7FBF — лазурь
    static let roleYouSoft = Color("Role/YouSoft")  // rgba(209,154,60,.22) — подложка ленты

    // Хром
    static let wood = Color("Chrome/Wood")   // #6B4A2F — кант 2 pt и мат вокруг фото
    static let fire = Color("Chrome/Fire")   // #FF7A2F — огонь как состояние, не как хром

    // Стекло
    static let glassFill   = Color("Glass/Fill")   // dark rgba(255,255,255,.14) · light rgba(5,30,48,.60)
    static let glassFill2  = Color("Glass/Fill2")  // вторая точка градиента G2/G3
    static let glassStroke = Color("Glass/Stroke") // dark rgba(255,255,255,.24) · light rgba(255,255,255,.40)
    static let glassSheen  = Color("Glass/Sheen")  // блик по верхней кромке
    static let glassSolid  = Color("Glass/Solid")  // G1: dark rgba(8,24,42,.80) · light rgba(5,30,48,.86)

    // Краска на стекле: в обеих темах панели тёмные, поэтому набор текста один.
    static let inkPrimary   = Color("Ink/Primary")    // rgba(255,255,255,.96)
    static let inkSecondary = Color("Ink/Secondary")  // rgba(255,255,255,.72)
    static let inkTertiary  = Color("Ink/Tertiary")   // rgba(255,255,255,.52)
    static let inkOnBrass   = Color("Ink/OnBrass")    // #0A1A2C — надпись на латунной подложке

    // Клетка · вода W1 / L2
    static let waterTop    = Color("Cell/WaterTop")    // dark rgba(255,255,255,.26) · light #D3E2EF
    static let waterBottom = Color("Cell/WaterBottom") // dark rgba(255,255,255,.07) · light #8FB0CD
    static let waterSheen  = Color("Cell/WaterSheen")  // inset верх: dark .45 · light .95
    static let waterShade  = Color("Cell/WaterShade")  // inset низ: rgba(0,20,40,.35) · rgba(18,42,72,.40)

    // Клетка · корпус K2 «Песок» (свой) и холодный корпус (чужой, только в разборе)
    static let hullSandLight = Color("Cell/HullSandLight") // #F8E9CD
    static let hullSand      = Color("Cell/HullSand")      // #E0C48F
    static let hullSandDark  = Color("Cell/HullSandDark")  // #A68A5B
    static let hullFoeLight  = Color("Cell/HullFoeLight")  // #A8CDEA
    static let hullFoe       = Color("Cell/HullFoe")       // #3C7FBF
    static let hullFoeDark   = Color("Cell/HullFoeDark")   // #22527E

    // Клетка · промах M1 «воронка»
    static let missPit = Color("Cell/MissPit") // dark rgba(0,18,34,.85) · light rgba(20,45,72,.60)
    static let missRim = Color("Cell/MissRim") // подсвеченная нижняя кромка

    // Клетка · огонь. F4 на поле противника, F1 поверх своего корпуса.
    static let fireHalo      = Color("Cell/FireHalo")      // dark #A9552C · light #FF8A00 (P4)
    static let fireEdgeTop   = Color("Cell/FireEdgeTop")   // light #FFC428
    static let fireEdgeBot   = Color("Cell/FireEdgeBottom")// light #BC2A00
    static let fireGlowIn    = Color("Cell/FireGlowIn")
    static let fireGlowOut   = Color("Cell/FireGlowOut")
    static let fireCross     = Color("Cell/FireCross")     // dark #FFF8EC · light #FF5212
    static let fireCrossEdge = Color("Cell/FireCrossEdge") // обводка креста

    // Клетка · уничтожен S4 «выгоревшая сталь»
    static let steelTop    = Color("Cell/SteelTop")    // #4A555F
    static let steelMid    = Color("Cell/SteelMid")    // #28313A
    static let steelBottom = Color("Cell/SteelBottom") // #10161C

    // Запрет при расстановке: та же рампа, что у корпуса, в розовом
    static let hullDeniedLight = Color("Cell/HullDeniedLight") // #FFD5D5
    static let hullDenied      = Color("Cell/HullDenied")      // #F0A3A3
    static let hullDeniedDark  = Color("Cell/HullDeniedDark")  // #C97B7B
}

extension LinearGradient {
    /// Фон всего приложения. Дышит 18 с (см. Motion.breathe), рисунка волн нет.
    static let sea = LinearGradient(
        stops: [.init(color: .seaTop, location: 0),
                .init(color: .seaMid, location: 0.46),
                .init(color: .seaBottom, location: 1)],
        startPoint: .top, endPoint: .bottom)

    static let waterCell = LinearGradient(
        colors: [.waterTop, .waterBottom],
        startPoint: .init(x: 0.15, y: 0), endPoint: .init(x: 0.85, y: 1))

    static let hullSand = LinearGradient(
        stops: [.init(color: .hullSandLight, location: 0),
                .init(color: .hullSand, location: 0.46),
                .init(color: .hullSandDark, location: 1)],
        startPoint: .top, endPoint: .bottom)

    /// Корабль в запрещённой позиции: в руке — с прозрачностью 0.62, после
    /// отпускания плотный. Геометрия та же, что у hullSand.
    static let hullDenied = LinearGradient(
        stops: [.init(color: .hullDeniedLight, location: 0),
                .init(color: .hullDenied, location: 0.46),
                .init(color: .hullDeniedDark, location: 1)],
        startPoint: .top, endPoint: .bottom)

    static let steelSunk = LinearGradient(
        stops: [.init(color: .steelTop, location: 0),
                .init(color: .steelMid, location: 0.45),
                .init(color: .steelBottom, location: 1)],
        startPoint: .top, endPoint: .bottom)
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
    static let incomingShot: Double = 0.180
    static let feedChip: Double = 0.220

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
