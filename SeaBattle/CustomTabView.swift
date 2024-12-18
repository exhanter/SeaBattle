//
//  CustomTabView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 02/09/2024.
//
import SwiftUI

struct CustomTabView: View {
    @ObservedObject var player: PlayerData
    let relativeFornSize: CGFloat
    let height: CGFloat
    var tabsLockBeforeGameStart: Bool {
        if !player.gameIsActive {
            return player.selectedTab == .menu || player.selectedTab == .about ? true : false
        }
        return false
    }
    var body: some View {
            ZStack {
                Image("wood")
                    .resizable()
                    .renderingMode(.original)
                    .frame(height: height)
                HStack {
                    Button {
                        if player.soundOn {
                            PlayerData.playSound(sound: "click_sound.wav")
                        }
                        player.selectedTab = .menu
                    } label: {
                        if player.selectedTab == .menu {
                            Text("Menu")
                                .font(.custom("Dorsa", size: relativeFornSize))
                                .foregroundColor(Color(red: 248/255, green: 1, blue: 0))
                                .underline()
                        } else {
                            Text("Menu")
                                .font(.custom("Dorsa", size: relativeFornSize))
                                .foregroundColor(Color(red: 248/255, green: 1, blue: 0))
                        }
                    }
                    .disabled(player.tabsBlocked)
                    .opacity(player.tabsBlocked ? 0.5 : 1)
                    .padding(.horizontal)
                    Button {
                        if player.soundOn {
                            PlayerData.playSound(sound: "click_sound.wav")
                        }
                        player.selectedTab = .playerView
                    } label: {
                        if player.selectedTab == .playerView {
                            Text("Player")
                                //.font(.custom("Dorsa", size: 50))
                                .font(.custom("Dorsa", size: relativeFornSize))
                                .foregroundColor(Color(red: 248/255, green: 1, blue: 0))
                                .underline()
                        } else {
                            Text("Player")
                                .font(.custom("Dorsa", size: relativeFornSize))
                                .foregroundColor(Color(red: 248/255, green: 1, blue: 0))
                        }
                    }
                    .disabled(player.tabsBlocked)
                    .disabled(self.tabsLockBeforeGameStart)
                    .opacity(player.tabsBlocked ? 0.5 : 1)
                    .padding(.horizontal)
                    Button {
                        if player.soundOn {
                            PlayerData.playSound(sound: "click_sound.wav")
                        }
                        player.selectedTab = .enemyView
                    } label: {
                        if player.selectedTab == .enemyView {
                            Text("Enemy")
                                .font(.custom("Dorsa", size: relativeFornSize))
                                .foregroundColor(Color(red: 248/255, green: 1, blue: 0))
                                .underline()
                        } else {
                            Text("Enemy")
                                .font(.custom("Dorsa", size: relativeFornSize))
                                .foregroundColor(Color(red: 248/255, green: 1, blue: 0))
                        }
                    }
                    .disabled(player.tabsBlocked)
                    .disabled(self.tabsLockBeforeGameStart)
                    .opacity(player.tabsBlocked ? 0.5 : 1)
                    .padding(.horizontal)
                    Button {
                        if player.soundOn {
                            PlayerData.playSound(sound: "click_sound.wav")
                        }
                        player.selectedTab = .about
                    } label: {
                        if player.selectedTab == .about {
                            Text("About")
                                .font(.custom("Dorsa", size: relativeFornSize))
                                .foregroundColor(Color(red: 248/255, green: 1, blue: 0))
                                .underline()
                        } else {
                            Text("About")
                                .font(.custom("Dorsa", size: relativeFornSize))
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
    CustomTabView(player: PlayerData(name: "Player"), relativeFornSize: 375, height: 100)
}
