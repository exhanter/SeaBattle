//
//  iPadButtonView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 23/12/2024.
//

import SwiftUI

enum ButtonSide {
    case up, down, left, right
}

struct iPadButtonView: View {
    let text: String
    let cornerRadius: CGFloat
    let screenSide: ButtonSide
    var roundedCorners: UIRectCorner {
        switch screenSide {
        case .up:    [.bottomLeft, .bottomRight]
        case .down:  [.topLeft, .topRight]
        case .left:  [.topRight, .bottomRight]
        case .right: [.topLeft, .bottomLeft]
        }
    }
    var body: some View {
        Text(text)
            .foregroundColor(.white)
            .padding()
            .background(Color.white.opacity(0.1)
                .clipShape(CustomRoundedRectangle(cornerRadius: cornerRadius, roundedCorners: roundedCorners))
                .overlay( CustomRoundedRectangle(cornerRadius: cornerRadius, roundedCorners: roundedCorners)
                .stroke(Color.white.opacity(0.2), lineWidth: 1) ) )
            .shadow(radius: 3)
    }
    init(text: String, cornerRadius: CGFloat, screenSide: ButtonSide) {
        self.text = text
        self.cornerRadius = cornerRadius
        self.screenSide = screenSide
    }
}

#Preview {
    iPadButtonView(text: "Change", cornerRadius: 25, screenSide: .right)
}
