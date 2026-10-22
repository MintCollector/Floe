//
//  ActionSubject.swift
//  Project: Floe
//
//  Copyright (Floe) © 2026 René Jiménez
//  Licensed under the GNU AGPLv3

import Foundation
import UniformTypeIdentifiers

/// The kinds of thing a result can be about. Alternative actions are chosen for each kind.
nonisolated enum SubjectKind: String, Codable, CaseIterable, Sendable {
    case app
    case file
    case folder
    case url
}

/// What a result is about, as alternative actions see it: an app, a file or folder, or a web address.
/// It is what a script is handed, so it stays small and its names stay put.
nonisolated struct ActionSubject: Equatable, Sendable {
    let kind: SubjectKind
    /// What the row is called: the app's or file's name, or the page's title.
    let title: String
    /// The app's bundle, the file, or the address.
    let url: URL
    var bundleIdentifier: String?
    var isRunning = false
    /// A file's type, as a uniform type identifier.
    var contentType: String?

    /// The keys a default of its own may be kept under, most specific first: one app, one type of file, one site.
    var scopes: [String] {
        switch kind {
        case .app: bundleIdentifier.map { ["app:\($0)"] } ?? []
        case .file: contentType.map { ["type:\($0)"] } ?? []
        case .folder: []
        case .url: url.host().map { ["host:\($0.lowercased())"] } ?? []
        }
    }

    /// Handed to a script as its environment. Never written into the script's text, so a name with quotes in it
    /// cannot break the command or add to it.
    var environment: [String: String] {
        var values = ["FLOE_SUBJECT": kind.rawValue, "FLOE_TITLE": title]
        switch kind {
        case .app:
            values["FLOE_APP_PATH"] = url.path
            values["FLOE_APP_NAME"] = title
            values["FLOE_BUNDLE_ID"] = bundleIdentifier
            values["FLOE_APP_RUNNING"] = isRunning ? "1" : "0"
        case .file, .folder:
            values["FLOE_FILE_PATH"] = url.path
            values["FLOE_CONTENT_TYPE"] = contentType
        case .url:
            values["FLOE_URL"] = url.absoluteString
        }
        return values
    }
}

/// A script command that is an alternative action. Its `@floe.` lines say which results it is offered on;
/// Raycast reads none of them, so the same file is a plain script command there.
///
///     # @floe.subjects app
///     # @floe.when running
///     # @floe.bundleIds com.apple.Safari, com.google.Chrome
///     # @floe.fileTypes public.image, md
///     # @floe.hosts youtube.com
nonisolated struct ScriptActionInfo: Equatable, Sendable {
    let kinds: Set<SubjectKind>
    var bundleIdentifiers: Set<String> = []
    /// Uniform type identifiers, which a file's type conforms to, or file name extensions.
    var fileTypes: [String] = []
    /// Sites, each matching itself and the sites under it.
    var hosts: [String] = []
    /// For an app: offered only while it runs (true), only while it does not (false), or either.
    var whenRunning: Bool?

    /// Nil for a script that names no kind of result: an ordinary script command.
    init?(metadata: [String: String]) {
        let kinds = Self.list(metadata["subjects"]).compactMap { name -> SubjectKind? in
            let name = name.lowercased()
            return name == "application" ? .app : SubjectKind(rawValue: name)
        }
        guard !kinds.isEmpty else { return nil }
        self.kinds = Set(kinds)
        bundleIdentifiers = Set(Self.list(metadata["bundleids"]))
        fileTypes = Self.list(metadata["filetypes"]).map { $0.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".")) }
        hosts = Self.list(metadata["hosts"]).map { $0.lowercased() }
        switch metadata["when"]?.lowercased().filter({ !$0.isWhitespace }) {
        case "running": whenRunning = true
        case "notrunning": whenRunning = false
        default: whenRunning = nil
        }
    }

    /// A list written with commas, spaces or both.
    private static func list(_ text: String?) -> [String] {
        (text ?? "").split { $0 == "," || $0.isWhitespace }.map(String.init)
    }

    /// Whether the script is offered on this result.
    func accepts(_ subject: ActionSubject) -> Bool {
        guard kinds.contains(subject.kind) else { return false }
        switch subject.kind {
        case .app:
            if !bundleIdentifiers.isEmpty, !bundleIdentifiers.contains(subject.bundleIdentifier ?? "") {
                return false
            }
            return whenRunning.map { $0 == subject.isRunning } ?? true
        case .file:
            return fileTypes.isEmpty || fileTypes.contains { Self.matches(subject, type: $0) }
        case .folder:
            return true
        case .url:
            guard !hosts.isEmpty else { return true }
            let host = subject.url.host()?.lowercased() ?? ""
            return hosts.contains { host == $0 || host.hasSuffix("." + $0) }
        }
    }

    /// A name with a dot is a type, which subtypes conform to; one without is a file name extension.
    private static func matches(_ subject: ActionSubject, type: String) -> Bool {
        guard type.contains(".") else {
            return subject.url.pathExtension.lowercased() == type
        }
        guard let wanted = UTType(type), let actual = subject.contentType.flatMap({ UTType($0) }) else { return false }
        return actual.conforms(to: wanted)
    }
}

extension ScriptCommand {
    /// What the script acts on when it is an alternative action; nil for an ordinary script command.
    nonisolated var actionInfo: ScriptActionInfo? {
        ScriptActionInfo(metadata: floeMetadata)
    }

    /// The id the script has as an action, which settings keep.
    nonisolated var actionID: String {
        "script:\(file.lastPathComponent)"
    }
}
