import XCTest
@testable import OffMar

final class ConversionTests: XCTestCase {
    func testLocalArgumentsKeepPathAsSingleArgument() {
        let url = URL(fileURLWithPath: "/Users/test/My File; echo nope.pdf")
        XCTAssertEqual(ConversionOptions().arguments(for: url), ["--", url.path])
    }

    func testContentUnderstandingOptions() {
        var options = ConversionOptions()
        options.mode = .contentUnderstanding
        options.endpoint = " https://example.com "
        options.analyzer = "invoice"
        options.fileTypes = "pdf,jpeg"
        options.plugins = true
        options.keepDataURIs = true
        let args = options.arguments(for: URL(fileURLWithPath: "/input.pdf"))
        XCTAssertTrue(args.contains("--use-cu"))
        XCTAssertTrue(args.contains("--use-plugins"))
        XCTAssertTrue(args.contains("--keep-data-uris"))
        XCTAssertTrue(args.contains("https://example.com"))
        XCTAssertTrue(args.contains("invoice"))
        XCTAssertNil(options.validationError)
    }

    func testCloudEndpointIsRequired() {
        var options = ConversionOptions()
        options.mode = .documentIntelligence
        XCTAssertNotNil(options.validationError)
        options.mode = .local
        XCTAssertNil(options.validationError)
    }

    func testRunnerDrainsBothStreams() async throws {
        let result = try await CommandRunner.run(executable: "/usr/bin/python3", arguments: [
            "-c", "import sys; sys.stderr.write('e' * 100000); sys.stdout.write('o' * 100000)"
        ])
        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.output.count, 100000)
        XCTAssertEqual(result.diagnostics.count, 100000)
    }

    @MainActor func testDuplicateFilesAreNotQueuedTwice() {
        let model = AppModel()
        let url = URL(fileURLWithPath: #filePath)
        model.addFiles([url, url])
        XCTAssertEqual(model.jobs.count, 1)
        XCTAssertEqual(model.selection, model.jobs.first?.id)
    }

    func testCancellationStopsProcess() async throws {
        let task = Task {
            try await CommandRunner.run(executable: "/bin/sleep", arguments: ["30"])
        }
        try await Task.sleep(for: .milliseconds(150))
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("A cancelled command should throw CancellationError")
        } catch is CancellationError {
            // Cancellation is distinguished from a CLI conversion failure.
        }
    }

    func testInstalledMarkItDownConversion() async throws {
        let executable = CommandRunner.detectExecutable()
        guard FileManager.default.isExecutableFile(atPath: executable) else {
            throw XCTSkip("MarkItDown is installed separately")
        }
        let fixture = FileManager.default.temporaryDirectory.appendingPathComponent("OffMar-\(UUID()).html")
        try "<html><body><h1>OffMar integration</h1><p>Hello <strong>Markdown</strong>.</p></body></html>"
            .write(to: fixture, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: fixture) }
        let result = try await CommandRunner.run(executable: executable, arguments: ConversionOptions().arguments(for: fixture))
        XCTAssertEqual(result.status, 0, result.diagnostics)
        XCTAssertTrue(result.output.contains("# OffMar integration"))
        XCTAssertTrue(result.output.contains("**Markdown**"))
    }
}
