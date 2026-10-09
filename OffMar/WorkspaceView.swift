import SwiftUI
import UniformTypeIdentifiers

struct WorkspaceView: View {
    @Bindable var model: AppModel
    @State private var importing = false
    @State private var showOptions = false
    @State private var dropTarget = false

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                HStack {
                    Text("FILES").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(model.jobs.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                .padding(16)
                List(selection: $model.selection) {
                    ForEach(model.jobs) { job in
                        FileRow(job: job).tag(job.id)
                            .contextMenu {
                                Button("Queue Again") { model.retry(job) }.disabled(model.isRunning)
                                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([job.url]) }
                            }
                    }
                }
                .overlay {
                    if model.jobs.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "tray").font(.title2)
                            Text("No files yet").font(.callout)
                            Text("Drop files here or choose Add Files.").font(.caption).multilineTextAlignment(.center)
                        }
                        .foregroundStyle(.secondary).padding(24).allowsHitTesting(false)
                    }
                }
                Divider()
                HStack {
                    Label("\(model.queuedCount) queued", systemImage: "tray").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button { model.removeSelected() } label: { Image(systemName: "minus") }
                        .buttonStyle(.borderless)
                        .help("Remove selected file")
                        .accessibilityLabel("Remove selected file")
                        .disabled(model.selection == nil || model.isRunning)
                }.padding(16)
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 380)
        } detail: {
            VStack(spacing: 0) {
                if !model.cliAvailable {
                    HStack(spacing: 12) {
                        Image(systemName: "terminal").foregroundStyle(Palette.accent)
                        Text(model.cliStatus).font(.callout)
                        Spacer()
                        SettingsLink { Text("Open Settings") }
                    }
                    .padding(16)
                    .background(Palette.accent.opacity(0.08))
                    Divider()
                }
                if let job = model.selectedJob {
                    ResultView(job: job, model: model)
                } else {
                    ContentUnavailableView {
                        Label("Convert to Markdown", systemImage: "doc.text")
                    } description: {
                        Text("Add files to get started.")
                            .font(.callout.weight(.regular))
                    } actions: {
                        Button("Add Files…") { importing = true }
                            .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                Divider()
                HStack(spacing: 8) {
                    Circle().fill(model.cliAvailable ? Color.green : Color.secondary).frame(width: 6, height: 6)
                    Text(model.cliStatus).lineLimit(1)
                    Spacer()
                    Text(model.options.mode == .local ? "Built-in conversion" : "Azure conversion · billable")
                }
                .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 16).padding(.vertical, 10)
            }
        }
        .navigationTitle("OffMar")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { importing = true } label: { Label("Add Files", systemImage: "plus") }
                    .help("Add files (⌘O)")
            }
            ToolbarItem(placement: .primaryAction) {
                Button { showOptions.toggle() } label: { Label("Options", systemImage: "slider.horizontal.3") }
                    .popover(isPresented: $showOptions) {
                        OptionsView(options: $model.options).frame(width: 380).padding(24)
                            .disabled(model.isRunning)
                    }
            }
            ToolbarItem(placement: .primaryAction) {
                if model.isRunning {
                    Button { model.cancel() } label: { Label("Cancel", systemImage: "stop.fill") }
                } else {
                    Button { model.start() } label: { Label("Convert Queue", systemImage: "play.fill") }
                        .disabled(!model.cliAvailable || model.queuedCount == 0)
                }
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): model.addFiles(urls)
            case .failure(let error): model.alertMessage = error.localizedDescription
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            model.addFiles(urls)
            return urls.contains { $0.isFileURL }
        } isTargeted: { dropTarget = $0 }
        .overlay {
            if dropTarget {
                RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.accent, lineWidth: 3)
                    .padding(4).allowsHitTesting(false)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .addOffMarFiles)) { _ in importing = true }
        .alert("OffMar", isPresented: Binding(get: { model.alertMessage != nil }, set: { if !$0 { model.alertMessage = nil } })) {
            Button("OK", role: .cancel) { model.alertMessage = nil }
        } message: { Text(model.alertMessage ?? "") }
    }
}

private struct FileRow: View {
    let job: ConversionJob
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text").font(.title3).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(job.url.lastPathComponent).lineLimit(1).font(.body)
                Label(job.status.rawValue, systemImage: job.status.symbol)
                    .font(.caption).foregroundStyle(job.status == .failed ? Color.red : Color.secondary)
            }
            Spacer(minLength: 0)
            if job.status == .converting { ProgressView().controlSize(.small) }
        }
        .padding(.vertical, 6)
        .help(job.url.path)
    }
}

private struct ResultView: View {
    let job: ConversionJob
    let model: AppModel
    @State private var showDiagnostics = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Text(job.url.pathExtension.uppercased().isEmpty ? "FILE" : job.url.pathExtension.uppercased())
                    .font(.caption.monospaced().weight(.semibold))
                    .padding(8).background(Palette.accent.opacity(0.12), in: .rect(cornerRadius: 6))
                    .foregroundStyle(Palette.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text(job.url.lastPathComponent).font(.title3.weight(.semibold)).lineLimit(1)
                    HStack(spacing: 8) {
                        Text(job.status.rawValue)
                        if let duration = job.duration { Text("· \(duration, specifier: "%.1f")s") }
                        if job.status == .completed { Text("· \(job.markdown.utf8.count.formatted()) bytes") }
                    }.font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if job.status == .completed {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(job.markdown, forType: .string)
                    } label: { Label("Copy", systemImage: "doc.on.doc") }
                    Button { model.save(job) } label: { Label("Save…", systemImage: "square.and.arrow.down") }
                }
            }.padding(24)
            Divider()
            if job.status == .completed {
                MarkdownResultView(markdown: job.markdown)
                    .id(job.id)
            } else if job.status == .converting {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Converting to Markdown…").font(.headline)
                    Text("Progress is indeterminate; MarkItDown does not report a percentage.")
                        .font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView {
                    Label(job.status == .queued ? "Ready to Convert" : job.status.rawValue,
                          systemImage: job.status == .queued ? "doc.badge.arrow.up" : job.status.symbol)
                } description: {
                    Text(job.status == .queued ? "Choose Convert Queue to generate Markdown." : "Review the diagnostics below or queue this file again.")
                } actions: {
                    if job.status != .queued {
                        Button("Queue Again") { model.retry(job) }.disabled(model.isRunning)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if !job.diagnostics.isEmpty {
                Divider()
                DisclosureGroup("Diagnostics", isExpanded: $showDiagnostics) {
                    ScrollView {
                        Text(job.diagnostics).font(.system(size: 12, design: .monospaced))
                            .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    }.frame(maxHeight: 160).padding(.top, 8)
                }.padding(16)
            }
        }
        .onChange(of: job.status) { _, status in if status == .failed { showDiagnostics = true } }
        .onAppear { showDiagnostics = job.status == .failed }
        .id(job.id)
    }
}

#Preview {
    WorkspaceView(model: AppModel()).frame(width: 1100, height: 740)
}
