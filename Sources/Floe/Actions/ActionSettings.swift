//
//  ActionSettings.swift
//  Project: Floe
//
//  Copyright (Floe) © 2026 René Jiménez
//  Licensed under the GNU AGPLv3

import Foundation

/// What the user chose for alternative actions. Kept with the other settings, so it is exported and synced with them.
struct ActionSettings: Codable, Equatable {
    /// For each kind of result, by `SubjectKind` raw value.
    var kinds: [String: KindActions] = [:]
    /// Defaults of their own for one app, type of file or site, under an `ActionSubject.scopes` key.
    var scoped: [String: [String]] = [:]
    /// Whether an app's hotkey does what Return does on the app, instead of opening it or hiding it.
    var hotkeysRunDefault = false

    init() {
        // Nothing chosen: every result does what Floe does.
    }

    subscript(kind: SubjectKind) -> KindActions {
        get { kinds[kind.rawValue] ?? KindActions() }
        set { kinds[kind.rawValue] = newValue == KindActions() ? nil : newValue }
    }

    /// The defaults to try for a subject, in order: those of its app, type or site, then its kind's.
    func defaults(for subject: ActionSubject) -> [String] {
        subject.scopes.flatMap { scoped[$0] ?? [] } + self[subject.kind].defaults
    }

    /// Whether anything is chosen for the kind at all, which spares working out its actions when nothing is.
    func isChosen(for subject: ActionSubject) -> Bool {
        !defaults(for: subject).isEmpty
    }

    private enum CodingKeys: String, CodingKey {
        case kinds, scoped, hotkeysRunDefault
    }

    /// A key that is missing reads as nothing chosen, so settings written before a key existed still read.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kinds = try container.decodeIfPresent([String: KindActions].self, forKey: .kinds) ?? [:]
        scoped = try container.decodeIfPresent([String: [String]].self, forKey: .scoped) ?? [:]
        hotkeysRunDefault = try container.decodeIfPresent(Bool.self, forKey: .hotkeysRunDefault) ?? false
    }
}

/// The choices for one kind of result.
struct KindActions: Codable, Equatable {
    /// Tried in order, and the first that is offered is what Return does. Empty is Floe's own.
    var defaults: [String] = []
    /// The Actions menu's order for the actions named. The rest follow, where Floe puts them.
    var order: [String] = []
    /// Left out of the Actions menu. Floe's own default never is.
    var hidden: Set<String> = []
    /// Keys that run an action while a result of the kind is selected.
    var shortcuts: [String: KeyCombination] = [:]

    init() {
        // Nothing chosen.
    }

    private enum CodingKeys: String, CodingKey {
        case defaults, order, hidden, shortcuts
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        defaults = try container.decodeIfPresent([String].self, forKey: .defaults) ?? []
        order = try container.decodeIfPresent([String].self, forKey: .order) ?? []
        hidden = try container.decodeIfPresent(Set<String>.self, forKey: .hidden) ?? []
        shortcuts = try container.decodeIfPresent([String: KeyCombination].self, forKey: .shortcuts) ?? [:]
    }
}
