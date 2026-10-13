//
//  PadLevelVariants.swift
//  Sea Battle — ВРЕМЕННО: варианты экрана уровня на iPad (10.10)
//
//  Заказчик выбирает по превью; после выбора файл удаляется, выбранное
//  переезжает в `AppShell`.
//

import SwiftUI

private struct PadLevelVariant: View {
    let chrome: Geometry.BottomChrome

    @State private var selected: AppState.DifficultyLevel = .hard
    @State private var markWater = true
    @State private var soundOn = true
    @State private var musicOn = false
    @State private var hapticsOn = false

    var body: some View {
        ZStack {
            SeaBackground()
                .ignoresSafeArea()
            LevelScreen(selected: selected, isPremium: false,
                        onSelect: { selected = $0 },
                        options: LevelMatchOptions(balance: 42, markWater: $markWater,
                                                   soundOn: $soundOn, musicOn: $musicOn,
                                                   hapticsOn: $hapticsOn, offersHaptics: false))
        }
        .environment(\.usesPadLayout, true)
        .environment(\.bottomChrome, chrome)
        .preferredColorScheme(.dark)
    }
}

struct PadLevel1_Previews: PreviewProvider {
    static var previews: some View {
        PadLevelVariant(chrome: .dock)
            .padPreview(.portrait, "1 · Капсулы и док")
    }
}

struct PadLevel2_Previews: PreviewProvider {
    static var previews: some View {
        PadLevelVariant(chrome: .tiles)
            .padPreview(.portrait, "2 · Квадраты по углам")
    }
}

struct PadLevel3_Previews: PreviewProvider {
    static var previews: some View {
        PadLevelVariant(chrome: .dock)
            .padPreview(.landscapeLeft, "3 · Капсулы и док · горизонтально")
    }
}

struct PadLevel4_Previews: PreviewProvider {
    static var previews: some View {
        PadLevelVariant(chrome: .tiles)
            .padPreview(.landscapeLeft, "4 · Квадраты по углам · горизонтально")
    }
}
