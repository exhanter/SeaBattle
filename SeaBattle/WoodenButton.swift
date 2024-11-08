//
//  LightGreenButton.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 26/08/2024.
//

import SwiftUI

struct WoodenButton: ButtonStyle {
    var radius: CGFloat
    var fontSize: CGFloat
    var width: CGFloat
    var height: CGFloat
    
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 0) {
            configuration.label
            .font(.custom("Aldrich", size: fontSize))//Kelly Slab
            .foregroundColor(Color(red: 248/255, green: 255/255, blue: 0/255))
        }
        .frame(width: width, height: height)
        .background(
            Image("wood")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .offset(y: -50)
        )
        .cornerRadius(radius)
        .shadow(color: Color(red: 0, green: 0, blue: 0, opacity: 0.35), radius: 3, x: 2, y: 2)
        .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
        .opacity(configuration.isPressed ? 0.8 : 1.0)
        .animation(.easeInOut, value: configuration.isPressed)
    }
}


struct viewButton: View {
    var body: some View {
        Button("Start") {}
            .buttonStyle(WoodenButton(radius: 20, fontSize: 40, width: 320, height: 70))
    }
}
#Preview {
    viewButton()
}


