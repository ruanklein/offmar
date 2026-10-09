import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel
    @State private var choosingExecutable = false
    @State private var listingPlugins = false

    var body: some View {
        Form {
            Section("MarkItDown CLI") {
                Text("OffMar uses your separately installed MarkItDown. It does not bundle Python or converters.")
                    .font(.callout).foregroundStyle(.secondary)
                TextField("Executable path", text: $model.executable)
                    .textFieldStyle(.roundedBorder)
                    .disabled(model.isRunning)
                HStack {
                    Button("Choose…") { choosingExecutable = true }
                    Button("Detect") { model.executable = CommandRunner.detectExecutable(); model.checkCLI() }
                    Button("Check Version") { model.checkCLI() }.disabled(model.isCheckingCLI)
                    if model.isCheckingCLI { ProgressView().controlSize(.small) }
                }.disabled(model.isRunning)
                Text(model.cliStatus).font(.caption).foregroundStyle(.secondary)
                Text("Install in Terminal: pip install 'markitdown[all]'")
                    .font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
            }
            Section("Plugins") {
                Text("Third-party plugins are disabled by default. Enable them in Conversion Options only if you trust them.")
                    .font(.callout).foregroundStyle(.secondary)
                Button(listingPlugins ? "Listing…" : "List Installed Plugins") {
                    listingPlugins = true
                    Task { await model.listPlugins(); listingPlugins = false }
                }.disabled(!model.cliAvailable || listingPlugins)
                if !model.pluginReport.isEmpty {
                    ScrollView {
                        Text(model.pluginReport).font(.system(size: 12, design: .monospaced))
                            .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    }.frame(height: 100)
                }
            }
            Section("Privacy") {
                Text("Azure modes send documents to Azure and may incur charges. Some converters and plugins may use network services even with built-in conversion selected. Authentication must be configured separately in your CLI environment.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 580, height: 540)
        .fileImporter(isPresented: $choosingExecutable, allowedContentTypes: [.item]) { result in
            if case .success(let url) = result { model.executable = url.path; model.checkCLI() }
        }
    }
}

struct OptionsView: View {
    @Binding var options: ConversionOptions
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Conversion Options").font(.headline)
            Text("Applied to the next queue run.").font(.caption).foregroundStyle(.secondary)
            Form {
                Picker("Converter", selection: $options.mode) {
                    ForEach(ConversionMode.allCases) { Text($0.rawValue).tag($0) }
                }
                if options.mode != .local {
                    TextField("Azure endpoint", text: $options.endpoint)
                    if options.mode == .contentUnderstanding {
                        TextField("Analyzer ID (optional)", text: $options.analyzer)
                        TextField("File types (e.g. pdf,jpeg)", text: $options.fileTypes)
                    }
                    Label("Documents will be sent to Azure. Charges may apply.", systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(Palette.accent)
                }
                Section("Input hints (optional)") {
                    TextField("Extension", text: $options.fileExtension)
                    TextField("MIME type", text: $options.mimeType)
                    TextField("Charset", text: $options.charset)
                }
                Toggle("Enable third-party plugins", isOn: $options.plugins)
                Toggle("Keep data URIs", isOn: $options.keepDataURIs)
            }
            .textFieldStyle(.roundedBorder)
            Text("Available formats depend on the extras installed with MarkItDown. PDF scans and image OCR may require additional services or plugins.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
