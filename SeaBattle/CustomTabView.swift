//
//  CustomTabView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 02/09/2024.
//
import SwiftUI

struct CustomTabView: View {
    @ObservedObject var appState: AppState
    let relativeFornSize: CGFloat
    let height: CGFloat
    var tabsLockBeforeGameStart: Bool {
        if !appState.gameIsActive {
            return appState.selectedTab == .menu || appState.selectedTab == .about ? true : false
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
                        if appState.soundOn {
                            AppState.playSound(sound: "click_sound.wav")
                        }
                        appState.selectedTab = .menu
                    } label: {
                        if appState.selectedTab == .menu {
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
                    .disabled(appState.tabsBlocked)
                    .opacity(appState.tabsBlocked ? 0.5 : 1)
                    .padding(.horizontal)
                    Button {
                        if appState.soundOn {
                            AppState.playSound(sound: "click_sound.wav")
                        }
                        appState.selectedTab = .playerView
                    } label: {
                        if appState.selectedTab == .playerView {
                            Text("Player")
                                .font(.custom("Dorsa", size: relativeFornSize))
                                .foregroundColor(Color(red: 248/255, green: 1, blue: 0))
                                .underline()
                        } else {
                            Text("Player")
                                .font(.custom("Dorsa", size: relativeFornSize))
                                .foregroundColor(Color(red: 248/255, green: 1, blue: 0))
                        }
                    }
                    .disabled(appState.tabsBlocked)
                    .disabled(self.tabsLockBeforeGameStart)
                    .opacity(appState.tabsBlocked ? 0.5 : 1)
                    .padding(.horizontal)
                    Button {
                        if appState.soundOn {
                            AppState.playSound(sound: "click_sound.wav")
                        }
                        appState.selectedTab = .enemyView
                    } label: {
                        if appState.selectedTab == .enemyView {
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
                    .disabled(appState.tabsBlocked)
                    .disabled(self.tabsLockBeforeGameStart)
                    .opacity(appState.tabsBlocked ? 0.5 : 1)
                    .padding(.horizontal)
                    Button {
                        if appState.soundOn {
                            AppState.playSound(sound: "click_sound.wav")
                        }
                        appState.selectedTab = .about
                    } label: {
                        if appState.selectedTab == .about {
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
                    .disabled(appState.tabsBlocked)
                    .opacity(appState.tabsBlocked ? 0.5 : 1)
                    .padding(.horizontal)
                }
                .frame(height: height)
            }
    }
}

#Preview {
    CustomTabView(appState: AppState(), relativeFornSize: 375, height: 100)
}
