import SwiftUI

// Арт iPad на трёх размерах (выбор заказчика 29.10): вертикально — корабль
// целиком над названием, горизонтально в меню — над рядом плиток, вода до
// низа экрана темнеет к нему; первый запуск горизонтально — постер.
// Устройство задано у каждого превью: канвас иначе берёт iPad Pro 11".

enum PadDevice {
    static let mini = "iPad mini (A17 Pro)"
    static let pro11 = "iPad Pro 11-inch (M5)"
    static let pro13 = "iPad Pro 13-inch (M5)"
}

struct PadMenuArtDemo: View {
    var body: some View {
        ZStack {
            SeaBackground()
                .ignoresSafeArea()
            PadMenuScreen(isPremium: false, canContinue: true, continueLevel: .hard)
        }
        .preferredColorScheme(.dark)
    }
}

struct PadWelcomeArtDemo: View {
    var body: some View {
        ZStack {
            SeaBackground()
                .ignoresSafeArea()
            PadWelcomeScreen()
        }
        .environment(\.usesPadLayout, true)
        .phoneStyle(true)
        .preferredColorScheme(.dark)
    }
}

struct PadArt1_Previews: PreviewProvider {
    static var previews: some View {
        PadMenuArtDemo().padPreview(.portrait, "1 · меню · 11\"", device: PadDevice.pro11)
    }
}

struct PadArt2_Previews: PreviewProvider {
    static var previews: some View {
        PadMenuArtDemo().padPreview(.landscapeLeft, "2 · меню · 11\"", device: PadDevice.pro11)
    }
}

struct PadArt3_Previews: PreviewProvider {
    static var previews: some View {
        PadMenuArtDemo().padPreview(.portrait, "3 · меню · mini", device: PadDevice.mini)
    }
}

struct PadArt4_Previews: PreviewProvider {
    static var previews: some View {
        PadMenuArtDemo().padPreview(.landscapeLeft, "4 · меню · mini", device: PadDevice.mini)
    }
}

struct PadArt5_Previews: PreviewProvider {
    static var previews: some View {
        PadMenuArtDemo().padPreview(.landscapeLeft, "5 · меню · 13\"", device: PadDevice.pro13)
    }
}

struct PadArt6_Previews: PreviewProvider {
    static var previews: some View {
        PadWelcomeArtDemo().padPreview(.portrait, "6 · первый запуск · mini", device: PadDevice.mini)
    }
}

struct PadArt7_Previews: PreviewProvider {
    static var previews: some View {
        PadWelcomeArtDemo().padPreview(.landscapeLeft, "7 · первый запуск · mini", device: PadDevice.mini)
    }
}
