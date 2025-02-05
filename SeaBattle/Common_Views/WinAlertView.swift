//
//  WinAlertView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 05/09/2024.
//

import SwiftUI

struct WinAlertView: View {
    let isPlayerWon: Bool
    var body: some View {
        VStack(alignment: .center) {
            Text(isPlayerWon ? "Victory!" : "Defeat!")
                .font(.custom("Dorsa", size: 250))
        }
        .foregroundStyle(isPlayerWon ? Color(red: 248/255, green: 255/255, blue: 0/255) : .black)
        .shadow(color: .white, radius: 5)
        .minimumScaleFactor(0.6)
        .lineLimit(1)
        .padding(.horizontal, 20)
    }
}

#Preview("English") {
    WinAlertView(isPlayerWon: false)
}

#Preview("Dutch") {
    WinAlertView(isPlayerWon: true)
        .environment(\.locale, Locale(identifier: "NL"))
}
