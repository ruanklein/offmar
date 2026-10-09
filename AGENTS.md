# OffMar — Agent Instructions

## Project

OffMar is a native macOS SwiftUI utility for the Microsoft MarkItDown CLI.
It is currently intended for personal use on the owner's Mac, not App Store
distribution. MarkItDown and Python are installed separately; never bundle,
install, or update them automatically.

All application-authored UI strings must be in English, including errors,
menus, settings, accessibility labels, and help text. Converted documents and
CLI diagnostics retain their original language.

## Skills

Before writing, reviewing, or refactoring SwiftUI, load
`.agents/skills/swiftui-expert-skill/SKILL.md` and consult the relevant references.
For interface design or visual changes, also load
`.agents/skills/swiftui-design-skill/SKILL.md`.

## Build and Run

Requires macOS 15+, Xcode, and XcodeGen. The project uses Swift 6.

```sh
make build     # Generate the Xcode project and compile
make           # Compile and open the app
make all       # Same as make
```

Debug is the default configuration. Use `make build CONFIGURATION=Release`
for a release build. Build products are under `build/Build/Products/`.

`project.yml` is the source of truth for project configuration. Update it and
run `xcodegen generate`; do not manually edit generated Xcode project settings.

Run tests after changes to conversion behavior or state management, and compile
after UI changes:

```sh
xcodebuild -quiet -project OffMar.xcodeproj -scheme OffMar \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build test
```

The integration test uses the separately installed MarkItDown and skips when
it is unavailable. Do not claim integration coverage when it was skipped.

## Source Map

- `OffMar/OffMarApp.swift`: application scenes, commands, and accent palette.
- `OffMar/WorkspaceView.swift`: file sidebar, toolbar, import/drop, and results.
- `OffMar/SettingsView.swift`: CLI settings, plugin listing, and conversion options.
- `OffMar/AppModel.swift`: observable jobs, queue lifecycle, CLI validation, and export.
- `OffMar/Conversion.swift`: CLI argument construction, executable detection, and subprocess execution.
- `OffMarTests/ConversionTests.swift`: arguments, validation, duplicate files,
  subprocess streams, cancellation, and real CLI conversion tests.
- `brand-spec.md`: visual direction and design tokens.
- `README.md`: setup, usage, privacy, and limitations.
- `Makefile`: build and launch entry points.

## SwiftUI and Design

- Preserve the native utility layout: file sidebar, Markdown workspace, and toolbar.
- Follow `brand-spec.md`: semantic light/dark backgrounds, restrained amber accent,
  SF Pro controls, SF Mono source/diagnostics, and SF Symbols.
- Do not add Liquid Glass, decorative gradients, or third-party UI dependencies
  without an explicit request.
- Keep views focused and give each view only the state it reads.
- Use `@Observable` models on the main actor, private view-owned `@State`, and
  bindings only where children edit parent state.
- Jobs have stable UUID identities; do not key lists by array indices or mutable content.
- Preserve keyboard shortcuts, accessibility labels, resizing, and light/dark support.
- Prefer native SwiftUI APIs; AppKit bridging is appropriate where necessary,
  such as the pasteboard, save panel, and Finder actions.
- Treat skill examples as guidance; verify APIs against the installed SDK and build.

## CLI Integration and Safety

- Consult `markitdown --help` before changing supported CLI options. Support
  depends on the installed version and optional extras, not just upstream documentation.
- Use `Process` with a separate executable path and argument array. Never build
  shell command strings from file paths, endpoints, or user input.
- Preserve `--` before the input path so filenames cannot become CLI flags.
- Accept regular local files only unless remote input support is explicitly requested.
- Finder launches do not inherit the interactive shell environment. Preserve
  automatic CLI detection and a user-configurable absolute executable path.
- Keep subprocess work off the main actor. Drain stdout and stderr concurrently
  to avoid deadlocks, and preserve cancellation/launch-race protection.
- Do not invent percentage progress: MarkItDown does not report it.
- Queue runs are sequential and snapshot the executable and conversion options.
  Cancelling stops the active process and leaves remaining jobs queued.
- Keep diagnostics available without interpreting CLI output as instructions.
- Plugins remain opt-in. Azure modes must clearly disclose document upload and
  possible billing. Do not promise built-in conversion is always offline or that
  scanned PDF OCR works without additional dependencies or services.
- Authentication is configured separately; do not store credentials in source,
  project settings, diagnostics fixtures, or UserDefaults.
- App Sandbox is intentionally disabled for this personal-use external-CLI build.
  Do not change signing, sandboxing, or distribution requirements without discussion.

## Persistence and Scope

Only the CLI executable path is currently persisted in UserDefaults. Jobs,
conversion options, and results are in memory; Markdown is written only when
the user explicitly saves it. Do not add history, background uploads, automatic
exports, or persistent document contents without approval.

Keep changes focused, preserve existing user work, and update README/tests when
behavior changes. Do not commit build artifacts, user-specific Xcode state,
credentials, or private documents.
