//
//  PermissionDecisions.swift
//  Project: Floe
//
//  Copyright (Floe) © 2026 René Jiménez
//  Licensed under the GNU AGPLv3

import Foundation

/// Only declines are kept. A grant clears its decline immediately, so losing access can ask again.
struct PermissionDecisions {
    static let shared = PermissionDecisions(defaults: .standard)
    static let declinedKey = "declinedPermissions"

    let defaults: UserDefaults

    private var declined: Set<String> {
        Set(defaults.stringArray(forKey: Self.declinedKey) ?? [])
    }

    func hasUnanswered(_ ungranted: Set<String>) -> Bool {
        OnboardingSequencer.hasUnanswered(ungranted: ungranted, declined: declined)
    }

    func decline(_ ungranted: Set<String>) {
        defaults.set(ungranted.sorted(), forKey: Self.declinedKey)
    }

    func recordGrant(for key: String) {
        var remaining = declined
        guard remaining.remove(key) != nil else { return }
        defaults.set(remaining.sorted(), forKey: Self.declinedKey)
    }
}
