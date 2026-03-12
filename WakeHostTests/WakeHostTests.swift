//
//  WakeHostTests.swift
//  WakeHostTests
//
//  Created by Daniel on 12/3/2026.
//

import Testing
@testable import WakeHost

struct WakeHostTests {
    @MainActor @Test func connectionValidationRequiresAddress() async throws {
        let validation = SettingsViewModel.validateConnection(
            address: "",
            port: "7443",
            key: "key",
            secret: "secret"
        )

        #expect(validation == .warning("Enter your OPNsense IP address or hostname."))
    }

    @MainActor @Test func connectionValidationRejectsInvalidAddress() async throws {
        let validation = SettingsViewModel.validateConnection(
            address: "https://",
            port: "7443",
            key: "key",
            secret: "secret"
        )

        #expect(validation == .error("Enter a valid IP address or hostname."))
    }

    @MainActor @Test func connectionValidationRequiresPort() async throws {
        let validation = SettingsViewModel.validateConnection(
            address: "opnsense.example.com",
            port: "",
            key: "key",
            secret: "secret"
        )

        #expect(validation == .warning("Enter the OPNsense port."))
    }

    @MainActor @Test func connectionValidationRejectsOutOfRangePort() async throws {
        let validation = SettingsViewModel.validateConnection(
            address: "opnsense.example.com",
            port: "70000",
            key: "key",
            secret: "secret"
        )

        #expect(validation == .error("Use a port between 1 and 65535."))
    }

    @MainActor @Test func connectionValidationRequiresCredentials() async throws {
        let validation = SettingsViewModel.validateConnection(
            address: "opnsense.example.com",
            port: "7443",
            key: "",
            secret: ""
        )

        #expect(validation == .warning("Add your API key and secret in Credentials."))
    }

    @MainActor @Test func connectionValidationAcceptsValidConfiguration() async throws {
        let validation = SettingsViewModel.validateConnection(
            address: "opnsense.example.com",
            port: "7443",
            key: "key",
            secret: "secret"
        )

        #expect(validation == .success("Ready to connect."))
    }
}
