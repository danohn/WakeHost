//
//  WakeHostApp.swift
//  WakeHost
//
//  Created by Daniel on 12/3/2026.
//

import SwiftUI

enum AppSceneID {
    static let onboarding = "onboarding"
}

@main
struct WakeHostApp: App {
    @StateObject private var appPreferences = AppPreferences()
    @StateObject private var settingsViewModel = SettingsViewModel()

    var body: some Scene {
        MenuBarExtra("WakeHost", systemImage: "power.circle") {
            ContentView(settingsViewModel: settingsViewModel, appPreferences: appPreferences)
        }
        .menuBarExtraStyle(.window)

        Window("Welcome to WakeHost", id: AppSceneID.onboarding) {
            OnboardingView(viewModel: settingsViewModel, appPreferences: appPreferences)
        }
        .defaultLaunchBehavior(appPreferences.hasCompletedOnboarding ? .suppressed : .presented)
        .restorationBehavior(.disabled)
        .windowResizability(.contentSize)

        Settings {
            SettingsView(viewModel: settingsViewModel, appPreferences: appPreferences)
        }
    }
}
