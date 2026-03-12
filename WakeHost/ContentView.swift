//
//  ContentView.swift
//  WakeHost
//
//  Created by Daniel on 12/3/2026.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow

    @ObservedObject var settingsViewModel: SettingsViewModel
    @ObservedObject var appPreferences: AppPreferences

    @State private var hosts: [WOLHost] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isWakingHostID: String?
    @State private var statusMessage: StatusMessage?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("WakeHost")
                        .font(.headline)
                    Text("Wake-on-LAN Hosts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            if let statusMessage {
                messageChip(text: statusMessage.text, color: statusMessage.color)
            }

            if !appPreferences.hasCompletedOnboarding {
                onboardingState
            } else if let errorMessage {
                messageChip(text: errorMessage, color: .red)
            } else if hosts.isEmpty {
                Text("No hosts found.")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(hosts) { host in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(host.displayName)
                                    Text(host.mac)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if isWakingHostID == host.id {
                                    ProgressView()
                                        .frame(width: 56)
                                } else {
                                    Button("Wake") {
                                        Task {
                                            await wake(host)
                                        }
                                    }
                                    .buttonStyle(.glassProminent)
                                    .controlSize(.small)
                                    .frame(width: 56)
                                    .disabled(isLoading)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: hostListHeight)
            }

            Divider()

            GlassEffectContainer(spacing: 18) {
                HStack(spacing: 10) {
                    Button {
                        Task {
                            await fetchHosts()
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                    .buttonStyle(.glassProminent)

                    Spacer()

                    Button {
                        NSApplication.shared.activate(ignoringOtherApps: true)
                        openSettings()
                    } label: {
                        Label("Settings…", systemImage: "gearshape")
                    }
                    .buttonStyle(.glass)

                    Button {
                        NSApplication.shared.terminate(nil)
                    } label: {
                        Label("Quit", systemImage: "power")
                    }
                    .buttonStyle(.glass)
                }
            }
        }
        .padding()
        .frame(width: 360)
        .task(id: settingsViewModel.connectionFingerprint) {
            guard appPreferences.hasCompletedOnboarding else {
                hosts = []
                errorMessage = nil
                return
            }
            await fetchHosts()
        }
    }

    private var onboardingState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Finish setup to load your Wake-on-LAN hosts.")
                .foregroundStyle(.secondary)

            Button("Open Setup") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openWindow(id: AppSceneID.onboarding)
            }
            .buttonStyle(.glass)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }

    private var hostListHeight: CGFloat {
        let rowHeight: CGFloat = 36
        let rowSpacing: CGFloat = 10
        let contentHeight = CGFloat(hosts.count) * rowHeight + CGFloat(max(hosts.count - 1, 0)) * rowSpacing + 4
        return min(max(contentHeight, rowHeight), 220)
    }

    private func fetchHosts() async {
        isLoading = true
        errorMessage = nil

        do {
            hosts = try await WOLService(viewModel: settingsViewModel).fetchHosts()
            if hosts.isEmpty {
                statusMessage = nil
            }
        } catch {
            hosts = []
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func wake(_ host: WOLHost) async {
        isWakingHostID = host.id
        statusMessage = nil

        do {
            try await WOLService(viewModel: settingsViewModel).wakeHost(uuid: host.id)
            statusMessage = StatusMessage(
                text: "Wake packet sent to \(host.displayName).",
                color: .green
            )
        } catch {
            statusMessage = StatusMessage(
                text: error.localizedDescription,
                color: .red
            )
        }

        isWakingHostID = nil
    }

    private func messageChip(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .glassEffect(.regular.tint(color.opacity(0.18)), in: .rect(cornerRadius: 12))
    }
}

private struct StatusMessage {
    let text: String
    let color: Color
}

#Preview {
    ContentView(settingsViewModel: SettingsViewModel(), appPreferences: AppPreferences())
}
