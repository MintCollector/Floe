//
//  LaunchAtLoginToggle.swift
//  Project: Floe
//
//  Copyright (Floe) © 2026 René Jiménez
//  Licensed under the GNU AGPLv3

import ServiceManagement
import SwiftUI

/// The General page's switch. macOS takes about 90 ms to say whether Floe is a login item, so it is asked off the main thread.
struct LaunchAtLoginToggle: View {
    /// The last answer, which a page opened again shows at once.
    private static var known = false

    @ObservedObject var settings: AppSettings
    @State private var isOn = LaunchAtLoginToggle.known

    var body: some View {
        Toggle("Launch at Login", isOn: Binding(get: { isOn }, set: { wanted in
            settings.setLaunchAtLogin(wanted)
            isOn = wanted
            Task { await read() }
        }))
        .task { await read() }
    }

    /// Asked again after a change too: macOS may have refused it.
    private func read() async {
        let answer = await Task.detached { SMAppService.mainApp.status == .enabled }.value
        Self.known = answer
        isOn = answer
    }
}
