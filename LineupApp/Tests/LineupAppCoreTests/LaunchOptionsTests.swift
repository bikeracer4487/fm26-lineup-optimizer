import Foundation
import Testing
import LineupEngine
@testable import LineupAppCore

@Suite struct LaunchOptionsTests {
    @Test func noArgumentsOpenTheAppOnItsOwnFiles() throws {
        #expect(try LaunchOptions.parse([]) == LaunchOptions(picturesDirectory: nil, sampleDataRoot: nil))
    }

    @Test func eachOptionTakesTheValueAfterIt() throws {
        #expect(try LaunchOptions.parse(["--pictures", ".build/pictures"])
            == LaunchOptions(picturesDirectory: ".build/pictures", sampleDataRoot: nil))
        #expect(try LaunchOptions.parse(["--sample-data", ".."])
            == LaunchOptions(picturesDirectory: nil, sampleDataRoot: ".."))
        #expect(try LaunchOptions.parse(["--sample-data", "..", "--pictures", "out"])
            == LaunchOptions(picturesDirectory: "out", sampleDataRoot: ".."))
    }

    @Test func anOptionWithoutItsValueIsRefused() {
        #expect(throws: LaunchOptionsError(description: "--pictures needs one directory, for example --pictures .build/pictures")) {
            try LaunchOptions.parse(["--pictures"])
        }
        #expect(throws: LaunchOptionsError(description: "--pictures needs one directory, for example --pictures .build/pictures")) {
            try LaunchOptions.parse(["--pictures", "--sample-data", ".."])
        }
        #expect(throws: LaunchOptionsError(description: "--sample-data needs the repository's root, for example --sample-data ..")) {
            try LaunchOptions.parse(["--sample-data"])
        }
    }

    @Test func anOptionGivenTwiceIsRefused() {
        #expect(throws: LaunchOptionsError(description: "--pictures was given twice.")) {
            try LaunchOptions.parse(["--pictures", "a", "--pictures", "b"])
        }
    }

    @Test func anUnknownArgumentIsRefused() {
        #expect(throws: LaunchOptionsError(description:
            "The argument \"--colour\" is not known. The options are --pictures <directory> and --sample-data <repository root>.")) {
            try LaunchOptions.parse(["--colour", "blue"])
        }
    }
}

@MainActor @Suite struct PictureModelTests {
    @Test func theEmptyModelHasNothingInItAndNoNotices() throws {
        let model = SampleData.emptyModel()
        #expect(model.players.isEmpty)
        #expect(model.notices.isEmpty)
        #expect(model.lastImport == nil)
        #expect(model.tactics.isEmpty && model.fixtures.isEmpty)
    }

    @Test func theFailedImportModelKeepsTheSampleSquadAndSaysWhy() throws {
        let sample = try SampleData.model(repositoryRoot: Captures.repositoryRoot)
        let model = try SampleData.modelWithFailedImport(repositoryRoot: Captures.repositoryRoot)
        #expect(model.players == sample.players)
        #expect(model.notices.isEmpty)
        guard case .failed(let reason)? = model.lastImport else {
            Issue.record("expected a failed import, got \(String(describing: model.lastImport))")
            return
        }
        #expect(reason == ErrorDescriptions.describe(ImportError.notAnFMRTEGrid(reason: "first line has no tab separators")))
    }
}
