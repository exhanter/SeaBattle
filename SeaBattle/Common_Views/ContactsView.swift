//
//  ContactsView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 27/12/2024.
//

import SwiftUI

struct ContactsView: View {
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.11, green: 0.77, blue: 0.56).opacity(0.60), Color(red: 0.04, green: 0.10, blue: 0.25).opacity(0.80)]), startPoint: .bottom, endPoint: .top)
                .ignoresSafeArea()
            .ignoresSafeArea()
            VStack(alignment: .leading) {
                Spacer()
                Text("This game was created by Ivan Tkachev in 2024. The game is available for iPhone and iPad.")
                    .padding(.top, 50)
                    Text("If you have any questions, you can contact me:")
                HStack {
                    Text("Email:      ")
                    Text("request@brapps.nl")
                        .background(Color(red: 248/255, green: 255/255, blue: 0/255))
                }
                HStack {
                    Text("LinkedIn: ")
                    Text("[ivan-tkachev](https://www.linkedin.com/in/ivan-tkachev)")
                        .background(Color(red: 248/255, green: 255/255, blue: 0/255))
                }
                HStack {
                    Text("Website: ")
                    Text("[https://brapps.nl](https://www.brapps.nl)")
                    .background(Color(red: 248/255, green: 255/255, blue: 0/255))
                }
                Spacer()
            }
            .italic()
            .foregroundStyle(.white)
            .padding(20)
        }
        .statusBar(hidden: true)
    }
}

#Preview {
    ContactsView()
}
