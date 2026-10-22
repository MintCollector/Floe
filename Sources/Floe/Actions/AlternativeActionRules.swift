//
//  AlternativeActionRules.swift
//  Project: Floe
//
//  Copyright (Floe) © 2026 René Jiménez
//  Licensed under the GNU AGPLv3

import AppKit

/// The decisions behind alternative actions, as plain functions of the rows on offer and what the user chose:
/// what Return runs, how the Actions menu reads, and what keys on the selected row run.
enum AlternativeActionRules {
    /// Floe's own Return on a result. A default can name it to come back to what Floe does.
    static let floesOwn = "floe.default"

    /// Keys Floe already gives a meaning to on a selected row, which a shortcut may not take.
    static let reservedKeys: [KeyCombination] = [
        KeyCombination(key: .returnKey, modifiers: []),
        KeyCombination(key: .returnKey, modifiers: .command),
        KeyCombination(key: .returnKey, modifiers: .option),
        KeyCombination(key: .returnKey, modifiers: .shift),
        KeyCombination(key: .k, modifiers: .command),
        KeyCombination(key: .y, modifiers: .command),
        KeyCombination(key: .comma, modifiers: .command),
        KeyCombination(key: .f, modifiers: [.command, .shift]),
        KeyCombination(key: .c, modifiers: [.command, .shift]),
        KeyCombination(key: .tab, modifiers: []),
    ]

    /// The rows on offer by id, those in submenus included. Where two share an id, the first is kept.
    static func offered(_ actions: [ItemAction?]) -> [String: ItemAction] {
        var found: [String: ItemAction] = [:]
        var pending = actions.compactMap(\.self)
        while !pending.isEmpty {
            let action = pending.removeFirst()
            if let id = action.id, found[id] == nil {
                found[id] = action
            }
            pending.insert(contentsOf: action.children, at: 0)
        }
        return found
    }

    /// What Return runs: the first default on offer. Nil when that is Floe's own, or when none of them is on offer,
    /// so Return does what Floe does. `offered` is asked lazily, so a default that is a script spares building Floe's rows.
    static func primary(_ defaults: [String], offered: (String) -> ItemAction?) -> ItemAction? {
        for id in defaults {
            if id == floesOwn {
                return nil
            }
            if let action = offered(id) {
                return action
            }
        }
        return nil
    }

    /// The Actions menu after the Return row. `own` is Floe's own Return, listed first when a default took its place;
    /// `extra` are the user's actions on the result. The primary is left out, being the Return row already. Chosen
    /// rows come first in the chosen order, hidden ones are left out, and each row shows its keys.
    static func arranged(_ actions: [ItemAction?], extra: [ItemAction], own: ItemAction?, primaryID: String?, choices: KindActions) -> [ItemAction?] {
        guard own != nil || !extra.isEmpty || choices != KindActions() else { return actions }
        var rows: [ItemAction?] = [nil]
        rows += ([own].compactMap(\.self) + extra).map { Optional($0) }
        rows.append(nil)
        rows += actions
        rows = rows.filter { row in
            guard let id = row?.id else { return true }
            return id != primaryID && (id == floesOwn || !choices.hidden.contains(id))
        }
        let moved = choices.order.compactMap { id in rows.lazy.compactMap(\.self).first { $0.id == id } }
        if !moved.isEmpty {
            let movedIDs = Set(moved.compactMap(\.id))
            rows = [nil] + moved.map { Optional($0) } + rows.filter { row in row?.id.map { !movedIDs.contains($0) } ?? true }
        }
        return tidied(rows.map { $0.map { showingKeys($0, choices.shortcuts) } })
    }

    /// The action keys on the selected row run, when they are one of the kind's shortcuts.
    static func action(for keys: KeyCombination, choices: KindActions, offered: (String) -> ItemAction?) -> ItemAction? {
        choices.shortcuts.keys.sorted().lazy.filter { choices.shortcuts[$0] == keys }.compactMap(offered).first
    }

    /// One separator at most between groups, and none at the end. A separator at the start stays: it parts the
    /// rows from the Return row above them.
    static func tidied(_ rows: [ItemAction?]) -> [ItemAction?] {
        var result: [ItemAction?] = []
        for row in rows where row != nil || result.last.map({ $0 != nil }) ?? true {
            result.append(row)
        }
        while let last = result.last, last == nil {
            result.removeLast()
        }
        return result
    }

    private static func showingKeys(_ action: ItemAction, _ shortcuts: [String: KeyCombination]) -> ItemAction {
        var action = action
        if let id = action.id, let keys = shortcuts[id] {
            action.shortcut = keys
        }
        action.children = action.children.map { showingKeys($0, shortcuts) }
        return action
    }
}
