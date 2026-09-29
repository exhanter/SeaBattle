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
    static let seaMid    = Color("Sea/Mid")     // dark #0D3450 · light #2E7A92 — 46 % в обеих темах
    static let seaBottom = Color("Sea/Bottom")  // dark #12566B · light #45A3A8
    /// Центр радиального свечения над градиентом. Единственный дышащий слой.
    static let seaGlow   = Color("Sea/Glow")    // dark rgba(120,220,220,.30) · light rgba(210,255,250,.34)

    // Роли. Тёплый акцент — всегда «ты», холодный — всегда противник,
    // одинаково у всех игроков и во всех режимах.
    static let roleYou     = Color("Role/You")      // #D19A3C — латунь
    static let roleFoe     = Color("Role/Foe")      // #3C7FBF — лазурь
    static let roleYouSoft = Color("Role/YouSoft")  // rgba(209,154,60,.22) — подложка ленты

    // Хром
    static let wood     = Color("Chrome/Wood")     // #6B4A2F — кант 2 pt (ровный) и верх мата
    static let woodDeep = Color("Chrome/WoodDeep") // #4D3521 — низ градиента мата; больше нигде
    static let fire = Color("Chrome/Fire")   // #FF7A2F — огонь как состояние, не как хром

    // Стекло. G2 — всегда градиент Fill → Fill2 под 135°; в тёмной теме точки равны,
    // поэтому заливка выглядит ровной. Геометрия одна, разные только значения.
    static let glassFill    = Color("Glass/Fill")    // dark rgba(255,255,255,.14) · light rgba(5,30,48,.60)
    static let glassFill2   = Color("Glass/Fill2")   // dark rgba(255,255,255,.14) · light rgba(5,30,48,.48)
    static let glassStroke  = Color("Glass/Stroke")  // dark rgba(255,255,255,.24) · light rgba(255,255,255,.40)
    static let glassSheen   = Color("Glass/Sheen")   // dark rgba(255,255,255,.32) · light rgba(255,255,255,.38)
    static let glassShadow  = Color("Glass/Shadow")  // dark rgba(0,0,0,.26) · light rgba(4,26,40,.26)

    // G3 — приподнятый слой. Свой набор: в тёмной теме заливка плотнее G2.
    static let glassRaisedFill   = Color("Glass/RaisedFill")   // dark rgba(255,255,255,.26) · light rgba(5,30,48,.72)
    static let glassRaisedFill2  = Color("Glass/RaisedFill2")  // dark rgba(255,255,255,.05) · light rgba(5,30,48,.56)
    static let glassRaisedStroke = Color("Glass/RaisedStroke") // dark rgba(255,255,255,.45) · light rgba(255,255,255,.50)
    static let glassRaisedSheen  = Color("Glass/RaisedSheen")  // dark rgba(255,255,255,.55) · light rgba(255,255,255,.40)
    static let glassRaisedShadow = Color("Glass/RaisedShadow") // dark rgba(0,0,0,.30) · light rgba(4,26,40,.30)

    // G1 — глухой слой: ни блюра, ни блика, ни тени.
    static let glassSolid       = Color("Glass/Solid")       // dark rgba(8,24,42,.80) · light rgba(5,30,48,.86)
    static let glassSolidStroke = Color("Glass/SolidStroke") // dark rgba(255,255,255,.10) · light rgba(255,255,255,.28)

    // Краска на стекле: в обеих темах панели тёмные, поэтому набор текста один.
    static let inkPrimary   = Color("Ink/Primary")    // rgba(255,255,255,.96)
    static let inkSecondary = Color("Ink/Secondary")  // rgba(255,255,255,.72)
    /// Тень заголовков экрана и подписей над полем, 0 1 5. В тёмной теме прозрачная —
    /// тень рисуется всегда, ветки по теме нет.
    static let inkTitleShadow = Color("Ink/TitleShadow") // dark rgba(0,0,0,0) · light rgba(4,26,40,.60)
    static let inkTertiary  = Color("Ink/Tertiary")   // rgba(255,255,255,.52)
    static let inkOnBrass   = Color("Ink/OnBrass")    // #0A1A2C — надпись на латунной подложке

    // Клетка · вода W1 / L2
    static let waterTop    = Color("Cell/WaterTop")    // dark rgba(255,255,255,.26) · light #D3E2EF
    static let waterBottom = Color("Cell/WaterBottom") // dark rgba(255,255,255,.07) · light #8FB0CD
    static let waterSheen  = Color("Cell/WaterSheen")  // inset верх: dark .45 · light .95
    static let waterShade  = Color("Cell/WaterShade")  // inset низ: rgba(0,20,40,.35) · rgba(18,42,72,.40)

    // Клетка · корпус K2 «Песок». Холодного корпуса в токенах нет: он нужен только
    // для разбора партии, а разбор отложен до будущих обновлений.
    static let hullSandLight = Color("Cell/HullSandLight") // #F8E9CD
    static let hullSand      = Color("Cell/HullSand")      // #E0C48F
    static let hullSandDark  = Color("Cell/HullSandDark")  // #A68A5B
    static let hullSheen     = Color("Cell/HullSheen")     // rgba(255,255,255,.60) — бевель сверху
    static let hullShade     = Color("Cell/HullShade")     // rgba(0,0,0,.32) — бевель снизу

    // Клетка · промах M1 «воронка»
    static let missPit = Color("Cell/MissPit") // dark rgba(0,18,34,.85) · light rgba(20,45,72,.60)
    static let missRim = Color("Cell/MissRim") // подсвеченная нижняя кромка

    // Клетка · огонь. F4 на поле противника: кромок четыре, разного тона — они
    // изображают объём пробоины: свет сверху, тень снизу-справа.
    static let fireHalo       = Color("Cell/FireHalo")       // dark #A9552C 42 % · light #FF8A00 70 % (P4)
    static let fireEdgeTop    = Color("Cell/FireEdgeTop")    // dark rgba(214,150,114,.85) · light rgba(255,196,40,1)
    static let fireEdgeLeft   = Color("Cell/FireEdgeLeft")   // dark rgba(198,132,92,.80) · light rgba(255,140,10,1)
    static let fireEdgeRight  = Color("Cell/FireEdgeRight")  // dark rgba(160,98,60,.80) · light rgba(224,70,0,1)
    static let fireEdgeBottom = Color("Cell/FireEdgeBottom") // dark rgba(135,80,48,.85) · light rgba(188,42,0,1)
    static let fireEdgeHi     = Color("Cell/FireEdgeHi")     // dark rgba(255,195,145,.22) · light rgba(255,205,150,.32)
    static let fireEdgeShadow = Color("Cell/FireEdgeShadow") // dark rgba(90,26,0,.26) · light rgba(95,22,0,.30)
    static let fireGlowIn     = Color("Cell/FireGlowIn")     // dark rgba(255,110,25,.62) · light rgba(255,130,15,.68)
    static let fireGlowOut    = Color("Cell/FireGlowOut")    // dark rgba(255,150,45,.40) · light rgba(255,180,50,.45)
    static let fireDarken     = Color("Cell/FireDarken")     // dark прозрачный · light rgba(200,130,20,.10)
    /// В светлой теме крест и обводка меняются ролями: белый крест на светлом
    /// море потерялся бы. Геометрия и код одни, разные только значения ассетов.
    static let fireCross      = Color("Cell/FireCross")      // dark rgba(255,248,238,.92) · light rgba(255,82,18,1)
    static let fireCrossEdge  = Color("Cell/FireCrossEdge")  // dark rgba(198,74,10,.95) · light rgba(255,250,240,.95)

    // Клетка · F1, попадание по своему кораблю. Свой корпус всегда песочный,
    // поэтому и огонь поверх него один на обе темы. Режимы смешивания обязательны:
    // без них получается плоская оранжевая заливка, а не горящий корпус.
    static let hitTintMulTop    = Color("Cell/HitTintMulTop")    // rgba(255,140,15,.62)
    static let hitTintMulBottom = Color("Cell/HitTintMulBottom") // rgba(255,60,0,.70)
    static let hitTintScrTop    = Color("Cell/HitTintScrTop")    // rgba(255,120,0,.30)
    static let hitTintScrBottom = Color("Cell/HitTintScrBottom") // rgba(255,40,0,.28)
    static let hitWarmIn        = Color("Cell/HitWarmIn")        // rgba(255,190,70,.40)
    static let hitWarmOut       = Color("Cell/HitWarmOut")       // rgba(255,90,10,.18) на 68 %
    static let hitCross         = Color("Cell/HitCross")         // #FFF8EC — крест F1
    static let hitCrossShadow   = Color("Cell/HitCrossShadow")   // rgba(120,35,0,.85) — тень креста F1

    // Клетка · уничтожен S4 «выгоревшая сталь». Крест лежит на тёмной стали и в
    // обеих темах оранжевый — это не тот же токен, что крест пробоины.
    static let steelTop       = Color("Cell/SteelTop")       // #4A555F
    static let steelMid       = Color("Cell/SteelMid")       // #28313A
    static let steelBottom    = Color("Cell/SteelBottom")    // #10161C
    static let steelSheen     = Color("Cell/SteelSheen")     // rgba(255,255,255,.14) — бевель сверху
    static let steelShade     = Color("Cell/SteelShade")     // rgba(0,0,0,.60) — бевель снизу
    static let sunkCross      = Color("Cell/SunkCross")      // dark rgba(255,122,47,.95) · light rgba(255,110,30,.95)
    static let sunkCrossEdge  = Color("Cell/SunkCrossEdge")  // rgba(150,44,4,.90)

    // Запрет при расстановке: та же рампа, что у корпуса, в розовом
    static let hullDeniedLight = Color("Cell/HullDeniedLight") // #FFD5D5
    static let hullDenied      = Color("Cell/HullDenied")      // #F0A3A3
    static let hullDeniedDark  = Color("Cell/HullDeniedDark")  // #C97B7B

    // Подложка поля B1 — в цвете роли. Одна на обе темы. .opacity() от цветов ролей
    // в коде не применять: исключений из правила «альфа входит в цвет» нет.
    static let boardFillYou   = Color("Board/FillYou")   // rgba(209,154,60,.10)
    static let boardFillFoe   = Color("Board/FillFoe")   // rgba(60,127,191,.12)
    static let boardStrokeYou = Color("Board/StrokeYou") // rgba(209,154,60,.45) — 1 pt
    static let boardStrokeFoe = Color("Board/StrokeFoe") // rgba(60,127,191,.45) — 1 pt

    // Главная кнопка (PrimaryButton). Кант — Role/You, ореол — Role/YouSoft,
    // надпись — Ink/Primary. Одна на обе темы.
    static let buttonBrassTop    = Color("Button/BrassTop")    // dark rgba(209,154,60,.42) · light rgba(168,112,34,.95)
    static let buttonBrassBottom = Color("Button/BrassBottom") // dark rgba(209,154,60,.16) · light rgba(120,78,20,.92)
    static let buttonSheen       = Color("Button/Sheen")       // rgba(255,255,255,.55) — inset 0 1 0
    static let buttonShade       = Color("Button/Shade")       // rgba(0,0,0,.28) — inset 0 −2 6
    static let buttonShadow      = Color("Button/Shadow")      // rgba(0,0,0,.34) — 0 6 18
    static let buttonTextShadow  = Color("Button/TextShadow")  // rgba(0,0,0,.45) — 0 1 2

    // Предупреждение (WarningLine): строка текста со значком, без фона, рамки и свечения —
    // чтобы не читалась как кнопка. Тень текста — Ink/TitleShadow.
    static let warnIcon = Color("Warn/Icon") // #FF7A2F
    static let warnText = Color("Warn/Text") // dark #FFC2A6 · light #FFFFFF

    /// Затемнение под модальным окном G3 («Выйти из партии?» и подобные).
    static let overlayScrim = Color("Overlay/Scrim") // dark rgba(2,10,20,.55) · light rgba(4,26,40,.40)
}

extension RadialGradient {
    /// Свечение снизу по центру — единственный слой, который дышит.
    /// Геометрия одна на все экраны и обе темы: центр (50 %, 91 %),
    /// радиус 60 % ширины области. Масштаб дыхания — scaleEffect внутри
    /// обрезающего контейнера; констант вылета за края не нужно.
    static func seaGlow(in size: CGSize) -> RadialGradient {
        RadialGradient(
            gradient: Gradient(stops: [.init(color: .seaGlow, location: 0),
                                       .init(color: .clear, location: 0.70)]),
            center: .init(x: 0.5, y: 0.91),
            startRadius: 0,
            endRadius: size.width * 0.60)
    }
}

extension LinearGradient {
    /// Мат вокруг фото на главном — единственный градиент дерева в игре.
    static let woodMat = LinearGradient(colors: [.wood, .woodDeep], startPoint: .top, endPoint: .bottom)
}

extension LinearGradient {
    /// Фон всего приложения. **Неподвижен** — дышит только слой свечения
    /// над ним (см. Motion.breathe). Рисунка волн нет. Точка перелома 46 % в обеих темах.
    static let sea = LinearGradient(
        stops: [.init(color: .seaTop, location: 0),
                .init(color: .seaMid, location: 0.46),
                .init(color: .seaBottom, location: 1)],
        startPoint: .top, endPoint: .bottom)

    static let waterCell = LinearGradient(
        colors: [.waterTop, .waterBottom],
        startPoint: .init(x: 0.15, y: 0), endPoint: .init(x: 0.85, y: 1))

    /// Корпус, запрет и сталь — под 168°, как в макетах. Точки посчитаны по правилу CSS
    /// для квадратной клетки: линия градиента длиной |sin| + |cos| через центр.
    static let cellStart = UnitPoint(x: 0.3767, y: -0.0800)
    static let cellEnd   = UnitPoint(x: 0.6233, y: 1.0800)

    static let hullSand = LinearGradient(
        stops: [.init(color: .hullSandLight, location: 0),
                .init(color: .hullSand, location: 0.46),
                .init(color: .hullSandDark, location: 1)],
        startPoint: cellStart, endPoint: cellEnd)

    /// Корабль в запрещённой позиции: в руке — с прозрачностью 0.62, после
    /// отпускания плотный. Геометрия та же, что у hullSand.
    static let hullDenied = LinearGradient(
        stops: [.init(color: .hullDeniedLight, location: 0),
                .init(color: .hullDenied, location: 0.46),
                .init(color: .hullDeniedDark, location: 1)],
        startPoint: cellStart, endPoint: cellEnd)

    static let steelSunk = LinearGradient(
        stops: [.init(color: .steelTop, location: 0),
                .init(color: .steelMid, location: 0.45),
                .init(color: .steelBottom, location: 1)],
        startPoint: cellStart, endPoint: cellEnd)
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

    enum Nav {
        static let rowHeight: CGFloat = 44       // NavRow; в макете 41 — ошибка макета
        static let rowRadius: CGFloat = 20
        static let rowPadding: CGFloat = 15
        static let stackInset: CGFloat = 12      // BottomStack: поля
        static let stackBottom: CGFloat = 10
        static let stackGap: CGFloat = 8
        static let titleInset: CGFloat = 20      // ScreenTitle: поля
        static let titleTop: CGFloat = 68
        static let titleGap: CGFloat = 6
        static let padColumn: CGFloat = 520      // iPad: колонка экрана уровня
    }

    /// Два размера iPhone. Компактный — ширина экрана < 390 pt. Спека 3.3.
    /// Величины, которых здесь нет, одинаковы на обоих.
    struct SizeClass {
        let menuInset, menuGap: CGFloat
        let photo, photoRadius, mat, photoInnerRadius: CGFloat
        let matShadowY, matShadowBlur: CGFloat; let matShadowAlpha: Double
        let modeListGap, modeRowHeight, modeRowRadius, modeRowPadding, modeRowGap: CGFloat
        let modeIcon, modeName, modeSub, modeLock: CGFloat
        let continueText: CGFloat
        let tabInset, tabBottom, tabHeight, tabRadius, tabIcon, tabLabel: CGFloat
        let cell, cellCoords: CGFloat

        static let compactBreakpoint: CGFloat = 390
        static func forWidth(_ w: CGFloat) -> SizeClass { w < compactBreakpoint ? compact : regular }

        static let regular = SizeClass(
            menuInset: 20, menuGap: 14, photo: 252, photoRadius: 22, mat: 5, photoInnerRadius: 17,
            matShadowY: 10, matShadowBlur: 28, matShadowAlpha: 0.38,
            modeListGap: 8, modeRowHeight: 58, modeRowRadius: 18, modeRowPadding: 13, modeRowGap: 11,
            modeIcon: 30, modeName: 15, modeSub: 11.5, modeLock: 21, continueText: 15,
            tabInset: 12, tabBottom: 10, tabHeight: 68, tabRadius: 26, tabIcon: 25, tabLabel: 11,
            cell: 32, cellCoords: 30)

        static let compact = SizeClass(
            menuInset: 16, menuGap: 12, photo: 170, photoRadius: 18, mat: 4, photoInnerRadius: 14,
            matShadowY: 8, matShadowBlur: 22, matShadowAlpha: 0.36,
            modeListGap: 7, modeRowHeight: 52, modeRowRadius: 16, modeRowPadding: 11, modeRowGap: 10,
            modeIcon: 26, modeName: 14, modeSub: 10.5, modeLock: 19, continueText: 13.5,
            tabInset: 10, tabBottom: 8, tabHeight: 56, tabRadius: 22, tabIcon: 21, tabLabel: 10,
            cell: 30, cellCoords: 28)
    }

    /// SecondaryButton: стекло G2 без бевеля и латуни. Спека 2.15.
    enum SecondaryButton {
        static let height: CGFloat = 44
        static let radius: CGFloat = 16
        static let padding: CGFloat = 16
        static let icon: CGFloat = 20
        static let gap: CGFloat = 8
    }

    /// WarningLine под полем. Не нажимается и не выглядит нажимаемой. Спека 2.16.
    enum Warning {
        static let icon: CGFloat = 16
        static let gap: CGFloat = 6
        static let belowBoard: CGFloat = 12
    }

    /// Сегментированный переключатель: видимый сегмент 44 pt, зона касания = сегмент.
    /// Обойма 3 pt с каждой стороны → общая высота 50 pt. Радиусы не меняются.
    enum Segment {
        static let height: CGFloat = 44
        static let trackInset: CGFloat = 3
    }

    /// Кант между стеклом панели и морем: верх нижней панели, низ верхней.
    static let woodEdge: CGFloat = 2
}

// MARK: - Материал

extension Material {
    /// G2 — основной материал панелей: blur 18, saturate 1,6 (в светлой 1,3).
    /// На iOS 18 подменяется на .ultraThinMaterial с той же раскладкой.
    static var glassPanel: Material { .ultraThinMaterial }
    /// G3 — приподнятый слой (листы, поповеры): blur 26, saturate 2 (в светлой 1,4).
    static var glassRaised: Material { .thinMaterial }
}

// MARK: - Типографика

enum TypeScale {
    /// Название игры на главном и приветствии. Трекинг −.02em: .tracking(gameTitleTracking(compact)).
    static func gameTitle(compact: Bool) -> Font {
        .system(size: compact ? 28 : 36, weight: .semibold, design: .rounded)
    }
    static func gameTitleTracking(compact: Bool) -> CGFloat { compact ? -0.56 : -0.72 }
    /// Заголовок экрана (ScreenTitle), один на оба размера. Трекинг −.01em.
    static let screenTitle = Font.system(size: 30, weight: .bold, design: .rounded)
    static let screenTitleTracking: CGFloat = -0.3
    /// Подзаголовок ScreenTitle (необязательный): межстрочный 1,4, до двух строк, Ink/Secondary.
    static let screenSubtitle = Font.system(size: 12.5, weight: .regular)
    static let secondaryButton = Font.system(size: 14, weight: .semibold, design: .rounded)
    static let warning = Font.system(size: 13.5, weight: .semibold, design: .rounded)
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
    static let breathe: Double = 18.0       // дыхание слоя свечения (не всего фона)
    static let breatheScale: ClosedRange<CGFloat> = 1.04...1.10
    static let breatheOffsetY: CGFloat = -0.02   // доля высоты области
    static let breatheOpacity: ClosedRange<Double> = 0.9...1.0
    static let jiggleRange: ClosedRange<Double> = 0.40...0.51 // дрожание клеток
    static let jiggleAngle: Double = 1.4    // градусы, ±
    static let jigglePhase: ClosedRange<Double> = 0...0.24

    static let standard = Animation.easeInOut(duration: stateSwap)
    static let quick = Animation.easeOut(duration: aim)

    /// Reduce Motion: перемещения и масштаб → прозрачность, длительности × 0,5,
    /// дрожание выключено, слой свечения стоит неподвижно на средних значениях
    /// (scale 1.07, offset 0, opacity 1) — не исчезает. Состояния клеток не меняются.
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
    латунная подложка, белая надпись. Второстепенная — стекло G2 без бевеля и латуни,
    намеренно тише. Других видов кнопок нет.
 7. Передача устройства — не sheet, а непрозрачный слой в том же контейнере.
 8. Градиент моря неподвижен. Дышит только слой свечения над ним.
 9. Геометрия живёт в коде и одна на обе темы; в ассет-каталог уходят только цвета.
    Если понадобилась разная геометрия по темам — ошибся дизайн, а не код.
10. Имена вида "Sea/Top" работают только потому, что у папок в Colors.xcassets включён
    Provides Namespace. Каталог в пакете уже собран так — не пересобирать вручную.
 */
