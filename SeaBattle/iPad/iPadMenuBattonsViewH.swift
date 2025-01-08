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
    
    var body: some View {
        Image("wood")
            .resizable()
            .frame(width: width, height: height)
            .clipShape(CustomRoundedRectangle(cornerRadius: 25, roundedCorners: [.topRight]))
            .shadow(color: .white, radius: height * 0.06)
    }
    init(width: CGFloat, height: CGFloat) {
        self.width = width * 0.175
        self.height = height * 0.12
    }
}

#Preview {
    iPadMenuButtonsViewH(width: 400, height: 500)
}

