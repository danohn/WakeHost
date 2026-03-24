import SwiftUI

struct SettingsView: View {
    @Environment(\.openWindow) private var openWindow

    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var appPreferences: AppPreferences

    @State private var selectedTab: SettingsTab = .setup
    @State private var draftAddress = ""
    @State private var draftPort = ""
    @State private var draftKey = ""
    @State private var draftSecret = ""
    @State private var isTestingConnection = false
    @State private var testConnectionMessage: String?
    @State private var testConnectionColor: Color = .secondary

    private var openAtLoginBinding: Binding<Bool> {
        Binding(
            get: { appPreferences.opensAtLogin },
            set: { appPreferences.setOpenAtLogin($0) }
        )
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Form {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Address")
                            .font(.headline)
                        TextField(
                            "",
                            text: $draftAddress,
                            prompt: Text("IP address or hostname")
                        )
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .accessibilityLabel("Address")
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Port")
                            .font(.headline)
                        TextField(
                            "",
                            text: $draftPort,
                            prompt: Text("443")
                        )
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 110)
                        .accessibilityLabel("Port")
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("API Key")
                            .font(.headline)
                        SecureField(
                            "",
                            text: $draftKey,
                            prompt: Text("API Key")
                        )
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("API Key")
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("API Secret")
                            .font(.headline)
                        SecureField(
                            "",
                            text: $draftSecret,
                            prompt: Text("API Secret")
                        )
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("API Secret")
                    }

                    if case .success = setupValidation {
                        EmptyView()
                    } else {
                        connectionStatusRow
                    }

                    HStack {
                        Button("Save Settings") {
                            saveSettings()
                        }
                        .disabled(!hasSetupChanges)
                        .controlSize(.small)
                    }

                    HStack {
                        Button("Test Connection") {
                            Task {
                                await testConnection()
                            }
                        }
                        .disabled(isTestingConnection || !canTestConnection)
                        .controlSize(.small)

                        if isTestingConnection {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }

                    if let testConnectionMessage {
                        Text(testConnectionMessage)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(testConnectionColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 6)
            }
            .tabItem {
                Label("Setup", systemImage: "network")
            }
            .tag(SettingsTab.setup)

            Form {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Open at Login", isOn: openAtLoginBinding)

                        Text(appPreferences.openAtLoginSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if let loginItemErrorMessage = appPreferences.loginItemErrorMessage {
                            Text(loginItemErrorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if appPreferences.needsLoginItemApproval {
                            Button("Open Login Items Settings") {
                                appPreferences.openLoginItemsSettings()
                            }
                            .controlSize(.small)
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Button("Reset Setup", role: .destructive) {
                            resetSettingsAndShowOnboarding()
                        }
                        .controlSize(.small)

                        Text("Clears saved connection details and credentials, then reopens setup.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 6)
            }
            .tabItem {
                Label("General", systemImage: "gearshape")
            }
            .tag(SettingsTab.general)
        }
        .frame(width: 460, height: 340)
        .scenePadding()
        .onAppear {
            appPreferences.refreshLoginItemStatus()
            loadDrafts()
        }
    }

    @ViewBuilder
    private var connectionStatusRow: some View {
        let validation = setupValidation

        HStack(alignment: .top, spacing: 10) {
            Image(systemName: validation.systemImage)
                .imageScale(.medium)
                .foregroundStyle(connectionStatusColor(for: validation))

            Text(validation.message)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }

    private var setupValidation: ConnectionValidation {
        SettingsViewModel.validateConnection(
            address: draftAddress,
            port: draftPort,
            key: draftKey,
            secret: draftSecret
        )
    }

    private var isAddressValid: Bool {
        let trimmedAddress = draftAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAddress.isEmpty else { return false }

        let normalizedAddress = trimmedAddress.contains("://") ? trimmedAddress : "https://\(trimmedAddress)"
        guard let components = URLComponents(string: normalizedAddress),
              let host = components.host else {
            return false
        }

        return !host.isEmpty
    }

    private var isPortValid: Bool {
        let trimmedPort = draftPort.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let portValue = Int(trimmedPort) else { return false }
        return (1...65535).contains(portValue)
    }

    private var isKeyValid: Bool {
        !draftKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isSecretValid: Bool {
        !draftSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canTestConnection: Bool {
        isAddressValid && isPortValid && isKeyValid && isSecretValid
    }

    private var hasSetupChanges: Bool {
        draftAddress != viewModel.address ||
        draftPort != viewModel.port ||
        draftKey != viewModel.key ||
        draftSecret != viewModel.secret
    }

    private func connectionStatusColor(for validation: ConnectionValidation) -> Color {
        switch validation {
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }

    private func loadDrafts() {
        draftAddress = viewModel.address
        draftPort = viewModel.port
        draftKey = viewModel.key
        draftSecret = viewModel.secret
    }

    private func saveSettings() {
        viewModel.saveConnection(address: draftAddress, port: draftPort)
        viewModel.saveCredentials(
            key: draftKey.trimmingCharacters(in: .whitespacesAndNewlines),
            secret: draftSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        loadDrafts()
        testConnectionMessage = nil
    }

    private func testConnection() async {
        isTestingConnection = true
        testConnectionMessage = nil

        do {
            try await WOLService(
                address: draftAddress,
                port: draftPort,
                key: draftKey,
                secret: draftSecret
            ).testConnection()
            testConnectionMessage = "Connection succeeded."
            testConnectionColor = .green
        } catch {
            testConnectionMessage = error.localizedDescription
            testConnectionColor = .red
        }

        isTestingConnection = false
    }

    private func resetSettingsAndShowOnboarding() {
        viewModel.clearConnection()
        viewModel.clearCredentials()
        loadDrafts()
        testConnectionMessage = nil
        appPreferences.resetOnboarding()
        NSApplication.shared.activate(ignoringOtherApps: true)
        openWindow(id: AppSceneID.onboarding)
    }
}

private enum SettingsTab: Hashable {
    case setup
    case general
}

#Preview {
    SettingsView(viewModel: SettingsViewModel(), appPreferences: AppPreferences())
}
