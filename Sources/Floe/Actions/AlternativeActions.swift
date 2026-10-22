//
//  AlternativeActions.swift
//  Project: Floe
//
//  Copyright (Floe) © 2026 René Jiménez
//  Licensed under the GNU AGPLv3

import AppKit

/// Alternative actions on the launcher's rows: what Return does on an app, a file or folder, or a web address, what
/// the Actions menu lists and in what order, and keys on the selected row. They are chosen in Settings for each kind
/// of result, and script commands with `@floe.` lines are actions of the user's own.
final class AlternativeActions {
    /// What the feature asks of the launcher.
    struct Host {
        var settings: () -> ActionSettings = { ActionSettings() }
        var scripts: () -> [ScriptCommand] = { [] }
        /// Floe's own rows of a result's Actions menu, after its Return row.
        var floeActions: (RootItem) -> [ItemAction?] = { _ in [] }
        /// What Floe's own Return on a result is called.
        var floeTitle: (RootItem) -> String = { _ in "" }
        /// Does what Floe's own Return does.
        var openAsFloeDoes: (RootItem) -> Void = { _ in
            // Set by LauncherFeatures.
        }

        /// Counts the result as used and keeps the search, as opening it would.
        var used: (RootItem) -> Void = { _ in
            // Set by LauncherFeatures.
        }

        var showHUD: (String) -> Void = { _ in
            // Set by LauncherFeatures.
        }

        /// Hides the panel and goes back to the root.
        var leave: () -> Void = {
            // Set by LauncherFeatures.
        }
    }

    var host = Host()
    var runScript: @Sendable (ScriptCommand, [String: String]) async throws -> ShellResult = {
        try await ScriptRunner.run($0, arguments: [], environment: $1)
    }

    var showOutput: (_ title: String, _ output: String) -> Void = { ScriptOutputWindow.show(title: $0, output: $1) }
    var runningApps: () -> [NSRunningApplication] = { NSWorkspace.shared.runningApplications }

    // MARK: - What the launcher asks

    /// Return on a result, when a default other than Floe's own applies to it. False leaves the result to Floe.
    func open(_ item: RootItem, flags: NSEvent.ModifierFlags) -> Bool {
        // Return with keys held means what Floe gives it on the row: a terminal for a shell command, Copy for an emoji.
        guard flags.isEmpty, let action = primary(for: item) else { return false }
        host.used(item)
        action.run()
        return true
    }

    /// What Return does on a result, when it is not Floe's own.
    func returnTitle(for item: RootItem) -> String? {
        primary(for: item)?.title
    }

    /// The Actions menu after the Return row, with the user's actions and choices applied to Floe's own rows.
    func arranged(_ actions: [ItemAction?], for item: RootItem) -> [ItemAction?] {
        guard let subject = subject(for: item) else { return actions }
        let settings = host.settings()
        let choices = settings[subject.kind]
        var extra = scriptActions(for: subject)
        // Open or Hide is listed once something is chosen for apps, so a menu nobody changed stays as Floe has it.
        if settings.isChosen(for: subject) || choices != KindActions(), let toggle = toggleAction(for: item, subject: subject) {
            extra.append(toggle)
        }
        let primary = primary(for: item, subject: subject, offered: AlternativeActionRules.offered(actions + extra.map { Optional($0) }))
        let own = primary == nil ? nil : ownAction(for: item)
        return AlternativeActionRules.arranged(actions, extra: extra, own: own, primaryID: primary?.id, choices: choices)
    }

    /// Keys on the selected row: the action they are a shortcut for, if any. False leaves the keys to Floe.
    func handleKey(_ keyCode: UInt16, flags: NSEvent.ModifierFlags, on item: RootItem) -> Bool {
        guard let subject = subject(for: item) else { return false }
        let choices = host.settings()[subject.kind]
        guard !choices.shortcuts.isEmpty else { return false }
        let keys = KeyCombination(key: KeyCode(rawValue: Int(keyCode)), modifiers: Modifiers(nsEventFlags: flags))
        let offered = offered(for: item, subject: subject)
        guard let action = AlternativeActionRules.action(for: keys, choices: choices, offered: { offered[$0] }) else { return false }
        host.used(item)
        action.run()
        return true
    }

    /// An app's hotkey, when settings say it does what Return does. False leaves the hotkey to open or hide the app.
    func runHotkey(for app: AppEntry) -> Bool {
        guard host.settings().hotkeysRunDefault, let action = primary(for: .app(app)) else { return false }
        host.used(.app(app))
        action.run()
        return true
    }

    // MARK: - Working it out

    /// What a result is about, for the results alternative actions apply to.
    func subject(for item: RootItem) -> ActionSubject? {
        switch item {
        case let .app(app):
            let target = app.url.standardizedFileURL
            let isRunning = runningApps().contains { $0.bundleURL?.standardizedFileURL == target }
            return ActionSubject(kind: .app, title: app.name, url: app.url, bundleIdentifier: Bundle(url: app.url)?.bundleIdentifier, isRunning: isRunning)
        case let .file(file):
            let values = try? file.url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey, .typeIdentifierKey])
            let isFolder = values?.isDirectory == true && values?.isPackage != true
            return ActionSubject(kind: isFolder ? .folder : .file, title: file.name, url: file.url, contentType: file.contentType ?? values?.typeIdentifier)
        case let .webAddress(address):
            return ActionSubject(kind: .url, title: address.text, url: address.url)
        case let .bookmark(bookmark):
            return ActionSubject(kind: .url, title: bookmark.title, url: bookmark.url)
        case let .browserTab(.tab(tab)):
            return URL(string: tab.url).map { ActionSubject(kind: .url, title: tab.title, url: $0) }
        default:
            return nil
        }
    }

    /// The user's script commands that act on this result, as rows of its Actions menu.
    func scriptActions(for subject: ActionSubject) -> [ItemAction] {
        host.scripts().filter { $0.actionInfo?.accepts(subject) == true }.map { script in
            ItemAction(title: script.title, symbol: "terminal", id: script.actionID) { [weak self] in
                self?.run(script, on: subject)
            }
        }
    }

    /// The action Return runs on a result, when the user chose one other than Floe's own and it is on offer.
    private func primary(for item: RootItem) -> ItemAction? {
        guard let subject = subject(for: item), host.settings().isChosen(for: subject) else { return nil }
        // Floe's rows are only built when a default asks for one, since a default that is a script needs none of them.
        var built: [String: ItemAction]?
        return primary(for: item, subject: subject) { id in
            if id.hasPrefix("script:") {
                return scriptActions(for: subject).first { $0.id == id }
            }
            if built == nil {
                built = AlternativeActionRules.offered(host.floeActions(item) + [toggleAction(for: item, subject: subject)])
            }
            return built?[id]
        }
    }

    private func primary(for item: RootItem, subject: ActionSubject, offered: [String: ItemAction]) -> ItemAction? {
        primary(for: item, subject: subject) { offered[$0] }
    }

    private func primary(for _: RootItem, subject: ActionSubject, offered: (String) -> ItemAction?) -> ItemAction? {
        AlternativeActionRules.primary(host.settings().defaults(for: subject), offered: offered)
    }

    /// Every action on offer for a result, Floe's own Return included, for keys to find theirs.
    private func offered(for item: RootItem, subject: ActionSubject) -> [String: ItemAction] {
        var rows = host.floeActions(item) + scriptActions(for: subject).map { Optional($0) }
        rows.append(ownAction(for: item))
        rows.append(toggleAction(for: item, subject: subject))
        return AlternativeActionRules.offered(rows)
    }

    /// Floe's own Return, as a row that stays reachable when a default took its place.
    private func ownAction(for item: RootItem) -> ItemAction {
        ItemAction(title: host.floeTitle(item), symbol: "arrow.uturn.backward", id: AlternativeActionRules.floesOwn) { [host] in
            host.openAsFloeDoes(item)
        }
    }

    /// Hide an app that is in front, or open it: what an app's hotkey does, offered as an action of its own.
    private func toggleAction(for item: RootItem, subject: ActionSubject) -> ItemAction? {
        guard case let .app(app) = item else { return nil }
        let target = subject.url.standardizedFileURL
        return ItemAction(title: String(localized: "Open or Hide", bundle: .floe, comment: "An action on an app: hide it when it is in front, or else open it."), symbol: "rectangle.on.rectangle", id: "toggle") { [host] in
            host.leave()
            if let front = NSWorkspace.shared.frontmostApplication, front.bundleURL?.standardizedFileURL == target {
                front.hide()
            } else {
                NSWorkspace.shared.openWithoutWaiting(app.url)
            }
        }
    }

    // MARK: - Scripts

    /// Runs a script on a result once the panel is gone. Output follows the script's mode, as a script command's does.
    private func run(_ script: ScriptCommand, on subject: ActionSubject) {
        host.leave()
        Task { [weak self, runScript] in
            let result: ShellResult
            do {
                result = try await runScript(script, subject.environment)
            } catch {
                await MainActor.run { [weak self] in
                    self?.host.showHUD(String(localized: "\(script.title) failed: \(error.localizedDescription)", bundle: .floe, comment: "The first placeholder is the name of a script, the second is the reason."))
                }
                return
            }
            await MainActor.run { [weak self] in self?.show(result, of: script) }
        }
    }

    private func show(_ result: ShellResult, of script: ScriptCommand) {
        guard result.succeeded else {
            let line = ScriptRunner.lastLine(result.errorOutput) ?? ScriptRunner.lastLine(result.output)
                ?? String(localized: "exit code \(result.status)", bundle: .floe, comment: "The reason a script failed, when it printed nothing. The placeholder is a number.")
            host.showHUD(String(localized: "\(script.title) failed: \(line)", bundle: .floe, comment: "The first placeholder is the name of a script, the second is the reason."))
            return
        }
        switch script.mode {
        case .silent:
            break
        case .inline, .compact:
            if let line = ScriptRunner.lastLine(result.output) {
                host.showHUD(line)
            }
        case .fullOutput:
            showOutput(script.title, result.trimmedOutput)
        }
    }
}
