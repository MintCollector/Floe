//
//  AlternativeActionRulesTests.swift
//  Project: Floe
//
//  Copyright (Floe) © 2026 René Jiménez
//  Licensed under the GNU AGPLv3

import AppKit
@testable import Floe
import Testing

/// What Return runs, how the Actions menu reads and what keys run, from the rows on offer and the user's choices.
@MainActor
struct AlternativeActionRulesTests {
    private func row(_ id: String?, _ title: String? = nil, children: [ItemAction] = []) -> ItemAction {
        ItemAction(title: title ?? id ?? "untitled", symbol: "circle", children: children, id: id)
    }

    /// The menu as text: titles, with "-" for a separator and the keys after a title that has them.
    private func read(_ rows: [ItemAction?]) -> [String] {
        rows.map { row in
            guard let row else { return "-" }
            return row.shortcut.map { "\(row.title) \($0.displayValue)" } ?? row.title
        }
    }

    private let floeRows: [ItemAction?] = [nil, ItemAction(title: "hide", symbol: "circle", id: "hide"), ItemAction(title: "quit", symbol: "circle", id: "quit"), nil, ItemAction(title: "favorite", symbol: "star")]

    @Test func offeredFindsRowsInSubmenus() {
        let offered = AlternativeActionRules.offered([row("openWith", children: [row("openWith:com.apple.Safari")]), nil, row(nil, "favorite")])
        #expect(Set(offered.keys) == ["openWith", "openWith:com.apple.Safari"])
    }

    @Test func primaryIsTheFirstDefaultOnOffer() {
        let offered = ["quit": row("quit"), "hide": row("hide")]
        #expect(AlternativeActionRules.primary(["script:gone.sh", "hide", "quit"]) { offered[$0] }?.id == "hide")
    }

    @Test func floesOwnStopsTheSearch() {
        let offered = ["hide": row("hide")]
        #expect(AlternativeActionRules.primary([AlternativeActionRules.floesOwn, "hide"]) { offered[$0] } == nil)
    }

    @Test func nothingOnOfferLeavesReturnToFloe() {
        #expect(AlternativeActionRules.primary(["hide"]) { _ in nil } == nil)
        #expect(AlternativeActionRules.primary([]) { _ in nil } == nil)
    }

    @Test func aMenuNobodyChangedStaysAsFloeHasIt() {
        let arranged = AlternativeActionRules.arranged(floeRows, extra: [], own: nil, primaryID: nil, choices: KindActions())
        #expect(read(arranged) == read(floeRows))
    }

    @Test func floesOwnComesFirstAndThePrimaryIsLeftOut() {
        let own = row(AlternativeActionRules.floesOwn, "Open")
        let arranged = AlternativeActionRules.arranged(floeRows, extra: [row("script:here.sh", "Bring Here")], own: own, primaryID: "script:here.sh", choices: KindActions())
        #expect(read(arranged) == ["-", "Open", "-", "hide", "quit", "-", "favorite"])
    }

    @Test func hiddenRowsAreLeftOutButFloesOwnStays() {
        var choices = KindActions()
        choices.hidden = ["quit", AlternativeActionRules.floesOwn]
        let arranged = AlternativeActionRules.arranged(floeRows, extra: [], own: row(AlternativeActionRules.floesOwn, "Open"), primaryID: nil, choices: choices)
        #expect(read(arranged) == ["-", "Open", "-", "hide", "-", "favorite"])
    }

    @Test func chosenOrderComesFirst() {
        var choices = KindActions()
        choices.order = ["quit", "script:here.sh", "missing"]
        let arranged = AlternativeActionRules.arranged(floeRows, extra: [row("script:here.sh", "Bring Here")], own: nil, primaryID: nil, choices: choices)
        #expect(read(arranged) == ["-", "quit", "Bring Here", "-", "hide", "-", "favorite"])
    }

    @Test func rowsShowTheirKeys() {
        var choices = KindActions()
        choices.shortcuts = ["quit": KeyCombination(key: .q, modifiers: .command)]
        let arranged = AlternativeActionRules.arranged(floeRows, extra: [], own: nil, primaryID: nil, choices: choices)
        #expect(read(arranged) == ["-", "hide", "quit ⌘ Q", "-", "favorite"])
    }

    @Test func keysFindTheirAction() {
        var choices = KindActions()
        choices.shortcuts = ["quit": KeyCombination(key: .q, modifiers: .command)]
        let offered = ["quit": row("quit")]
        #expect(AlternativeActionRules.action(for: KeyCombination(key: .q, modifiers: .command), choices: choices) { offered[$0] }?.id == "quit")
        #expect(AlternativeActionRules.action(for: KeyCombination(key: .w, modifiers: .command), choices: choices) { offered[$0] } == nil)
    }

    @Test func separatorsAreTidied() {
        let tidied = AlternativeActionRules.tidied([nil, nil, row("a"), nil, nil, row("b"), nil])
        #expect(read(tidied) == ["-", "a", "-", "b"])
        #expect(AlternativeActionRules.tidied([nil, nil]).isEmpty)
    }
}
