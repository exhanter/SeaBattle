//
//  CustomTabView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 02/09/2024.
//
import SwiftUI

struct CustomTabView: View {
    var player: PlayerData
    
    let height: CGFloat
    var body: some View {
        ZStack {
            Image("wood")
                .resizable()
                .renderingMode(.original)
                .frame(height: height)
            HStack {
                Button {
                    if player.soundIsOn {
                        PlayerData.playSound(sound: "click_sound.wav")
                    }
                    player.selectedTab = .menu
                } label: {
                    if player.selectedTab == .menu {
                        Text("Menu")
                            .font(.custom("Dorsa", size: 50))
                            .foregroundColor(Color(red: 248/255, green: 1, blue: 0))
                            .underline()
                    } else {
                        Text("Menu")
                            .font(.custom("Dorsa", size: 50))
                            .foregroundColor(Color(red: 248/255, green: 1, blue: 0))
                        }
                    }
                .disabled(player.tabsBlocked)
                .opacity(player.tabsBlocked ? 0.5 : 1)
                .padding(.horizontal)
                Button {
                    if player.soundIsOn {
                        PlayerData.playSound(sound: "click_sound.wav")
                    }
                        player.selectedTab = .playerView
                } label: {
                    if player.selectedTab == .playerView {
                        Text("Player")
                            .font(.custom("Dorsa", size: 50))
                            .foregroundColor(Color(red: 248/255, green: 1, blue: 0))
                            .underline()
                    } else {
                        Text("Player")
                            .font(.custom("Dorsa", size: 50))
                            .foregroundColor(Color(red: 248/255, green: 1, blue: 0))
                        }
                }
                .disabled(player.tabsBlocked)
                .opacity(player.tabsBlocked ? 0.5 : 1)
                .padding(.horizontal)
                Button {
                    if player.soundIsOn {
                        PlayerData.playSound(sound: "click_sound.wav")
                    }
                        player.selectedTab = .enemyView
                } label: {
                    if player.selectedTab == .enemyView {
                        Text("Enemy")
                            .font(.custom("Dorsa", size: 50))
                            .foregroundColor(Color(red: 248/255, green: 1, blue: 0))
                            .underline()
                    } else {
                        Text("Enemy")
                            .font(.custom("Dorsa", size: 50))
                            .foregroundColor(Color(red: 248/255, green: 1, blue: 0))
                        }
                }
                .disabled(player.tabsBlocked)
                .opacity(player.tabsBlocked ? 0.5 : 1)
                .padding(.horizontal)
                Button {
                    if player.soundIsOn {
                        PlayerData.playSound(sound: "click_sound.wav")
                    }
                    player.selectedTab = .about
                } label: {
                    if player.selectedTab == .about {
                        Text("About")
                            .font(.custom("Dorsa", size: 50))
                            .foregroundColor(Color(red: 248/255, green: 1, blue: 0))
                            .underline()
                    } else {
                        Text("About")
                            .font(.custom("Dorsa", size: 50))
                            .foregroundColor(Color(red: 248/255, green: 1, blue: 0))

                        }
                }
                .disabled(player.tabsBlocked)
                .opacity(player.tabsBlocked ? 0.5 : 1)
                .padding(.horizontal)
            }
            .frame(height: height)
        }
    }
}

#Preview {
    CustomTabView(player: PlayerData(name: "Player"), height: 100)
}
