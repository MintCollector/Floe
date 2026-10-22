//
//  AlternativeActionsSettingsSection.swift
//  Project: Floe
//
//  Copyright (Floe) © 2026 René Jiménez
//  Licensed under the GNU AGPLv3

import AppKit
import SwiftUI
import ThawUI

/// One action a kind of result can have, as Settings lists it.
struct ActionChoice: Identifiable, Equatable {
    let id: String
    let title: String
}

extension ActionChoice {
    /// Floe's own Return, which every kind has.
    static var floesOwn: ActionChoice {
        ActionChoice(id: AlternativeActionRules.floesOwn, title: String(localized: "What Floe Does", bundle: .floe, comment: "A choice for what Return does on a result: Floe's own action, such as opening it."))
    }

    /// Floe's actions for a kind of result, the ones with an id in its Actions menu. Rows that depend on the result,
    /// such as the apps in Open With, are left out; a script reaches those.
    static func builtIns(for kind: SubjectKind) -> [ActionChoice] {
        let copies = [
            ActionChoice(id: "copyPath", title: String(localized: "Copy Path", bundle: .floe)),
            ActionChoice(id: "copyName", title: String(localized: "Copy Name", bundle: .floe)),
        ]
        let trash = ActionChoice(id: "moveToTrash", title: String(localized: "Move to Trash…", bundle: .floe))
        let finder = ActionChoice(id: "showInFinder", title: String(localized: "Show in Finder", bundle: .floe))
        switch kind {
        case .app:
            return [
                ActionChoice(id: "toggle", title: String(localized: "Open or Hide", bundle: .floe, comment: "An action on an app: hide it when it is in front, or else open it.")),
                ActionChoice(id: "hide", title: String(localized: "Hide", bundle: .floe, comment: "An action that hides a running app's windows.")),
                ActionChoice(id: "quit", title: String(localized: "Quit", bundle: .floe, comment: "An action that quits a running app.")),
                ActionChoice(id: "restart", title: String(localized: "Restart", bundle: .floe, comment: "An action that quits a running app and opens it again.")),
                ActionChoice(id: "forceQuit", title: String(localized: "Force Quit…", bundle: .floe)),
                finder,
            ] + copies + [
                ActionChoice(id: "copyBundleIdentifier", title: String(localized: "Copy Bundle Identifier", bundle: .floe)),
                trash,
            ]
        case .file, .folder:
            return [
                ActionChoice(id: "openIn:terminal", title: String(localized: "Open in Your Terminal", bundle: .floe, comment: "An action on a file or folder: open it in the terminal app chosen in Settings.")),
                ActionChoice(id: "openIn:editor", title: String(localized: "Open in Your Editor", bundle: .floe, comment: "An action on a file or folder: open it in the editor app chosen in Settings.")),
                finder,
                ActionChoice(id: "quickLook", title: String(localized: "Quick Look", bundle: .floe, comment: "The name of the macOS feature that previews a file.")),
            ] + copies + [
                ActionChoice(id: "copyFile", title: String(localized: "Copy File", bundle: .floe)),
                trash,
            ]
        case .url:
            return [ActionChoice(id: "copyAddress", title: String(localized: "Copy Address", bundle: .floe))]
        }
    }

    /// Script commands that act on a kind of result.
    static func scripts(for kind: SubjectKind, in scripts: [ScriptCommand]) -> [ActionChoice] {
        scripts.filter { $0.actionInfo?.kinds.contains(kind) == true }.map { ActionChoice(id: $0.actionID, title: $0.title) }
    }
}

extension SubjectKind {
    var settingsTitle: LocalizedStringKey {
        switch self {
        case .app: "Apps"
        case .file: "Files"
        case .folder: "Folders"
        case .url: "Links"
        }
    }

    /// What a new action script for the kind starts with: the variables it is handed, and a line that uses them.
    var scriptExample: String {
        switch self {
        case .app:
            """
            # Handed: $FLOE_APP_NAME, $FLOE_APP_PATH, $FLOE_BUNDLE_ID, $FLOE_APP_RUNNING (1 or 0).
            open -b "$FLOE_BUNDLE_ID"
            """
        case .file, .folder:
            """
            # Handed: $FLOE_FILE_PATH, $FLOE_CONTENT_TYPE, $FLOE_TITLE.
            open -R "$FLOE_FILE_PATH"
            """
        case .url:
            """
            # Handed: $FLOE_URL, $FLOE_TITLE.
            open -a Safari "$FLOE_URL"
            """
        }
    }
}

/// The Commands page's Actions tab: for each kind of result, what Return does, the keys for each action, and which
/// actions the Actions menu shows.
struct AlternativeActionsSettingsSection: View {
    @ObservedObject var catalog: CatalogStore
    @ObservedObject var settings: AppSettings
    @State private var kind = SubjectKind.app
    @State private var refusal: String?

    private var choices: [ActionChoice] {
        [.floesOwn] + ActionChoice.builtIns(for: kind) + ActionChoice.scripts(for: kind, in: catalog.allScripts)
    }

    var body: some View {
        ThawSection("Return") {
            LabeledContent("Results") {
                ThawPillPicker(selection: $kind, options: SubjectKind.allCases.map { ThawPillPicker.Option($0, title: $0.settingsTitle) })
            }
            ThawPicker(selection: defaultChoice) {
                ForEach(choices) { choice in
                    Text(choice.title).tag(choice.id)
                }
            } label: {
                Text("Return does")
                Text("Where the action doesn't apply, such as a script for running apps on one that isn't, Return does what Floe does.")
            }
            if kind == .app {
                Toggle(isOn: $settings.alternativeActions.hotkeysRunDefault) {
                    Text("App hotkeys do what Return does")
                    Text("Otherwise an app's hotkey opens it, or hides it when it's in front.")
                }
            }
        }
        ThawSection("Actions") {
            ForEach(choices) { choice in
                row(choice)
            }
            if let refusal {
                Text(refusal).foregroundStyle(.red)
            }
        }
        ThawSection("Your Own Actions") {
            Text("A script command with a `# @floe.subjects` line is an action on results of that kind: app, file, folder or url. It is listed here and in the Actions menu instead of in the search, and is handed the result in variables that start with FLOE_.")
                .foregroundStyle(ThawInk.supporting)
            LabeledContent("New") {
                Button("New Action Script") { Self.makeScript(for: kind, catalog: catalog) }
                    .buttonStyle(.settingsGlass)
            }
        }
    }

    private func row(_ choice: ActionChoice) -> some View {
        HStack(spacing: ThawSpacing.compact) {
            Text(choice.title)
                .lineLimit(1)
            Spacer()
            HotkeyRecorder(
                keyCombination: shortcut(for: choice),
                onRecordingChange: { settings.isRecordingHotkey = $0 },
                label: { Text("Keys") }
            )
            .labelsHidden()
            .fixedSize()
            Toggle(isOn: shown(choice)) {
                Text("Show in the Actions menu")
            }
            .labelsHidden()
            .disabled(choice.id == AlternativeActionRules.floesOwn)
            .help(Text("Show in the Actions menu"))
        }
    }

    private var defaultChoice: Binding<String> {
        Binding {
            settings.alternativeActions[kind].defaults.first ?? AlternativeActionRules.floesOwn
        } set: { id in
            settings.alternativeActions[kind].defaults = id == AlternativeActionRules.floesOwn ? [] : [id]
        }
    }

    private func shown(_ choice: ActionChoice) -> Binding<Bool> {
        Binding {
            !settings.alternativeActions[kind].hidden.contains(choice.id)
        } set: { isShown in
            if isShown {
                settings.alternativeActions[kind].hidden.remove(choice.id)
            } else {
                settings.alternativeActions[kind].hidden.insert(choice.id)
            }
        }
    }

    /// Keys taken by Floe, or by another action on the same kind of result, are refused and the refusal says why.
    private func shortcut(for choice: ActionChoice) -> Binding<KeyCombination?> {
        Binding {
            settings.alternativeActions[kind].shortcuts[choice.id]
        } set: { keys in
            guard let keys else {
                settings.alternativeActions[kind].shortcuts[choice.id] = nil
                return
            }
            if AlternativeActionRules.reservedKeys.contains(keys) {
                refusal = String(localized: "\(keys.displayValue) already does something in the launcher.", bundle: .floe, comment: "The placeholder is a key combination, such as ⌘ K.")
                return
            }
            if let other = settings.alternativeActions[kind].shortcuts.first(where: { $0.value == keys && $0.key != choice.id }),
               let title = choices.first(where: { $0.id == other.key })?.title {
                refusal = String(localized: "\(keys.displayValue) is already the keys for \(title).", bundle: .floe, comment: "The first placeholder is a key combination, such as ⌘ K; the second is the name of an action.")
                return
            }
            refusal = nil
            settings.alternativeActions[kind].shortcuts[choice.id] = keys
        }
    }

    /// Writes a starter action script for a kind of result into the Scripts folder and reveals it, so it can be edited.
    static func makeScript(for kind: SubjectKind, catalog: CatalogStore) {
        Paths.prepareSupportFolders()
        var index = 1
        var file = Paths.scripts.appendingPathComponent("\(kind.rawValue)-action-\(index).sh")
        while FileManager.default.fileExists(atPath: file.path) {
            index += 1
            file = Paths.scripts.appendingPathComponent("\(kind.rawValue)-action-\(index).sh")
        }
        let text = """
        #!/bin/zsh
        # @raycast.schemaVersion 1
        # @raycast.title My \(kind.rawValue.capitalized) Action \(index)
        # @raycast.mode silent
        # @floe.subjects \(kind.rawValue)
        \(kind.scriptExample)

        """
        try? text.write(to: file, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
        catalog.reloadScripts()
        // The launcher lists scripts too, and has its own copy of the list.
        ProcessLink.current?.send(.rescan(.scripts))
        NSWorkspace.shared.activateFileViewerSelecting([file])
    }
}
