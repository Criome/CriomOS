# Voice-Typing — Design

## Problem

Typing is not the fastest path from thought to text for prose, meditative
reflection, Sanskrit-inflected philosophy, and cross-language notes. A good
voice-typing system on Linux in 2026 should feel like the text is already
there — appearing as fast as the mouth moves, with the voice's mistakes and
hesitations cleaned up, proper nouns spelled the way the user spells them,
and Sanskrit terms rendered in IAST with real diacritics, not ASCII mush.

No off-the-shelf Linux app in 2026 does this. The closest two — Hyprvoice
and Speech Note — are good at the ASR layer but lack multi-pass correction,
personal vocabulary curation, niri-aware injection, and IAST-class
transliteration. Meanwhile the mega-models (Gemini 2.5 audio, GPT-4o-audio,
Claude audio) transcribe mixed-language prose surprisingly well but live
behind a cloud API, which violates the CriomOS premise of on-premise-first
with the user's own LLM server doing the work.

The user already has Prometheus: 128 GB unified-memory Strix Halo on the
LAN, running llama-server on port 11434 with Vulkan/RADV, LRU model
hot-swap, and sub-millisecond network latency from the laptop. That's the
missing infrastructure piece that makes a two-or-three-tier dictation
pipeline practical.

## Goal

A multi-pass voice-typing system that produces text reading like the user
wrote it, end-to-end in under one second for short utterances, spanning
English, Sanskrit (IAST output), Spanish, and French, and integrating with
niri + Noctalia on the laptop and llama-server on Prometheus.

Follows Mentci architecture: own CozoDB for glossary and session history,
own repo, relations as source of truth, MCP tools for introspection, three
orthogonal subsystems (capture, transcribe, correct).

## Name

`criome-dictate`

## Architecture

```
┌────────── laptop (niri + Noctalia) ──────────┐   ┌──────── Prometheus ───────────┐
│                                              │   │                               │
│  mic ──► PipeWire (16 kHz mono) ──► VAD      │   │  whisper.cpp server           │
│                                     │        │   │  :11435  (Vulkan, large-v3-   │
│                                     ▼        │   │          turbo GGUF + Sanskrit│
│  ┌────────────────────────────┐               │   │          fine-tune)           │
│  │ fast draft (Moonshine v2)  │               │   │                               │
│  │ ~150–250 ms first partial  │               │   │  llama-server router :11434   │
│  │ → gray text in floating    │               │   │  ├─ qwen3.5-122b-a10b (MoE)   │
│  │   Noctalia overlay         │               │   │  ├─ qwen3-8b-corrector        │
│  └────────────────────────────┘               │   │  │  (pinned, GenSEC prompt)   │
│                   │                           │   │  └─ qwen3-embedding-0.6b      │
│                   ▼                           │   │                               │
│  audio buffer ──► WebSocket ────────────────► │   │  LanceDB style-corpus         │
│                                               │   │  /var/lib/dictate/corpus.lance│
│                   ◄──────────────── final ────┤   │                               │
│                   │                           │   └───────────────────────────────┘
│                   ▼
│  overlay commits via ydotool → focused app
│  Noctalia toast: "accept revision? / reject"
│
└──────────────────────────────────────────────┘
```

### Subsystems

1. **Capture** — PipeWire source client, 16 kHz mono S16LE, 20 ms frames,
   Silero or TEN VAD for endpointing, push-to-talk primary + toggle
   fallback. Written in Rust against `pipewire-rs`.

2. **Draft** — local fast ASR. Moonshine v2 Small ONNX for English,
   Parakeet-TDT-0.6B-v3 via `onnx-asr` for Romance. Emits token partials
   over an in-process channel within ~150–250 ms of each frame window,
   without network.

3. **Correct** — two-round pipeline on Prometheus:
   - ASR: whisper.cpp server with `large-v3-turbo` GGUF on Vulkan, called
     with `language="en"`, `initial_prompt=<context>`,
     `hotwords=<rare terms>`. Returns 1-best + 5-best in 200–500 ms.
   - LLM correction: `qwen3-8b-corrector` (pinned in the router), GenSEC
     N-best prompt with injected glossary + retrieved style chunks.
     Returns polished text in 200–400 ms.

4. **Inject** — takes the committed polished text and types it into the
   currently focused Wayland surface via `ydotool` (kernel uinput). Avoids
   `wtype` because of the niri bug cluster (see §Text injection).

5. **Learn** — logs every `(raw, draft, committed, edited_later)` tuple to
   CozoDB. Edits captured via a filesystem hook on the user's note
   directories and jj commit hook. Over weeks, feeds the RAG corpus and
   eventually a QLoRA on the corrector.

6. **MCP interface** — query tools for introspection: last transcription,
   current glossary, recent edit log, session history, force specific
   model, manual override.

## Latency budget

| Stage                                              | Target       | Bound by                    |
|----------------------------------------------------|--------------|-----------------------------|
| Audio tail → server                                | 10–30 ms     | LAN, quantum=128            |
| Local draft partials (Moonshine Small)             | 150–250 ms   | CPU inference + 80 ms LA    |
| Whisper-Vulkan on Prometheus (5 s utterance)       | 200–500 ms   | Vulkan kernel               |
| Qwen3-8B correction (≤60 output tokens)            | 200–400 ms   | Vulkan decode               |
| Return + overlay swap                              | 30 ms        | ydotool kernel              |
| **End-to-end polished text**                       | **500–1100 ms** |                          |

The draft appears essentially live (gray). Final polished text replaces
the draft within ~1 s of utterance end. This matches the user's 1–2 s
ceiling and leaves headroom for a small RAG retrieval (~100 ms) in
Phase 2.

## Model choices — rationale

| Role                           | Model                                   | Params | Reason                                                |
|--------------------------------|-----------------------------------------|--------|-------------------------------------------------------|
| Laptop draft (English)         | Moonshine v2 Small (ONNX)               | 123 M  | Only open model that clears ≤200 ms TTFT on CPU       |
| Laptop draft (Romance)         | Parakeet-TDT-0.6B-v3 (onnx-asr int8)    | 600 M  | 25 EU langs, ONNX Runtime CPU viable                  |
| Server ASR                     | whisper.cpp large-v3-turbo (GGUF Vulkan)| 809 M  | 99 langs, mature Vulkan, ~1.6 GB, works on Strix Halo |
| Server corrector (per-utterance)| Qwen3-8B-Instruct (GGUF Q5_K_M)        | 8 B    | ~200 ms Vulkan decode, GenSEC sweet spot              |
| Server corrector (paragraph)   | Qwen3.5-122B-A10B (already resident)    | 122 B  | Hard cases + Pass-3 style polish, ~1.5 s accepted     |
| Sanskrit specialist (opt-in)   | whisper-medium fine-tune on Vāksañcayaḥ | 769 M  | 15.4 % WER on Sanskrit; on-demand only                |
| Embeddings (Phase 2 RAG)       | Qwen3-Embedding-0.6B                    | 600 M  | Served via llama-server `--embeddings`                |

What explicitly is not chosen and why:

- **Canary / Canary-Qwen**: English-only or 25-EU-only; no Sanskrit, no
  Hindi fallback. Also NeMo-PyTorch-only — extra runtime to maintain.
- **Voxtral-Mini-Realtime**: vLLM-only, no GGUF, vLLM on Strix Halo Vulkan
  is not production-ready. Track llama.cpp#20914; re-evaluate in Q3 2026.
- **Kyutai STT**: English or English+French only. Narrower than our needs.
- **SeamlessM4T v2**: PyTorch-only, heavy, code-switching is not its
  advertised capability.
- **IndicConformer-sa as primary**: zero English/Spanish/French support.
  Keep it as a Phase 4 opt-in specialist pass only.
- **Cloud multimodal (Gemini/GPT-4o/Claude audio)**: violates on-prem
  default; keep as an explicit escape hatch for designated material.

## Memory budget on Prometheus

Currently resident: Qwen3.5-122B-A10B at 76.5 GB. Adding for dictate:

| Model                          | Size       | Policy             |
|--------------------------------|------------|--------------------|
| whisper-large-v3-turbo GGUF    | ~1.6 GB    | Pinned             |
| qwen3-8b-corrector Q5_K_M      | ~6.0 GB    | Pinned             |
| qwen3-embedding-0.6b           | ~0.6 GB    | Pinned             |
| bge-reranker-v2-m3 (opt)       | ~0.5 GB    | On-demand          |
| whisper-medium-sa fine-tune    | ~1.5 GB    | On-demand          |
| **New total pinned**           | **~8.2 GB** |                   |

With the 76.5 GB MoE: ~85 GB resident, ~43 GB free. Fits comfortably
inside the `MemoryMax=110G` guardrail without evicting. Router LRU
behavior unchanged — the existing 122B can still hot-swap with other
one-off models; only the corrector/ASR/embedding models are newly pinned.

Update `data/config/largeAI/llm.json` to add:
- a `pinned` boolean per model (extended router feature),
- a `purpose` tag (`asr | corrector | embedding | chat`) so the dictate
  daemon can query capability rather than specific model names.

## Text injection (Wayland / niri specifics)

niri does not implement `zwp_text_input_v3` or `zwp_input_method_v2`
(tracker: niri#2476). `wtype` uses `zwp_virtual_keyboard_v1`, which niri
does support, but there is an active bug cluster that makes it
unreliable: niri#2280, #2314, #1546, #3394. Concretely, after a wtype
burst the focused app can lose its real keyboard input until refocused.

**Decision**: use `ydotool` via `/dev/uinput`. Compositor-agnostic,
handles arbitrary Unicode (including Devanagari and IAST diacritics)
via a synthetic XKB layout uploaded per session, and survives every
niri wtype bug because it does not go through Wayland.

`ydotoold` runs as a per-user systemd service (NixOS has
`programs.ydotool.enable = true`). The daemon socket is
`/run/user/$UID/.ydotool_socket`; dictate talks to it via the
`ydotool` CLI or a small Rust wrapper.

Fallback injection paths, in order:

1. `ydotool type --file -` (default).
2. `wl-copy <text> && ydotool key ctrl+v` (when the focused app is a
   terminal that filters synthesized keystrokes, or when Unicode fails).
3. Return the text in a Noctalia toast with a "copy" button (last resort).

Revisit when niri ships text-input-v3 support. Track niri#2476 and the
`--wayland-text-input-version=3` experimental flag.

### The stream-then-revise UX problem

Two existing UX patterns and their failure modes on Linux:

- **Floating preview, commit on finalize** (Superwhisper, Speed of Sound):
  safe but feels laggy; text appears all at once.
- **Stream-then-revise in-place** (Deepgram Flux demo): feels live but
  emits backspaces into whatever has focus — destructive in terminals
  running builds, in Emacs with active kbd macros, anywhere backspace
  means something other than "delete previous character".

No FOSS Linux dictation app ships a clean third pattern, so we design one:

**Commit fast draft, offer revision as a dismissible toast.** The fast
draft types in immediately. When the polished pass arrives ~500 ms
later, Noctalia surfaces a toast: "Revision available — ⏎ accept,
Esc reject." On accept, dictate emits a diff-minimal sequence of
backspaces + retype through ydotool (only if the target window is still
focused; otherwise requires manual trigger). On reject or timeout
(~4 s), the draft stands. This keeps the live feel while refusing to
type backspace into the wrong place.

Advanced mode: hold a modifier while speaking to suppress fast-draft
injection entirely. Text appears only on final commit. Useful for
terminal dictation.

## Capture pipeline

PipeWire source, native Rust client via `pipewire-rs`. `quantum=128` at
48 kHz input, resampled to 16 kHz mono for ASR. Silero VAD v5 for
endpointing, threshold 0.5, 200 ms trailing silence = end-of-utterance.
TEN VAD considered as a drop-in when the upstream Apache 2.0 release
stabilizes.

Push-to-talk primary: niri binds `Mod+Space` to
`spawn "criome-dictate" "toggle"`; the daemon owns PTT state and starts
capture on press, finalizes on release. Niri has no native key-release
action, so the daemon debounces via a 150 ms hold timer and treats a
tap as toggle-start, a hold as PTT. Second binding `Mod+Shift+Space`
calls `criome-dictate abort`.

No VAD-triggered always-on mode in Phase 1. Privacy and drift risk
outweigh convenience. Revisit if push-to-talk proves too interruptive.

## Glossary and vocabulary curation

Single source of truth: a CozoDB relation plus a mirrored JSONL at
`/var/lib/criome-dictate/glossary.jsonl` for human editing and VCS.

```cozoscript
:create dictate_glossary {
    canonical: String
    =>
    variants: List<String>,
    phonetic: String,
    language: String,
    domain: List<String>,
    definition: String,
    seen: Int,
    promoted: Bool,
    last_used: String,
    phase: String,
    dignity: String
}
```

Example entries:

```json
{"canonical":"saṃskāra","variants":["samskara","sumskara","sanskara"],"language":"sa-IAST","domain":["yoga","philosophy"],"seen":7,"promoted":true}
{"canonical":"Noctalia","variants":["noctilia","knock talia"],"language":"en","domain":["criomos","desktop"],"seen":3,"promoted":true}
{"canonical":"jj","variants":["jay jay"],"language":"en","domain":["tooling","vcs"],"seen":42,"promoted":true}
{"canonical":"CriomOS","variants":["crime os","cry um os"],"language":"en","domain":["criomos"],"seen":29,"promoted":true}
```

**Growth rule**: each time the corrector rewrites token `X → Y` where `Y`
exists in the glossary as a variant of canonical `Z`, increment `seen`
on `Z`. When `X` is not already a known variant, add it to the variants
list with `seen=1, promoted=false`. On second occurrence
(`seen >= 2`), promote.

**Seeding**: initial ~100 entries covering Yoga Sūtras / Bhagavad-Gītā
vocabulary, Mentci/CriomOS jargon, Nix/Rust/jj terms. Bootstrap via
a one-shot script against Monier-Williams for definitions where useful.

**Consumption**:
- **ASR**: at each utterance, the daemon selects ≤30 glossary entries
  by domain-tag match against current context (focused window class,
  working directory, recent jj commit subjects), composes an
  `initial_prompt` of ≤200 tokens, plus a `hotwords` list of the 10
  rarest promoted canonicals.
- **Corrector**: entire promoted glossary injected as a terse
  `<glossary>` block in the system prompt. Fits comfortably in
  Qwen3-8B's context.

## Correction prompt

Canonical skeleton for the corrector, adapted from GenSEC + task-activating
literature:

```
System: You are a post-ASR corrector for Li. You receive a whisper.cpp
hypothesis (1-best + optional N-best) and a personal glossary. Return
exactly one polished transcript matching Li's writing style:
- Same language as the audio. Preserve code-mixed tokens.
- Sanskrit in IAST (ātman, prāṇāyāma, saṃskāra). Never ASCII-fold.
- Spanish and French diacritics preserved (María, ça, père).
- Never paraphrase. Never translate. Fix only misrecognitions,
  punctuation, and casing.
- If the ASR posterior is high and the 1-best is plausible, return it
  verbatim — do not "improve" clean text.

User:
<glossary>
  ātman, Bhagavad-Gītā, citta-vṛtti, dharma, karma, mokṣa, prajñā,
  prāṇāyāma, saṃsāra, saṃskāra, CriomOS, Mentci, Noctalia, niri, jj,
  llama.cpp, Prometheus, Strix Halo, …
</glossary>
<nbest>
  <h score="-2.31">tell me about som skritta grammar</h>
  <h score="-2.44">tell me about samskrita grammar</h>
  <h score="-2.51">tell me about sanskrit grammar</h>
</nbest>
Output the corrected transcript on a single line:
```

Confidence gating: if whisper.cpp reports per-token logprob mean above
a threshold on the 1-best, skip the LLM round. The literature is
consistent that over-correction of already-clean transcripts is a real
failure mode (Ma et al. arXiv 2407.21414). Saves latency and preserves
exact style on easy utterances.

## Sanskrit handling

Two modes:

1. **Default mixed-language mode** (what happens 99 % of the time): the
   pipeline above runs with whisper forced `language="en"`; phonetic
   approximations of Sanskrit terms come out of whisper as English-ish;
   the corrector rewrites them to IAST using the glossary and the
   system-prompt rules. Works well for sentences like "I was working on
   prāṇāyāma this morning and noticed the citta-vṛtti smooth out."

2. **Sanskrit specialist mode** (opt-in, for dedicated dictation of
   philosophical passages): the user holds `Mod+Alt+Space` instead of
   `Mod+Space`. Router routes the utterance to a dedicated
   Vāksañcayaḥ-fine-tuned `whisper-medium` endpoint, output is
   Devanagari, then `aksharamukha` transliterates to IAST, then
   corrector normalizes with the Sanskrit-weighted glossary. Expected
   WER ~15 % (Vāksañcayaḥ paper), higher out-of-domain.

Script modes for IAST vs Devanagari vs ASCII-fold are configurable
per-user globally and per-session via MCP. Default `iast`. Never default
to lossy ASCII — it collapses ātman/atman distinctions.

## RAG style corpus (Phase 2)

`/var/lib/criome-dictate/corpus.lance` (LanceDB). Chunking: ~300 tokens
with 50-token overlap. Metadata: source path, language, domain tags,
date. Embeddings via `qwen3-embedding-0.6b` on the router.

Retrieval per correction:
1. Encode current utterance (10 ms).
2. Top-5 ANN over corpus (30 ms LanceDB) filtered by domain tags derived
   from current context.
3. Optional rerank with `bge-reranker-v2-m3` (100 ms) — skip for
   per-utterance, keep for Pass-3 paragraph polish.
4. Inject retrieved chunks as few-shot examples in the corrector prompt.

Bootstrap the corpus from:
- `~/org/**/*.org` notes
- jj commit messages from ~/git/**
- blog/ and essays/ directories if present
- recent dictate-committed paragraphs (self-reinforcing)

Re-index weekly via a systemd timer. Keep the index small (< 200 MB
for hundreds of thousands of chunks — LanceDB is compact).

## Optional Pass 3 (frontier polish)

User-triggered only. `criome-dictate polish` takes a buffer or selection
and sends it to one of:

- The resident 122B MoE (free, no egress, ~5–15 s).
- Claude (best voice preservation) via the existing pi-mentci path.
- Gemini 2.5 (cheap long context for whole-document polish).

Never on the per-utterance hot path. Three-tuple commit format for the
output: `(("dictate", "polish"), …, …)`. Pass-3 is explicit, async, and
opt-in — the 1 s budget dies the moment TLS + queueing enter.

## CozoDB relations

```cozoscript
:create dictate_session {
    session_id: String
    =>
    started_ts: String,
    ended_ts: String,
    trigger_window_class: String,
    working_dir: String,
    phase: String,
    dignity: String
}

:create dictate_utterance {
    utterance_id: String
    =>
    session_id: String,
    started_ts: String,
    duration_ms: Int,
    audio_sha256: String,
    language_detected: String,
    phase: String,
    dignity: String
}

:create dictate_hypothesis {
    utterance_id: String,
    source: String         // "draft" | "whisper" | "corrector"
    =>
    text: String,
    nbest: Json,
    model: String,
    logprob_mean: Float,
    ms_to_first_token: Int,
    ms_total: Int,
    phase: String,
    dignity: String
}

:create dictate_commit {
    utterance_id: String
    =>
    committed_text: String,
    injected_via: String,   // "ydotool" | "wl-copy" | "toast"
    focused_app: String,
    phase: String,
    dignity: String
}

:create dictate_edit {
    utterance_id: String,
    edited_ts: String
    =>
    post_edit_text: String,
    diff: Json,
    source: String,         // "filesystem-hook" | "jj-hook" | "manual"
    phase: String,
    dignity: String
}

:create dictate_glossary { ... }  // defined above

:create dictate_config {
    key: String
    =>
    value: String,
    phase: String,
    dignity: String
}
```

Retention: raw audio hashes in `dictate_utterance` hold 30 days;
`dictate_hypothesis` 90 days; `dictate_commit` and `dictate_edit` forever
(small, high training value).

## MCP tools

| Tool                  | Description                                                  |
|-----------------------|--------------------------------------------------------------|
| `dictate_start`       | Start a session; returns session_id                          |
| `dictate_stop`        | End current session                                          |
| `dictate_status`      | Current state (idle/listening/correcting), last utterance    |
| `dictate_last`        | Return last committed text + all hypotheses + timings        |
| `dictate_replay`      | Re-run the pipeline on a stored audio hash with current models|
| `dictate_glossary`    | CRUD: list, add, promote, remove glossary entries            |
| `dictate_correct`     | One-shot: given text, run corrector with glossary            |
| `dictate_polish`      | Pass-3: polish a buffer via configured frontier model        |
| `dictate_teach`       | Record a user correction as a training signal                |
| `dictate_config`      | Read/write config (script mode, default language, hotkeys)   |

MCP over a Unix socket at `/run/user/$UID/criome-dictate.sock`, stdio
bridge for pi-mentci consumption.

## systemd integration (NixOS)

User service, not system. Capture + ydotool all work unprivileged with
the user in the `input` group for `/dev/uinput`, which is the only
privileged path and is already handled by `programs.ydotool.enable`.

```nix
systemd.user.services.criome-dictate = {
    description = "CriomOS voice-typing daemon";
    after = [ "pipewire.service" "ydotool.service" ];
    wants = [ "pipewire.service" "ydotool.service" ];
    wantedBy = [ "default.target" ];
    serviceConfig = {
        Type = "notify";
        ExecStart = "criome-dictate daemon";
        StateDirectory = "criome-dictate";
        Restart = "on-failure";
    };
};
```

On Prometheus: extend `nix/mkCriomOS/llm.nix` to read an `asr` section
from `data/config/largeAI/llm.json` and spawn:

- `prometheus-whisper-server` — whisper.cpp server with
  `large-v3-turbo.gguf` on :11435.
- Optional `prometheus-whisper-sanskrit` — Vāksañcayaḥ fine-tune on
  :11436, socket-activated.

Models pinned via the router's (to-be-extended) `pinned=true` attribute
so LRU never evicts them.

## Home profile packaging

A new Rust crate `src/criome-dictate/` with the daemon. Nix wrapper
`nix/criome-dictate.nix`. Add to `nix/homeModule/med/default.nix` in
the `worldPackages` list, wired to niri via a new keybind section and
to Noctalia via a QuickShell `IpcHandler` named `dictation` with
methods `interim(text)`, `final(text)`, `revisionOffer(text)`,
`reject()`, `accept()`.

Noctalia fork/extension scope: ~50 lines QML to render the dictation
pill on the bar and the revision toast. Keep the upstream Noctalia-shell
unchanged; put CriomOS-specific panels in
`nix/homeModule/max/noctalia-overlays/`.

## Repo structure

```
criome-dictate/
    Cargo.toml
    flake.nix                   # crane + fenix
    src/
        main.rs                 # daemon entry, MCP stdio bridge
        lib.rs                  # pub mod capture, draft, correct, inject, learn
        capture/
            pipewire.rs         # native PipeWire source
            vad.rs              # Silero / TEN dispatch
        draft/
            moonshine.rs        # ONNX Runtime bindings
            parakeet.rs         # onnx-asr bindings
        correct/
            whisper_client.rs   # HTTP/WebSocket to whisper.cpp server
            corrector_client.rs # OpenAI-compatible to llama-server :11434
            prompt.rs           # GenSEC prompt construction
        inject/
            ydotool.rs          # socket client
            wl_copy.rs          # wl-clipboard fallback
            toast.rs            # Noctalia IPC for revision UI
        learn/
            glossary.rs         # CozoDB CRUD + promote logic
            rag.rs              # Phase 2: LanceDB client
            edits.rs            # filesystem + jj hooks
        mcp.rs
        error.rs
    schema/
        dictate-init.cozo
        dictate-seed.cozo       # initial ~100 glossary entries
    tests/
```

## Dependencies

```toml
[dependencies]
criome-cozo = { path = "flake-crates/criome-cozo" }
rmcp = { version = "0.16", features = ["server", "transport-io", "macros"] }
tokio = { version = "1", features = ["full"] }
pipewire = "0.8"                           # native PipeWire source
ort = "2"                                  # ONNX Runtime bindings for Moonshine/Parakeet
reqwest = { version = "0.12", features = ["json", "stream"] }
tokio-tungstenite = "0.21"                 # WebSocket to whisper.cpp server
serde = { version = "1", features = ["derive"] }
serde_json = "1"
schemars = "1"
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter"] }
chrono = "0.4"
zbus = "4"                                 # D-Bus for compositor signals and Noctalia
clap = { version = "4", features = ["derive"] }
```

No Python in the daemon. Transliteration (`aksharamukha`) runs out-of-
process via a thin subprocess shim wrapped in Nix, since porting to
Rust is not worth the maintenance cost and it's only invoked in
Sanskrit specialist mode.

No ML framework beyond ONNX Runtime. No tract. No candle. The corrector
runs remote on Prometheus; the laptop does not train or do heavy math.

## Phasing

### Phase 1 — Proof of concept (single-language, no style)

Ship when:
- `criome-dictate daemon` runs under systemd user, bound to `Mod+Space`.
- Moonshine v2 Small draft typing live into Emacs/VS Code via ydotool.
- whisper.cpp server on Prometheus :11435 returning 1-best.
- Static glossary of ~20 Sanskrit terms seeded into
  `initial_prompt`/`hotwords`.
- Noctalia toast shows "Listening → Transcribing → Done".

No corrector, no RAG, no edit learning. Value: prove the PipeWire →
ydotool → Wayland path on niri works for Li's workflow, prove Strix Halo
Vulkan whisper latency.

### Phase 2 — Corrector + glossary growth

Ship when:
- `qwen3-8b-corrector` pinned on Prometheus, GenSEC prompt.
- Glossary in CozoDB with auto-promote logic, MCP CRUD.
- Revision-toast UX working via Noctalia IPC.
- `aksharamukha` shim for IAST mode.
- Sanskrit + English code-mixed utterances round-trip correctly on a
  hand-curated test suite of 20 sentences.

### Phase 3 — RAG + edit learning

Ship when:
- LanceDB corpus built from user's org notes + jj commit messages.
- `qwen3-embedding-0.6b` on the router.
- Dynamic few-shot selection in corrector prompt.
- Filesystem hook + jj hook capturing post-commit edits into
  `dictate_edit`.
- Sanskrit specialist mode via Vāksañcayaḥ fine-tune on :11436.

### Phase 4 — Personal LoRA

Ship when ≥ 1000 `(raw, draft, committed, edited)` pairs have
accumulated. Train a QLoRA on the 8B corrector either:
- On Strix Halo via ROCm + Unsloth in a Nix-packaged toolbox, or
- Cloud H100 one-shot via a CriomOS-flavored runpod wrapper,
then load with `llama-server --lora`. A/B compare against non-LoRA
corrector; keep whichever wins on held-out utterances.

### Phase 5 — Preference learning (KTO)

Once ≥ 300 edit-pair signals exist, KTO-tune the 8B on preferences
derived from edits. The unary nature of KTO fits edit-stream data
better than DPO pairs. Gate behind an A/B harness.

## Dangerous operations — DO NOT DO

- **Never stream-then-revise in-place with backspaces** into a focused
  window without an opt-in toggle — terminals interpret backspace as a
  destructive operation that's hostile to pipelines.
- **Never send SIGHUP to the daemon** to reload config; use MCP
  `dictate_config` or restart the user service. SIGHUP is reserved for
  "rotate logs".
- **Never fetch ASR or corrector GGUF hashes from web searches** —
  follow the FOD pattern in `docs/AGENTS.md`: `nix-prefetch-url` on
  Prometheus, pin HF URLs to specific commits, add GC root.
- **Never enable cloud fallback by default.** Pass-3 frontier polish is
  opt-in per invocation.
- **Never commit raw audio files** to any repo or nix store. Hashes
  only; audio tmpfs-backed, retention-capped.

## Open questions

1. **Drift in the draft/final contract**: if Moonshine produces text
   that's semantically right but lexically different from whisper's
   output, the user sees the gray text change to different black text.
   Do we prefer whisper's rendering (usually correct) or preserve the
   draft's rhythm when both are plausible? Phase-2 question; initial
   rule: whisper wins on content, draft wins on nothing.

2. **Sanskrit mode auto-detect**: rather than require a modifier key,
   could we detect "this utterance is >30% Sanskrit" from the first-pass
   whisper output and auto-reroute? Probably yes, but adds a
   per-utterance decision branch that's hard to unit-test.
   Defer to Phase 4.

3. **Terminal dictation**: backspace, ctrl-C, tab completion interact
   badly with any injection. Open question whether to detect focused
   terminal via `xdg-toplevel` app_id and silently switch to wl-copy +
   explicit-paste mode. Phase-2 configurable, not automatic in Phase 1.

4. **Hyprvoice as a starting point**: should Phase 1 ship as a
   Hyprvoice configuration + Noctalia integration rather than a bespoke
   Rust daemon? Zero code, 80 % coverage, but locks into Hyprvoice's
   backend list and architecture. Probably worth a 2-day spike before
   committing to the bespoke plan — if Hyprvoice handles ydotool on
   niri cleanly and its LLM-correction pass can take our corrector
   endpoint, we save weeks.

5. **Multi-device**: if the user dictates on a second node (e.g. a
   future laptop), the glossary and corpus should sync. Same CozoDB
   replication pattern Samskara uses. Design constraint for Phase 2,
   not blocking.

## See also

- Research appendix: [voice-typing-research.md](voice-typing-research.md)
- Adaptive charging daemon (shared Rust + CozoDB + MCP architecture):
  [adaptive-charging.md](adaptive-charging.md)
- LLM runtime guidelines: [../docs/LLAMA_RUNTIME_PROMETHEUS.md](../docs/LLAMA_RUNTIME_PROMETHEUS.md)
- llm.json schema: `data/config/largeAI/llm.json`
