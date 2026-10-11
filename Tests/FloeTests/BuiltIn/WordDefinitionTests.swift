//
//  WordDefinitionTests.swift
//  Project: Floe
//
//  Copyright (Floe) © 2026 René Jiménez
//  Licensed under the GNU AGPLv3

@testable import Floe
import Foundation
import Testing

struct WordDefinitionTests {
    private let tide = "tide | tīd |\nnoun\n1 the alternate rising and falling of the sea"

    private func provider(_ entries: [String: String]) -> DefinitionSearchProvider {
        DefinitionSearchProvider { entries[$0] }
    }

    @Test func theEntryIsPutOnOneLine() {
        #expect(WordDefinition(word: "Tide", entry: tide).text == "tide | tīd | noun 1 the alternate rising and falling of the sea")
    }

    @Test func theLinkOpensTheWordInTheDictionaryApp() {
        #expect(WordDefinition(word: "tide", entry: tide).link?.absoluteString == "dict://tide")
        #expect(WordDefinition(word: "high tide", entry: tide).link?.absoluteString == "dict://high%20tide")
    }

    @Test func defineAndAWordPinsWhatTheDictionarySays() {
        let contribution = provider(["tide": tide]).contribution(for: SearchContext(query: "Define tide "))
        #expect(contribution.pinned.map(\.item.title) == ["tide | tīd | noun 1 the alternate rising and falling of the sea"], "the row's title is the entry, since a row has one line")
        #expect(contribution.pinned.first?.item.kind == "Dictionary")
    }

    @Test func nothingIsPinnedWithoutAWordOrAnEntry() {
        let provider = provider(["tide": tide, "ebb": " \n"])
        for query in ["define", "define ", "define xyzzy", "tide", "defined tide"] {
            #expect(provider.contribution(for: SearchContext(query: query)).pinned.isEmpty, "\(query)")
        }
        #expect(provider.contribution(for: SearchContext(query: "define ebb")).pinned.isEmpty, "an empty entry says nothing")
    }

    @Test func aQuicklinkWithTheSameKeywordKeepsIt() {
        var context = SearchContext(query: "define tide")
        context.quicklinks = [Quicklink(name: "Wiktionary", keyword: "define", url: "https://en.wiktionary.org/wiki/{query}")]
        #expect(provider(["tide": tide]).contribution(for: context).pinned.isEmpty)
    }
}
