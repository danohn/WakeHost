import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismissWindow) private var dismissWindow

    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var appPreferences: AppPreferences

    @FocusState private var focusedField: OnboardingField?
    @State private var draftAddress = ""
    @State private var draftPort = ""
    @State private var draftKey = ""
    @State private var draftSecret = ""
    @State private var isTestingConnection = false
    @State private var onboardingMessage: String?
    @State private var onboardingMessageColor: Color = .secondary

    private var onboardingValidation: ConnectionValidation {
        SettingsViewModel.validateConnection(
            address: draftAddress,
            port: draftPort,
            key: draftKey,
            secret: draftSecret
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Set Up WakeHost")
                    .font(.largeTitle.weight(.semibold))

                Text("Enter your OPNsense connection details to get started.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("Address", isValid: isAddressValid && focusedField != .address)
                    TextField(
                        "",
                        text: $draftAddress,
                        prompt: Text("IP address or hostname")
                    )
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .accessibilityLabel("Address")
                    .focused($focusedField, equals: .address)
                }

                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("Port", isValid: isPortValid && focusedField != .port)
                    TextField(
                        "",
                        text: $draftPort,
                        prompt: Text("443")
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 110)
                    .accessibilityLabel("Port")
                    .focused($focusedField, equals: .port)
                }

                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("API Key", isValid: isKeyValid && focusedField != .key)
                    SecureField(
                        "",
                        text: $draftKey,
                        prompt: Text("API Key")
                    )
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("API Key")
                    .focused($focusedField, equals: .key)
                }

                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("API Secret", isValid: isSecretValid && focusedField != .secret)
                    SecureField(
                        "",
                        text: $draftSecret,
                        prompt: Text("API Secret")
                    )
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("API Secret")
                    .focused($focusedField, equals: .secret)
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

                VStack(alignment: .leading, spacing: 4) {
                    if let onboardingMessage {
                        Text(onboardingMessage)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(onboardingMessageColor)
                    }
                    Text("You can update these settings later from WakeHost Settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            HStack {
                Spacer()

                Button("Finish Setup") {
                    finishSetup()
                }
                .buttonStyle(.glassProminent)
            }
        }
        .padding(24)
        .frame(width: 460)
        .onAppear {
            loadDrafts()
        }
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

    private func validationColor(for validation: ConnectionValidation) -> Color {
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
        onboardingMessage = nil
    }

    private func saveOnboardingSettings() {
        viewModel.saveConnection(address: draftAddress, port: draftPort)
        viewModel.saveCredentials(
            key: draftKey.trimmingCharacters(in: .whitespacesAndNewlines),
            secret: draftSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func finishSetup() {
        focusedField = nil

        switch onboardingValidation {
        case .success:
            saveOnboardingSettings()
            appPreferences.completeOnboarding()
            dismissWindow(id: AppSceneID.onboarding)
        case .warning, .error:
            onboardingMessage = onboardingValidation.message
            onboardingMessageColor = validationColor(for: onboardingValidation)
        }
    }

    private func testConnection() async {
        focusedField = nil
        onboardingMessage = nil
        isTestingConnection = true

        do {
            try await WOLService(
                address: draftAddress,
                port: draftPort,
                key: draftKey,
                secret: draftSecret
            ).testConnection()
            onboardingMessage = "Connection succeeded."
            onboardingMessageColor = .green
        } catch {
            onboardingMessage = error.localizedDescription
            onboardingMessageColor = .red
        }

        isTestingConnection = false
    }

    @ViewBuilder
    private func fieldLabel(_ title: String, isValid: Bool) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.headline)

            if isValid {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)
            }
        }
    }
}

private enum OnboardingField: Hashable {
    case address
    case port
    case key
    case secret
}

#Preview {
    OnboardingView(viewModel: SettingsViewModel(), appPreferences: AppPreferences())
}
