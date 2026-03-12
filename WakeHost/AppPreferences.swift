import Combine
import Foundation
import OSLog
import ServiceManagement

@MainActor
final class AppPreferences: ObservableObject {
    private static let logger = Logger(subsystem: "com.dohnesorge.WakeHost", category: "app-preferences")

    @Published var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: Self.hasCompletedOnboardingKey)
        }
    }

    @Published private(set) var loginItemStatus: SMAppService.Status
    @Published var loginItemErrorMessage: String?

    private static let hasCompletedOnboardingKey = "has_completed_onboarding"
    private static let forceOnboardingLaunchArgument = "--uitest-force-onboarding"
    private let loginItemService = SMAppService.mainApp

    init() {
        let defaultsValue = UserDefaults.standard.bool(forKey: Self.hasCompletedOnboardingKey)
        let forceOnboarding = ProcessInfo.processInfo.arguments.contains(Self.forceOnboardingLaunchArgument)
        hasCompletedOnboarding = forceOnboarding ? false : defaultsValue
        loginItemStatus = loginItemService.status
    }

    var opensAtLogin: Bool {
        switch loginItemStatus {
        case .enabled, .requiresApproval:
            return true
        case .notRegistered, .notFound:
            return false
        @unknown default:
            return false
        }
    }

    var openAtLoginSummary: String {
        switch loginItemStatus {
        case .enabled:
            return "WakeHost will launch automatically when you log in."
        case .requiresApproval:
            return "Finish enabling WakeHost in System Settings > General > Login Items."
        case .notFound:
            return "WakeHost isn’t currently registered to open at login."
        case .notRegistered:
            return "WakeHost launches manually until you turn on Open at Login."
        @unknown default:
            return "WakeHost can launch automatically when you log in."
        }
    }

    var needsLoginItemApproval: Bool {
        loginItemStatus == .requiresApproval
    }

    var canToggleOpenAtLogin: Bool {
        true
    }

    func refreshLoginItemStatus() {
        loginItemStatus = loginItemService.status
        Self.logger.info("Login item status refreshed: \(String(describing: self.loginItemStatus), privacy: .public)")
    }

    func setOpenAtLogin(_ enabled: Bool) {
        loginItemErrorMessage = nil

        do {
            if enabled {
                try loginItemService.register()
                Self.logger.info("Requested Open at Login registration")
            } else {
                try loginItemService.unregister()
                Self.logger.info("Requested Open at Login unregistration")
            }
        } catch {
            Self.logger.error("Failed to update Open at Login. Error: \(error.localizedDescription, privacy: .public)")
            loginItemErrorMessage = error.localizedDescription
        }

        refreshLoginItemStatus()
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
    }

    func resetOnboarding() {
        hasCompletedOnboarding = false
    }
}
