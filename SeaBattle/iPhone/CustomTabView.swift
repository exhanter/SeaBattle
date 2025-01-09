//
//  CustomTabView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 02/09/2024.
//
import SwiftUI

struct CustomTabView: View {
    @ObservedObject var appState: AppState
    let relativeFontSize: CGFloat
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
                    Spacer()
                    Button {
                        if appState.soundOn {
                            AppState.playSound(sound: "click_sound.wav")
                        }
                        appState.selectedTab = .menu
                    } label: {
                        if appState.selectedTab == .menu {
                            Text("Menu")
                                .font(.custom("Dorsa", size: relativeFontSize))
                                .foregroundColor(Color(red: 248/255, green: 1, blue: 0))
                                .underline()
                                .fixedSize(horizontal: true, vertical: true)
                                .shadow(color: .white, radius: 1)
                        } else {
                            Text("Menu")
                                .font(.custom("Dorsa", size: relativeFontSize))
                                .foregroundColor(Color(red: 248/255, green: 1, blue: 0))
                                .fixedSize(horizontal: true, vertical: true)
                        }
                    }
                    .disabled(appState.tabsBlocked)
                    .opacity(appState.tabsBlocked ? 0.5 : 1)
                    //.padding(.horizontal)
                    Spacer()
                    Button {
                        if appState.soundOn {
                            AppState.playSound(sound: "click_sound.wav")
                        }
                        appState.selectedTab = .playerView
                    } label: {
                        if appState.selectedTab == .playerView {
                            Text("Player")
                                .font(.custom("Dorsa", size: relativeFontSize))
                                .foregroundColor(Color(red: 248/255, green: 1, blue: 0))
                                .underline()
                                .fixedSize(horizontal: true, vertical: true)
                                .shadow(color: .white, radius: 1)
                        } else {
                            Text("Player")
                                .font(.custom("Dorsa", size: relativeFontSize))
                                .foregroundColor(Color(red: 248/255, green: 1, blue: 0))
                                .fixedSize(horizontal: true, vertical: true)
                        }
                    }
                    .disabled(appState.tabsBlocked)
                    .disabled(self.tabsLockBeforeGameStart)
                    .opacity(appState.tabsBlocked ? 0.5 : 1)
                    //.padding(.horizontal)
                    Spacer()
                    Button {
                        if appState.soundOn {
                            AppState.playSound(sound: "click_sound.wav")
                        }
                        appState.selectedTab = .enemyView
                    } label: {
                        if appState.selectedTab == .enemyView {
                            Text("Enemy")
                                .font(.custom("Dorsa", size: relativeFontSize))
                                .foregroundColor(Color(red: 248/255, green: 1, blue: 0))
                                .underline()
                                .fixedSize(horizontal: true, vertical: true)
                                .shadow(color: .white, radius: 1)
                        } else {
                            Text("Enemy")
                                .font(.custom("Dorsa", size: relativeFontSize))
                                .foregroundColor(Color(red: 248/255, green: 1, blue: 0))
                                .fixedSize(horizontal: true, vertical: true)
                        }
                    }
                    .disabled(appState.tabsBlocked)
                    .disabled(self.tabsLockBeforeGameStart)
                    .opacity(appState.tabsBlocked ? 0.5 : 1)
                    //.padding(.horizontal)
                    Spacer()
                    Button {
                        if appState.soundOn {
                            AppState.playSound(sound: "click_sound.wav")
                        }
                        appState.selectedTab = .about
                    } label: {
                        if appState.selectedTab == .about {
                            Text("About")
                                .font(.custom("Dorsa", size: relativeFontSize))
                                .foregroundColor(Color(red: 248/255, green: 1, blue: 0))
                                .underline()
                                .fixedSize(horizontal: true, vertical: true)
                                .shadow(color: .white, radius: 1)
                        } else {
                            Text("About")
                                .font(.custom("Dorsa", size: relativeFontSize))
                                .foregroundColor(Color(red: 248/255, green: 1, blue: 0))
                                .fixedSize(horizontal: true, vertical: true)
                        }
                    }
                    .disabled(appState.tabsBlocked)
                    .opacity(appState.tabsBlocked ? 0.5 : 1)
                    //.padding(.horizontal)
                    Spacer()
                }
                .frame(height: height)
            }
    }
}

#Preview {
    CustomTabView(appState: AppState(), relativeFontSize: 375, height: 100)
}
