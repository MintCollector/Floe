//
//  RaycastSignInNotice.swift
//  Project: Floe
//
//  Copyright (Floe) © 2026 René Jiménez
//  Licensed under the GNU AGPLv3

import AppKit

/// Said before the first sign-in in the browser, which goes through Raycast's sign-in service until Floe has its own.
nonisolated struct RaycastSignInNotice: Sendable {
    static let seenKey = "raycastSignInNoticeSeen"

    var seen: @Sendable () -> Bool = { UserDefaults.standard.bool(forKey: seenKey) }
    var markSeen: @Sendable () -> Void = { UserDefaults.standard.set(true, forKey: seenKey) }
    var asks: @Sendable (String) async -> Bool = { provider in await MainActor.run { ask(provider: provider) } }

    /// True once the user has agreed, now or before. A no is asked again at the next sign-in.
    func allows(provider: String) async -> Bool {
        if seen() {
            return true
        }
        guard await asks(provider) else { return false }
        markSeen()
        return true
    }

    @MainActor
    static func ask(provider: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = String(localized: "Sign in to \(provider) through Raycast?", bundle: .floe, comment: "The placeholder is a service such as Notion. Raycast is another app's name.")
        alert.informativeText = String(localized: "Floe has no sign-in of its own yet. For now the browser returns through raycast.com, and some extensions get their token from Raycast’s servers. This is temporary and may stop working. Floe’s own sign-in service is planned to replace it.", bundle: .floe)
        alert.addButton(withTitle: String(localized: "Continue", bundle: .floe))
        alert.addButton(withTitle: String(localized: "Cancel", bundle: .floe))
        NSApp.activate()
        return ModalGuard.run { alert.runModal() == .alertFirstButtonReturn }
    }
}
