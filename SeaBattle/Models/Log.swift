//
//  Log.swift
//  SeaBattle
//
//  R0.2: unified logging. Replaces the scattered `print` calls in error paths —
//  `print` is invisible in a shipped build, `Logger` shows up in Console.app and
//  in the Xcode debug console with a subsystem and category.
//

import OSLog

enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "nl.brapps.SeaBattle"

    static let audio = Logger(subsystem: subsystem, category: "audio")
    static let store = Logger(subsystem: subsystem, category: "store")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let purchase = Logger(subsystem: subsystem, category: "purchase")
    static let sync = Logger(subsystem: subsystem, category: "sync")
}
