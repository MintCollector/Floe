//
//  WordDefinition.swift
//  Project: Floe
//
//  Copyright (Floe) © 2026 René Jiménez
//  Licensed under the GNU AGPLv3

import CoreServices
import Foundation

/// What the Mac's dictionaries say about a word typed after `define`.
nonisolated struct WordDefinition: Hashable, Sendable {
    static let keyword = "define"

    var word: String
    /// The entry on one line, as a row shows it. It starts with its headword.
    var text: String

    /// The link that opens the word in the Dictionary app.
    var link: URL? {
        word.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(["/"])).flatMap { URL(string: "dict://\($0)") }
    }

    init(word: String, entry: String) {
        self.word = word
        text = entry.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// The entry of the dictionaries switched on in the Dictionary app, in their order. Nil when none has the word.
    /// Nothing leaves the Mac: the dictionaries are on disk.
    @concurrent
    static func entry(for word: String) async -> String? {
        let range = CFRange(location: 0, length: (word as NSString).length)
        return DCSCopyTextDefinition(nil, word as CFString, range)?.takeRetainedValue() as String?
    }
}

/// `define tide` leads with what the dictionary says.
struct DefinitionSearchProvider: SearchProvider {
    func contribution(for context: SearchContext) -> SearchContribution {
        guard let word = context.text(after: WordDefinition.keyword),
              let definition = context.definition, definition.word == word, !definition.text.isEmpty
        else { return SearchContribution() }
        return SearchContribution(pinned: [RootResult(item: .definition(definition), section: nil)])
    }
}
