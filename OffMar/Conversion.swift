import Foundation

enum ConversionMode: String, CaseIterable, Identifiable, Sendable {
    case local = "Built-in converters"
    case documentIntelligence = "Azure Document Intelligence"
    case contentUnderstanding = "Azure Content Understanding"
    var id: String { rawValue }
}

struct ConversionOptions: Sendable {
    var mode: ConversionMode = .local
    var fileExtension = ""
    var mimeType = ""
    var charset = ""
    var plugins = false
    var keepDataURIs = false
    var endpoint = ""
    var analyzer = ""
    var fileTypes = ""

    var validationError: String? {
        if mode != .local && endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Enter an Azure endpoint before converting."
        }
        return nil
    }

    func arguments(for url: URL) -> [String] {
        // Options precede -- so filenames can never be interpreted as flags.
        var result: [String] = []
        func append(_ flag: String, _ value: String) {
            let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty { result += [flag, value] }
        }
        append("--extension", fileExtension)
        append("--mime-type", mimeType)
        append("--charset", charset)
        if plugins { result.append("--use-plugins") }
        if keepDataURIs { result.append("--keep-data-uris") }
        switch mode {
        case .local: break
        case .documentIntelligence:
            result.append("--use-docintel")
            append("--endpoint", endpoint)
        case .contentUnderstanding:
            result.append("--use-cu")
            append("--cu-endpoint", endpoint)
            append("--cu-analyzer", analyzer)
            append("--cu-file-types", fileTypes)
        }
        return result + ["--", url.path]
    }
}

struct CommandResult: Sendable {
    let output: String
    let diagnostics: String
    let status: Int32
}

// Process is only accessed under the lock, including the launch/cancel race.
private final class ProcessHandle: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false

    func launch(_ process: Process) throws {
        lock.lock()
        defer { lock.unlock() }
        if cancelled { throw CancellationError() }
        self.process = process
        try process.run()
    }

    func cancel() {
        lock.lock()
        defer { lock.unlock() }
        cancelled = true
        if let process, process.isRunning { process.terminate() }
    }
}

enum CommandRunner {
    static func run(executable: String, arguments: [String]) async throws -> CommandResult {
        let handle = ProcessHandle()
        return try await withTaskCancellationHandler {
            let result = try await Task.detached {
                try Task.checkCancellation()
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments
                var environment = ProcessInfo.processInfo.environment
                // Finder-launched apps don't inherit the interactive shell PATH.
                let home = FileManager.default.homeDirectoryForCurrentUser.path
                environment["PATH"] = "\(home)/.local/bin:/opt/homebrew/bin:/usr/local/bin:" + (environment["PATH"] ?? "/usr/bin:/bin")
                process.environment = environment
                process.standardInput = FileHandle.nullDevice
                let output = Pipe()
                let errors = Pipe()
                process.standardOutput = output
                process.standardError = errors
                try handle.launch(process)
                // Drain both streams concurrently; waiting first can deadlock a full pipe.
                async let errorData = Task.detached {
                    errors.fileHandleForReading.readDataToEndOfFile()
                }.value
                let outputData = output.fileHandleForReading.readDataToEndOfFile()
                let diagnostics = await errorData
                process.waitUntilExit()
                return CommandResult(
                    output: String(decoding: outputData, as: UTF8.self),
                    diagnostics: String(decoding: diagnostics, as: UTF8.self),
                    status: process.terminationStatus
                )
            }.value
            try Task.checkCancellation()
            return result
        } onCancel: {
            handle.cancel()
        }
    }

    static func detectExecutable() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = ["\(home)/.local/bin/markitdown", "/opt/homebrew/bin/markitdown", "/usr/local/bin/markitdown"]
        let pathCandidates = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":").map { "\($0)/markitdown" }
        return (candidates + pathCandidates).first { FileManager.default.isExecutableFile(atPath: $0) } ?? candidates[0]
    }
}
