//
//  ScriptActionInfoTests.swift
//  Project: Floe
//
//  Copyright (Floe) © 2026 René Jiménez
//  Licensed under the GNU AGPLv3

@testable import Floe
import Foundation
import Testing

/// Which results a script with `@floe.` lines is offered on, and what it is handed.
struct ScriptActionInfoTests {
    private let safari = ActionSubject(kind: .app, title: "Safari", url: URL(fileURLWithPath: "/Applications/Safari.app"), bundleIdentifier: "com.apple.Safari", isRunning: true)

    private func file(_ path: String, type: String?) -> ActionSubject {
        ActionSubject(kind: .file, title: (path as NSString).lastPathComponent, url: URL(fileURLWithPath: path), contentType: type)
    }

    private func link(_ address: String) -> ActionSubject {
        ActionSubject(kind: .url, title: address, url: URL(string: address)!)
    }

    @Test func aScriptThatNamesNoKindIsAPlainCommand() {
        #expect(ScriptActionInfo(metadata: [:]) == nil)
        #expect(ScriptActionInfo(metadata: ["subjects": "windows"]) == nil)
    }

    @Test func kindsAreReadFromAList() throws {
        let info = try #require(ScriptActionInfo(metadata: ["subjects": "application, file url"]))
        #expect(info.kinds == [.app, .file, .url])
    }

    @Test func appsNarrowByBundleIdentifierAndRunning() throws {
        let any = try #require(ScriptActionInfo(metadata: ["subjects": "app"]))
        #expect(any.accepts(safari))
        let chrome = try #require(ScriptActionInfo(metadata: ["subjects": "app", "bundleids": "com.google.Chrome"]))
        #expect(!chrome.accepts(safari))
        let closed = try #require(ScriptActionInfo(metadata: ["subjects": "app", "when": "not running"]))
        #expect(!closed.accepts(safari))
        let running = try #require(ScriptActionInfo(metadata: ["subjects": "app", "when": "running"]))
        #expect(running.accepts(safari))
    }

    @Test func filesNarrowByTypeOrExtension() throws {
        let images = try #require(ScriptActionInfo(metadata: ["subjects": "file", "filetypes": "public.image"]))
        #expect(images.accepts(file("/tmp/a.png", type: "public.png")))
        #expect(!images.accepts(file("/tmp/a.txt", type: "public.plain-text")))
        let markdown = try #require(ScriptActionInfo(metadata: ["subjects": "file", "filetypes": ".MD"]))
        #expect(markdown.accepts(file("/tmp/notes.md", type: nil)))
        #expect(!markdown.accepts(safari))
    }

    @Test func sitesMatchThemselvesAndTheSitesUnderThem() throws {
        let youtube = try #require(ScriptActionInfo(metadata: ["subjects": "url", "hosts": "youtube.com"]))
        #expect(youtube.accepts(link("https://www.youtube.com/watch?v=1")))
        #expect(youtube.accepts(link("https://youtube.com")))
        #expect(!youtube.accepts(link("https://notyoutube.com")))
    }

    @Test func theSubjectReachesAScriptAsItsEnvironment() {
        let environment = safari.environment
        #expect(environment["FLOE_SUBJECT"] == "app")
        #expect(environment["FLOE_BUNDLE_ID"] == "com.apple.Safari")
        #expect(environment["FLOE_APP_PATH"] == "/Applications/Safari.app")
        #expect(environment["FLOE_APP_RUNNING"] == "1")
        #expect(link("https://example.com/a b".replacingOccurrences(of: " ", with: "%20")).environment["FLOE_URL"] == "https://example.com/a%20b")
    }

    @Test func scopesAreMostSpecificFirst() {
        #expect(safari.scopes == ["app:com.apple.Safari"])
        #expect(file("/tmp/a.png", type: "public.png").scopes == ["type:public.png"])
        #expect(link("https://Example.com/x").scopes == ["host:example.com"])
    }

    @Test func aRealScriptIsHandedTheSubjectInItsEnvironment() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("echo.sh")
        try "#!/bin/sh\nprintf '%s|%s' \"$FLOE_BUNDLE_ID\" \"$FLOE_TITLE\"\n".write(to: file, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
        let script = ScriptCommand(file: file, title: "Echo", packageName: nil, mode: .silent, needsConfirmation: false, icon: nil, arguments: [])
        let quoted = ActionSubject(kind: .app, title: "It's \"quoted\"; $(no)", url: URL(fileURLWithPath: "/Applications/Safari.app"), bundleIdentifier: "com.apple.Safari")
        let result = try await ScriptRunner.run(script, arguments: [], environment: quoted.environment)
        #expect(result.trimmedOutput == "com.apple.Safari|It's \"quoted\"; $(no)")
    }

    @Test func aScriptFileCarriesItsFloeLines() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("here.sh")
        try """
        #!/bin/sh
        # @raycast.schemaVersion 1
        # @raycast.title Bring Here
        # @raycast.mode silent
        # @floe.subjects app
        # @floe.when running
        """.write(to: file, atomically: true, encoding: .utf8)
        let script = try ScriptCommand.parse(file: file).get()
        #expect(script.title == "Bring Here")
        #expect(script.actionInfo?.kinds == [.app])
        #expect(script.actionInfo?.whenRunning == true)
        #expect(script.actionID == "script:here.sh")
    }
}
