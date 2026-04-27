# Voixe by Enginecy

**Voice → text on your Mac. On-device. Free.**

Press-and-hold a hotkey, speak, and the transcript pastes into whatever app you're using. Optional on-device LLM cleanup strips fillers, executes spoken commands ("make this bulleted", "translate to Spanish"), and matches tone to the app you're dictating into. Nothing leaves your machine.

A free freebie from [Enginecy](https://enginecy.com) — a creative marketing agency that builds tools for the people we want to work with.

> **Note:** Voixe runs on **Apple Silicon Macs** only (M1 or newer), macOS 15+.

## What it does

- **Hold-to-talk** dictation with global hotkey.
- **On-device transcription** via [Parakeet TDT v3](https://github.com/FluidInference/FluidAudio) (default, multilingual) or [Whisper](https://github.com/argmaxinc/WhisperKit). No audio leaves the Mac.
- **Optional refinement** via a downloadable local LLM (Qwen / Llama 3.2 in 4-bit MLX) — cleans fillers, fixes backtracks, applies voice commands, matches tone to the active app. Or talk to your own [Ollama](https://ollama.com) server.
- **Custom dictionary** for proper nouns and acronyms.
- **History** with audio playback so you can revisit what you said.
- **Auto-updates** via Sparkle.

## Install

Once we cut the first release, this is where the DMG link lives.

For now, build from source: open `Voixe.xcodeproj` in Xcode 16+, set your Apple ID team in Signing & Capabilities, and ⌘R.

## How to use it

1. On first launch, Voixe walks you through three steps: welcome, permissions (microphone, accessibility, input monitoring), and Refine setup.
2. Pick a transcription model — it downloads in the background.
3. Pick (or skip) a refine model — it downloads in the background.
4. Hold your hotkey, speak, release. The transcript pastes into the active app.

Two recording modes:

- **Press-and-hold** the hotkey to record, release to transcribe.
- **Double-tap** the hotkey to lock recording, tap once more to transcribe.

## Built on

- [Hex](https://github.com/kitlangton/Hex) by Kit Langton — the original macOS voice-to-text app this is forked from. Voixe extends Hex with a curated bundled-LLM refine path (MLX-Swift), a first-run wizard, and Enginecy branding. Massive credit to Kit for the foundation.
- [WhisperKit](https://github.com/argmaxinc/WhisperKit) — Whisper Core ML inference.
- [FluidAudio](https://github.com/FluidInference/FluidAudio) — Parakeet TDT.
- [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture) — state management.
- [Sparkle](https://sparkle-project.org) — auto-updates.
- [mlx-swift-examples](https://github.com/ml-explore/mlx-swift-examples) — on-device LLM inference for the bundled refine path.

## Contributing

Issues welcome. PRs welcome too — please open an issue first if it's a non-trivial change so we can align on direction.

### Changelog workflow

- AI agents: `bun run changeset:add-ai <type> "summary"` to create a changeset non-interactively.
- Humans: `bunx changeset` for an interactive prompt.
- See [docs/RELEASING-FORKS.md](docs/RELEASING-FORKS.md) for the full release process.

## License

Apache License 2.0. See [LICENSE](LICENSE).

This project is a derivative work of [Hex](https://github.com/kitlangton/Hex) by Kit Langton, originally MIT-licensed. The original MIT license terms are preserved for the upstream code; new code added by Enginecy is contributed under Apache 2.0. See [NOTICE](NOTICE) for attribution detail.
