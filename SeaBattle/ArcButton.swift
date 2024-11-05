//
//  ArcButton.swift
//  SeaBattle
//
//  Created by Иван Ткачев on 26/08/2024.
//

import SwiftUI

struct ArcButton: View {
    let fontSize: CGFloat
    var body: some View {
        ZStack {
          Group {
            Text("a")
              .font(Font.custom("Aldrich", size: fontSize))
              .offset(x: 28.39, y: 7.07)
              .rotationEffect(.degrees(2.76))
            Text("B")
              .font(Font.custom("Aldrich", size: fontSize))
              .offset(x: -4.36, y: 7.06)
            Text(" ")
              .font(Font.custom("Aldrich", size: fontSize))
              .offset(x: -33.32, y: 5.76)
              .rotationEffect(.degrees(-3.23))
            Text("t")
              .font(Font.custom("Aldrich", size: fontSize))
              .offset(x: 55.19, y: 5.34)
              .rotationEffect(.degrees(5.36))
            Text("t")
              .font(Font.custom("Aldrich", size: fontSize))
              .offset(x: 77.63, y: 3.10)
              .rotationEffect(.degrees(7.55))
            Text("a")
              .font(Font.custom("Aldrich", size: fontSize))
              .offset(x: -60.57, y: 2.83)
              .rotationEffect(.degrees(-5.89))
            Text("l")
              .font(Font.custom("Aldrich", size: fontSize))
              .offset(x: 99.43, y: 0.01)
              .rotationEffect(.degrees(9.69))
            Text("e")
              .font(Font.custom("Aldrich", size: fontSize))
              .offset(x: -90.84, y: -1.63)
              .rotationEffect(.degrees(-8.85))
            Text("e")
              .font(Font.custom("Aldrich", size: fontSize))
              .offset(x: 124.88, y: -3.71)
              .rotationEffect(.degrees(12.19))
            Text("S")
              .font(Font.custom("Aldrich", size: fontSize))
              .offset(x: -122.36, y: -8.49)
              .rotationEffect(.degrees(-11.98))
          }
          .foregroundColor(Color(red: 248/255, green: 255/255, blue: 0/255))
          .shadow(color: .black, radius: 2, x: 2, y: 2)
        }
    }
}

#Preview {
    ArcButton(fontSize: 48)
}
