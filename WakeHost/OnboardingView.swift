import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openSettings) private var openSettings

    @ObservedObject var appPreferences: AppPreferences

    private var openAtLoginBinding: Binding<Bool> {
        Binding(
            get: { appPreferences.opensAtLogin },
            set: { appPreferences.setOpenAtLogin($0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "power.circle.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(.green)

                Text("Welcome to WakeHost")
                    .font(.largeTitle.weight(.semibold))

                Text("WakeHost lives in your menu bar so you can wake machines without keeping a window open.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 14) {
                OnboardingStep(
                    systemImage: "menubar.rectangle",
                    title: "Use the menu bar",
                    description: "Click the WakeHost icon in the menu bar to refresh hosts and send wake packets."
                )
                OnboardingStep(
                    systemImage: "gearshape",
                    title: "Add your OPNsense connection",
                    description: "Enter the server address, port, API key, and secret in Settings before you fetch hosts."
                )
                OnboardingStep(
                    systemImage: "person.crop.circle.badge.checkmark",
                    title: "Optional: launch at login",
                    description: "Turn on Open at Login if you want WakeHost ready in the menu bar after every sign-in."
                )
            }

            VStack(alignment: .leading, spacing: 12) {
                Toggle("Open at Login", isOn: openAtLoginBinding)
                    .disabled(!appPreferences.canToggleOpenAtLogin)

                Text(appPreferences.openAtLoginSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let loginItemErrorMessage = appPreferences.loginItemErrorMessage {
                    Text(loginItemErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if appPreferences.needsLoginItemApproval {
                    Button("Open Login Items Settings") {
                        appPreferences.openLoginItemsSettings()
                    }
                }
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            HStack {
                Button("Open Settings…") {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    openSettings()
                }

                Spacer()

                Button("Continue") {
                    appPreferences.completeOnboarding()
                    dismissWindow(id: AppSceneID.onboarding)
                }
                .buttonStyle(.glassProminent)
            }
        }
        .padding(24)
        .frame(width: 520)
        .onAppear {
            appPreferences.refreshLoginItemStatus()
        }
    }
}

private struct OnboardingStep: View {
    let systemImage: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .frame(width: 28)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    OnboardingView(appPreferences: AppPreferences())
}
