//
//  iPadMenuBattonsViewH.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 07/01/2025.
//

import SwiftUI

struct iPadMenuButtonsViewH: View {
    
    let width: CGFloat
    let height: CGFloat
    let biggerWidth: Bool
    var relativeSize: CGFloat {
        return biggerWidth ? self.width * 0.22 : self.width * 0.175
    }
    
    var body: some View {
        Image("wood")
            .resizable()
            .frame(width: relativeSize, height: height * 0.12)
            .clipShape(CustomRoundedRectangle(cornerRadius: 25, roundedCorners: [.topRight]))
            .shadow(color: .white, radius: 5)
    }
    init(width: CGFloat, height: CGFloat, biggerWidth: Bool) {
        self.width = width
        self.height = height
        self.biggerWidth = biggerWidth
    }
}

#Preview {
    iPadMenuButtonsViewH(width: 400, height: 500, biggerWidth: true)
}

