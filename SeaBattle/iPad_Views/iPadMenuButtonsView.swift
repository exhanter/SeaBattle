//
//  iPadMenuButtonsView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 03/01/2025.
//

import SwiftUI

struct iPadMenuButtonsViewV: View {
    
    let width: CGFloat
    let height: CGFloat
    let relativeFontSize: CGFloat
    
    var body: some View {
        Image("wood")
            .resizable()
            .frame(width: width, height: height)
            .clipShape(CustomRoundedRectangle(cornerRadius: 25, roundedCorners: [.topRight, .bottomRight]))
            .shadow(color: .white, radius: width * 0.06)
    }
    init(width: CGFloat, height: CGFloat) {
        self.width = width * 0.11
        self.height = height * 0.2
        self.relativeFontSize = width * 0.06
    }
}

#Preview {
    iPadMenuButtonsViewV(width: 500, height: 400)
}
