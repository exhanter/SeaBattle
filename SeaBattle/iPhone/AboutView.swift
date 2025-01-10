//
//  AboutView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 06/02/2024.
//

import SwiftUI

struct AboutView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var showInformationView = false
    @State private var showContactsView = false
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(gradient: Gradient(colors: [Color(red: 0.11, green: 0.77, blue: 0.56).opacity(0.60), Color(red: 0.04, green: 0.10, blue: 0.25).opacity(0.80)]), startPoint: .bottom, endPoint: .top)
                    .ignoresSafeArea()
                ScrollView {
                    Text("Game rules")
                        .font(.custom("Aldrich", size: 42))
                        .foregroundStyle(Color(red: 248/255, green: 255/255, blue: 0/255))
                        .padding(.top, 50)
                        .padding()
                    Text("""
Objective: 

Sink all of your opponent’s ships before they sink yours.

Setup:

Each player has a grid (10x10).
Players place their fleet of ships on the grid:

1 ship of 4 cells
2 ships of 3 cells
3 ships of 2 cells
4 ships of 1 cell

Ships can be placed horizontally or vertically, but not diagonally. Ships cannot overlap. There must always be at least a 1-cell gap between the ships.

Gameplay:

Players take turns selecting cells on the opponent's field. The game will indicate the result of each guess:

- Miss
- Hit (ship is damaged)
- Sunk (ship is destroyed)

Players continue guessing until all the ships of one player are sunk.

Winning: The first player to sink all of the opponent’s ships wins the game.
""")
                    .font(.custom("Aldrich", size: 22))
                    .foregroundStyle(Color(red: 248/255, green: 255/255, blue: 0/255))
                    Button("Rights and licenses") {
                        self.showInformationView = true
                    }
                    .buttonStyle(.bordered)
                    .foregroundStyle(Color(red: 248/255, green: 255/255, blue: 0/255))
                    .padding(.top)
                    Button("Contacts") {
                        self.showContactsView = true
                    }
                    .buttonStyle(.bordered)
                    .foregroundStyle(Color(red: 248/255, green: 255/255, blue: 0/255))
                }
                .scrollIndicators(.hidden)
                .padding(.vertical, 20)
                .padding(.horizontal, geometry.size.width * 0.05)
                .background(.clear)
                .sheet(isPresented: $showInformationView) {
                    InformationView()
                        .presentationDetents([.medium, .large])
                }
                .sheet(isPresented: $showContactsView) {
                    ContactsView()
                    .presentationDetents([.medium, .large])
                }
            }
            .statusBar(hidden: true)
        }
    }
}

#Preview {
    AboutView()
        .environmentObject(AppState(tempInstance: true))
}
