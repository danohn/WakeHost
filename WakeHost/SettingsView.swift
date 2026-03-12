import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var appPreferences: AppPreferences

    @State private var selectedTab: SettingsTab = .connection
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
                Section {
                    LabeledContent("Address") {
                        TextField("opnsense.example.com", text: $viewModel.address)
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 260)
                            .autocorrectionDisabled()
                    }

                    LabeledContent("Port") {
                        TextField("7443", text: $viewModel.port)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                }

                Section {
                    connectionStatusRow

                    HStack {
                        Button("Test Connection") {
                            Task {
                                await testConnection()
                            }
                        }
                        .disabled(isTestingConnection)

                        if isTestingConnection {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }

                    if let testConnectionMessage {
                        Text(testConnectionMessage)
                            .font(.caption)
                            .foregroundStyle(testConnectionColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .tabItem {
                Label("Connection", systemImage: "network")
            }
            .tag(SettingsTab.connection)

            Form {
                Section {
                    LabeledContent("API Key") {
                        SecureField("Required", text: $draftKey)
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 260)
                    }

                    LabeledContent("API Secret") {
                        SecureField("Required", text: $draftSecret)
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 260)
                    }
                }

                Section {
                    Text("WakeHost stores your API credentials securely in Keychain.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button("Save Credentials") {
                        saveCredentials()
                    }
                    .disabled(!hasCredentialChanges)

                    Button("Clear Credentials", role: .destructive) {
                        clearCredentials()
                    }
                }
            }
            .tabItem {
                Label("Credentials", systemImage: "key.fill")
            }
            .tag(SettingsTab.credentials)

            Form {
                Section {
                    Toggle("Open at Login", isOn: openAtLoginBinding)

                    Text(appPreferences.openAtLoginSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let loginItemErrorMessage = appPreferences.loginItemErrorMessage {
                    Section {
                        Text(loginItemErrorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if appPreferences.needsLoginItemApproval {
                    Section {
                        Button("Open Login Items Settings") {
                            appPreferences.openLoginItemsSettings()
                        }
                    }
                }
            }
            .tabItem {
                Label("General", systemImage: "gearshape")
            }
            .tag(SettingsTab.general)
        }
        .frame(width: 460, height: 300)
        .scenePadding()
        .onAppear {
            appPreferences.refreshLoginItemStatus()
            loadCredentialDrafts()
        }
    }

    @ViewBuilder
    private var connectionStatusRow: some View {
        let validation = viewModel.connectionValidation

        HStack(alignment: .top, spacing: 10) {
            Image(systemName: validation.systemImage)
                .imageScale(.medium)
                .foregroundStyle(connectionStatusColor(for: validation))

            VStack(alignment: .leading, spacing: 4) {
                Text(validation.message)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("Used to reach your OPNsense server from the menu bar utility.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
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

    private func testConnection() async {
        isTestingConnection = true
        testConnectionMessage = nil

        do {
            try await WOLService(viewModel: viewModel).testConnection()
            testConnectionMessage = "Connection succeeded."
            testConnectionColor = .green
        } catch {
            testConnectionMessage = error.localizedDescription
            testConnectionColor = .red
        }

        isTestingConnection = false
    }

    private var hasCredentialChanges: Bool {
        draftKey != viewModel.key || draftSecret != viewModel.secret
    }

    private func loadCredentialDrafts() {
        draftKey = viewModel.key
        draftSecret = viewModel.secret
    }

    private func saveCredentials() {
        viewModel.saveCredentials(
            key: draftKey.trimmingCharacters(in: .whitespacesAndNewlines),
            secret: draftSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func clearCredentials() {
        viewModel.clearCredentials()
        loadCredentialDrafts()
    }
}

private enum SettingsTab: Hashable {
    case connection
    case credentials
    case general
}

#Preview {
    SettingsView(viewModel: SettingsViewModel(), appPreferences: AppPreferences())
}
