import AppKit
import Observation
import UniformTypeIdentifiers

enum JobStatus: String {
    case queued = "Queued", converting = "Converting", completed = "Completed"
    case failed = "Failed", cancelled = "Cancelled"

    var symbol: String {
        switch self {
        case .queued: "clock"
        case .converting: "arrow.triangle.2.circlepath"
        case .completed: "checkmark.circle.fill"
        case .failed: "exclamationmark.circle.fill"
        case .cancelled: "stop.circle"
        }
    }
}

@Observable @MainActor
final class ConversionJob: Identifiable {
    let id = UUID()
    let url: URL
    var status: JobStatus = .queued
    var markdown = ""
    var diagnostics = ""
    var duration: TimeInterval?
    init(url: URL) { self.url = url }
}

@Observable @MainActor
final class AppModel {
    var jobs: [ConversionJob] = []
    var selection: UUID?
    var options = ConversionOptions()
    var executable: String {
        didSet {
            UserDefaults.standard.set(executable, forKey: "executablePath")
            cliStatus = "Not checked"
            cliAvailable = false
        }
    }
    var cliStatus = "Checking MarkItDown…"
    var cliAvailable = false
    var isCheckingCLI = false
    var pluginReport = ""
    var isRunning = false
    var alertMessage: String?
    @ObservationIgnored private var conversionTask: Task<Void, Never>?
    @ObservationIgnored private var checkTask: Task<Void, Never>?

    init() {
        executable = UserDefaults.standard.string(forKey: "executablePath") ?? CommandRunner.detectExecutable()
    }

    var selectedJob: ConversionJob? { jobs.first { $0.id == selection } }
    var queuedCount: Int { jobs.filter { $0.status == .queued }.count }

    func addFiles(_ urls: [URL]) {
        for url in urls where url.isFileURL {
            var directory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &directory), !directory.boolValue else {
                alertMessage = "Choose regular files, not folders."
                continue
            }
            if let existing = jobs.first(where: { $0.url.standardizedFileURL == url.standardizedFileURL }) {
                selection = existing.id
            } else {
                let job = ConversionJob(url: url)
                jobs.append(job)
                selection = job.id
            }
        }
    }

    func checkCLI() {
        checkTask?.cancel()
        let path = executable
        isCheckingCLI = true
        cliAvailable = false
        cliStatus = "Checking MarkItDown…"
        checkTask = Task {
            defer { if executable == path { isCheckingCLI = false } }
            do {
                let result = try await CommandRunner.run(executable: path, arguments: ["--version"])
                guard !Task.isCancelled, executable == path else { return }
                cliAvailable = result.status == 0 && result.output.lowercased().contains("markitdown")
                cliStatus = cliAvailable ? result.output.trimmingCharacters(in: .whitespacesAndNewlines) : "MarkItDown could not be verified"
            } catch {
                guard !Task.isCancelled, executable == path else { return }
                cliStatus = "MarkItDown not found. Set its path in Settings."
            }
        }
    }

    func listPlugins() async {
        do {
            let result = try await CommandRunner.run(executable: executable, arguments: ["--list-plugins"])
            pluginReport = [result.output, result.diagnostics].filter { !$0.isEmpty }.joined(separator: "\n")
            if pluginReport.isEmpty { pluginReport = "No plugins reported." }
        } catch { pluginReport = error.localizedDescription }
    }

    func start() {
        guard !isRunning, cliAvailable, queuedCount > 0 else { return }
        if let error = options.validationError { alertMessage = error; return }
        let batch = jobs.filter { $0.status == .queued }
        let settings = options
        let path = executable
        isRunning = true
        conversionTask = Task {
            defer { isRunning = false; conversionTask = nil }
            for job in batch {
                if Task.isCancelled { break }
                job.status = .converting
                job.diagnostics = ""
                let started = Date()
                do {
                    let result = try await CommandRunner.run(executable: path, arguments: settings.arguments(for: job.url))
                    job.duration = Date().timeIntervalSince(started)
                    if Task.isCancelled { job.status = .cancelled; break }
                    job.diagnostics = result.diagnostics
                    if result.status == 0 {
                        job.markdown = result.output
                        job.status = .completed
                    } else {
                        job.status = .failed
                        if job.diagnostics.isEmpty { job.diagnostics = "MarkItDown exited with status \(result.status)." }
                    }
                } catch {
                    job.status = Task.isCancelled ? .cancelled : .failed
                    job.diagnostics = Task.isCancelled ? "Conversion cancelled." : error.localizedDescription
                }
            }
        }
    }

    func cancel() { conversionTask?.cancel() }

    func retry(_ job: ConversionJob) {
        guard !isRunning else { return }
        job.status = .queued
        job.markdown = ""
        job.diagnostics = ""
        job.duration = nil
    }

    func removeSelected() {
        guard !isRunning, let selection else { return }
        jobs.removeAll { $0.id == selection }
        self.selection = jobs.first?.id
    }

    func save(_ job: ConversionJob) {
        let panel = NSSavePanel()
        panel.title = "Save Markdown"
        panel.nameFieldStringValue = job.url.deletingPathExtension().lastPathComponent + ".md"
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try job.markdown.write(to: url, atomically: true, encoding: .utf8) }
        catch { alertMessage = "Could not save Markdown: \(error.localizedDescription)" }
    }
}
