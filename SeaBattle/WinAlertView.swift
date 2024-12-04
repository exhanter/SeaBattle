//
//  WinAlertView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 05/09/2024.
//

import SwiftUI

struct WinAlertView: View {
    let isPlayerWon: Bool
    var text: String
    var body: some View {
        VStack(alignment: .center) {
            Text(text)
                .font(.custom("Dorsa", size: 250))
        }
        .foregroundStyle(isPlayerWon ? Color(red: 248/255, green: 255/255, blue: 0/255) : .black)
        .shadow(color: .white, radius: 5)
    }
}

#Preview {
    WinAlertView(isPlayerWon: false, text: "Victory")
}
