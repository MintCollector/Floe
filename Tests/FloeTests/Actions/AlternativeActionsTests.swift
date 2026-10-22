//
//  AlternativeActionsTests.swift
//  Project: Floe
//
//  Copyright (Floe) © 2026 René Jiménez
//  Licensed under the GNU AGPLv3

import AppKit
@testable import Floe
import Testing

/// Alternative actions as the launcher asks them, with a fake launcher and a runner that answers at once: no script
/// is run and nothing is opened.
@MainActor
struct AlternativeActionsTests {
    private final class Asked {
        var settings = ActionSettings()
        var ranFloes: [String] = []
        var used: [String] = []
        var left = 0
        var ran: [String] = []
        var environments: [[String: String]] = []
    }

    private let asked = Asked()
    private let calculator = AppEntry(name: "Calculator", url: URL(fileURLWithPath: "/System/Applications/Calculator.app"))

    private func script(_ name: String, _ lines: [String: String]) -> ScriptCommand {
        ScriptCommand(
            file: URL(fileURLWithPath: "/tmp/\(name)"), title: name, packageName: nil, mode: .silent,
            needsConfirmation: false, icon: nil, arguments: [], floeMetadata: lines
        )
    }

    private func actions(scripts: [ScriptCommand] = []) -> AlternativeActions {
        let asked = asked
        let actions = AlternativeActions()
        actions.host = AlternativeActions.Host(
            settings: { asked.settings },
            scripts: { scripts },
            floeActions: { _ in
                [nil, ItemAction(title: "Quit", symbol: "xmark", id: "quit") { asked.ran.append("quit") }]
            },
            floeTitle: { _ in "Open" },
            openAsFloeDoes: { asked.ranFloes.append($0.id) },
            used: { asked.used.append($0.id) },
            showHUD: { _ in
                // Not looked at.
            },
            leave: { asked.left += 1 }
        )
        actions.runningApps = { [] }
        actions.runScript = { script, environment in
            await MainActor.run {
                asked.ran.append(script.title)
                asked.environments.append(environment)
            }
            return ShellResult(status: 0, stdout: Data(), stderr: Data())
        }
        return actions
    }

    private func settle(until done: () -> Bool) async {
        for _ in 0 ..< 200 where !done() {
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    @Test func nothingChosenLeavesReturnToFloe() {
        let actions = actions()
        #expect(!actions.open(.app(calculator), flags: []))
        #expect(actions.returnTitle(for: .app(calculator)) == nil)
    }

    @Test func aChosenScriptRunsOnReturnWithTheAppHandedToIt() async {
        asked.settings[.app] = { var kind = KindActions(); kind.defaults = ["script:here.sh"]; return kind }()
        let actions = actions(scripts: [script("here.sh", ["subjects": "app"])])
        #expect(actions.returnTitle(for: .app(calculator)) == "here.sh")
        #expect(actions.open(.app(calculator), flags: []))
        await settle { !asked.environments.isEmpty }
        #expect(asked.used == [RootItem.app(calculator).id])
        #expect(asked.left == 1)
        #expect(asked.environments.first?["FLOE_BUNDLE_ID"] == "com.apple.calculator")
    }

    @Test func returnWithKeysHeldStaysFloes() {
        asked.settings[.app] = { var kind = KindActions(); kind.defaults = ["quit"]; return kind }()
        #expect(!actions().open(.app(calculator), flags: .command))
    }

    @Test func aDefaultThatDoesNotApplyFallsThrough() {
        asked.settings[.app] = { var kind = KindActions(); kind.defaults = ["script:here.sh", "quit"]; return kind }()
        // The script is only for apps that are running, and Calculator is not.
        let actions = actions(scripts: [script("here.sh", ["subjects": "app", "when": "running"])])
        #expect(actions.returnTitle(for: .app(calculator)) == "Quit")
        #expect(actions.open(.app(calculator), flags: []))
        #expect(asked.ran == ["quit"])
    }

    @Test func anAppOfItsOwnComesBeforeItsKind() {
        asked.settings[.app] = { var kind = KindActions(); kind.defaults = ["quit"]; return kind }()
        asked.settings.scoped["app:com.apple.calculator"] = [AlternativeActionRules.floesOwn]
        #expect(actions().returnTitle(for: .app(calculator)) == nil)
    }

    @Test func theMenuKeepsFloesOwnReachable() {
        asked.settings[.app] = { var kind = KindActions(); kind.defaults = ["quit"]; return kind }()
        let menu = actions().arranged([nil, ItemAction(title: "Quit", symbol: "xmark", id: "quit")], for: .app(calculator))
        let titles = menu.map { $0?.title ?? "-" }
        #expect(titles.first == "-")
        #expect(titles.contains("Open"))
        #expect(!titles.contains("Quit"))
        menu.compactMap(\.self).first { $0.id == AlternativeActionRules.floesOwn }?.run()
        #expect(asked.ranFloes == [RootItem.app(calculator).id])
    }

    @Test func keysRunTheirAction() {
        asked.settings[.app] = { var kind = KindActions(); kind.shortcuts = ["quit": KeyCombination(key: .q, modifiers: .command)]; return kind }()
        let actions = actions()
        #expect(actions.handleKey(UInt16(KeyCode.q.rawValue), flags: .command, on: .app(calculator)))
        #expect(asked.ran == ["quit"])
        #expect(!actions.handleKey(UInt16(KeyCode.w.rawValue), flags: .command, on: .app(calculator)))
    }

    @Test func aHotkeyRunsTheDefaultOnlyWhenAsked() {
        asked.settings[.app] = { var kind = KindActions(); kind.defaults = ["quit"]; return kind }()
        let actions = actions()
        #expect(!actions.runHotkey(for: calculator))
        asked.settings.hotkeysRunDefault = true
        #expect(actions.runHotkey(for: calculator))
        #expect(asked.ran == ["quit"])
    }

    @Test func rowsWithoutASubjectAreLeftAlone() {
        asked.settings[.app] = { var kind = KindActions(); kind.defaults = ["quit"]; return kind }()
        #expect(!actions().open(.settings, flags: []))
    }

    @Test func settingsReadWithoutTheKeysTheyLack() throws {
        let settings = try JSONDecoder().decode(ActionSettings.self, from: Data(#"{"kinds":{"app":{"defaults":["quit"]}}}"#.utf8))
        #expect(settings[.app].defaults == ["quit"])
        #expect(settings[.app].hidden.isEmpty)
        #expect(!settings.hotkeysRunDefault)
    }

    @Test func aKindWithNothingChosenIsNotKept() {
        var settings = ActionSettings()
        settings[.file] = KindActions()
        #expect(settings.kinds.isEmpty)
    }
}
