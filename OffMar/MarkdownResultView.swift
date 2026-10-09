import MarkdownView
import SwiftUI

struct MarkdownResultView: View {
    let markdown: String
    @State private var presentation: Presentation = .source

    private enum Presentation: String, CaseIterable {
        case source = "Source"
        case preview = "Preview"
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Markdown presentation", selection: $presentation) {
                ForEach(Presentation.allCases, id: \.self) { presentation in
                    Text(presentation.rawValue).tag(presentation)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 240)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .center)

            Divider()

            if markdown.isEmpty {
                Text("(Empty Markdown output)")
                    .font(.system(size: 13, design: .monospaced))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(24)
            } else if presentation == .source {
                ScrollView([.horizontal, .vertical]) {
                    Text(markdown)
                        .font(.system(size: 13, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                MarkdownPreview(markdown: markdown)
            }
        }
        .background(.background)
    }
}

private struct MarkdownPreview: View {
    let markdown: String

    var body: some View {
        ScrollView {
            MarkdownView(markdown)
                .markdownElementRenderer(.image(BlockedRemoteImageRenderer(), urlScheme: "http"))
                .markdownElementRenderer(.image(BlockedRemoteImageRenderer(), urlScheme: "https"))
                .tint(Palette.accent)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct BlockedRemoteImageRenderer: MarkdownImageRenderer {
    func makeBody(configuration: Configuration) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text("Remote image blocked")
                if let alternativeText = configuration.alternativeText, !alternativeText.isEmpty {
                    Text(alternativeText)
                }
            }
        } icon: {
            Image(systemName: "photo.badge.exclamationmark")
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }
}
