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
            VStack(spacing: 0) {
                Image("wood")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                Image("wood")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            }
            .ignoresSafeArea()
            VStack(alignment: .leading) {
                Spacer()
                Text("This game was created by Ivan Tkachev in 2024.")
                    .padding(.top, 50)
                    Text("If you have any questions, you can contact me:")
                HStack {
                    Text("Email:      ")
                    Text("2ivan.tkachev@gmail.com")
                        .background(Color(red: 248/255, green: 255/255, blue: 0/255))
                }
                HStack {
                    Text("LinkedIn: ")
                    Text("[https://www.linkedin.com/in/ivan-tkachev](https://www.linkedin.com/in/ivan-tkachev)")
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
