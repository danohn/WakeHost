# WakeHost

WakeHost is a macOS menu bar app for sending Wake-on-LAN requests through OPNsense.

## Features

- Menu bar interface for waking configured hosts
- OPNsense API integration for fetching hosts and sending wake requests
- Credentials stored in Keychain
- Optional Open at Login support

## Requirements

- macOS
- An OPNsense instance with the Wake-on-LAN plugin/API available
- An API key and secret with access to the Wake-on-LAN endpoints

## OPNsense Setup

Before configuring WakeHost, prepare OPNsense:

1. In the OPNsense web interface, open `Firmware > Plugins` and install the `os-wol` plugin.
2. Open `Services > Wake on LAN` and create a static Wake-on-LAN entry for each device you want WakeHost to manage.
3. Open `System > Access > Users` and create a dedicated API user for WakeHost.
4. Assign the privilege `Services: Wake on LAN` to that user.
5. From the user details page, select `Create and download API key for this user`, then use the downloaded key and secret in WakeHost.

## Run Locally

1. Open `WakeHost.xcodeproj` in Xcode.
2. Build and run the `WakeHost` target.
3. Complete the onboarding flow or open `Settings…` from the menu bar app.
4. Enter your OPNsense address, port, API key, and API secret.
5. Save credentials and test the connection.

## Notes

- The app runs as a menu bar utility, so it does not appear in the Dock in normal use.
- For realistic testing of `Open at Login`, use an app build installed in `/Applications`.
