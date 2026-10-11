//
//  DefinitionSearch.swift
//  Project: Floe
//
//  Copyright (Floe) © 2026 René Jiménez
//  Licensed under the GNU AGPLv3

import Foundation

/// The dictionary answer for the query on screen. Root ranking never waits for a disk-backed lookup.
final class DefinitionSearch {
    typealias Lookup = @concurrent @Sendable (String) async -> String?

    var lookup: Lookup
    private(set) var definition: WordDefinition?
    private var word: String?
    private var task: Task<Void, Never>?

    init(lookup: @escaping Lookup = WordDefinition.entry) {
        self.lookup = lookup
    }

    deinit {
        task?.cancel()
    }

    var isSearching: Bool {
        task != nil
    }

    @discardableResult
    func search(_ context: SearchContext, onChange: @escaping () -> Void) -> Task<Void, Never>? {
        let wanted = context.text(after: WordDefinition.keyword)
        guard wanted != word else { return task }
        cancel()
        guard let wanted else { return nil }
        word = wanted
        task = Task { [weak self, lookup] in
            let entry = await lookup(wanted)
            guard let self, !Task.isCancelled, word == wanted else { return }
            definition = entry.map { WordDefinition(word: wanted, entry: $0) }
            task = nil
            onChange()
        }
        return task
    }

    func cancel() {
        task?.cancel()
        task = nil
        word = nil
        definition = nil
    }

    func settled() async {
        await task?.value
    }
}
