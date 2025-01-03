//
//  PictureShipView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 26/12/2024.
//

import SwiftUI

struct PictureShipView: View {
    var body: some View {
        //Image("war_ship8")
        ZStack {
            Color.blue
                .edgesIgnoringSafeArea(.all) // Квадратная рамка с закругленными углами внутри и снаружи
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.white, lineWidth: 30)
                .background( RoundedRectangle(cornerRadius: 20)
                    .foregroundColor(.clear) )
                .mask( RoundedRectangle(cornerRadius: 20)
                    .padding(15) // Добавляем отступ для закругления углов внутри
                )
                    .frame(width: 200, height: 200)
                       }
    }
}

#Preview {
    PictureShipView()
}
