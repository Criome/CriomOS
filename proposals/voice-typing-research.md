# Voice-Typing — Research Appendix

Deep research backing the decisions in [voice-typing.md](voice-typing.md).
Organized into five streams:

1. Laptop-local low-latency ASR
2. Server-side accurate ASR + LLM post-correction on Strix Halo
3. Linux/Wayland voice-typing apps and text injection
4. Multilingual code-switching and Sanskrit ASR
5. Style and vocabulary adaptation

Every model claim, benchmark number, and compositor bug below is
sourced. The main design document references this appendix for
rationale; this file is where the "why" lives in detail.

Research date: April 2026.

---

## 1. Laptop-local low-latency ASR

### 1.1 The 2026 model landscape

The "offline-first Whisper" assumption from 2023 is no longer the
frontier for real-time voice-typing on a laptop. Four model families
dominate the low-latency open-source space in early 2026:

1. **Moonshine v2** (Useful Sensors, Feb 2026) — ergodic streaming
   encoder, sub-100 ms TTFT at Tiny, English-only.
2. **Kyutai STT 1B en_fr** — delayed-streams modeling, 500 ms native
   delay (down to ~125 ms with "flush trick"), CC-BY-4.0 weights.
3. **Voxtral-Mini-4B-Realtime-2602** (Mistral, Feb 2026) — Apache 2.0,
   configurable 80–2400 ms, 13 languages including Hindi/Arabic.
4. **Parakeet-TDT-0.6B-v3** (NVIDIA, Aug 2025) — best accuracy/RTFx
   ratio; community ONNX CPU builds now make it viable without CUDA.

### 1.2 Comparison table

| Model | Params | License | Streaming | Linux/Vulkan | RTF (CPU) | First-partial | Multilingual | Notes |
|---|---|---|---|---|---|---|---|---|
| Moonshine v2 Tiny | 34 M | MIT | Native | ONNX RT, pure CPU | ~0.05 | ~50 ms on M3, 80–120 ms on Ryzen | EN only | Ships `.ort` flatbuffers |
| Moonshine v2 Small | 123 M | MIT | Native | ONNX RT | ~0.1–0.2 | ~148 ms on M3 | EN | Sweet spot |
| Moonshine v2 Medium | 245 M | MIT | Native | ONNX RT | ~0.2–0.4 | ~258 ms on M3 | EN | Near-Large quality |
| Kyutai STT 1B en_fr | 1 B | CC-BY-4.0 | Native | PyTorch/Rust/Candle | GPU only | 500 ms (125 ms flush) | EN+FR | Built-in semantic VAD |
| Kyutai STT 2.6B en | 2.6 B | CC-BY-4.0 | Native | PyTorch/Rust | GPU | 2.5 s default | EN | Higher accuracy |
| Voxtral-Mini-Realtime | 4 B | Apache 2.0 | Native causal | vLLM, no GGUF | GPU ≥16 GB | 80–2400 ms cfg | 13 langs incl. Hindi/AR | WER 2.08% LS-clean |
| Parakeet-TDT-0.6B-v3 | 600 M | CC-BY-4.0 | Chunked | NeMo/CUDA + community ONNX | Community "blazing fast" | ~2 s chunks | 25 EU langs | Best WER/size in class |
| Parakeet-TDT-0.6B-v2 | 600 M | CC-BY-4.0 | Chunked | NeMo + ONNX | — | — | EN | "Hour in a second" on H100 |
| Canary-1B-Flash | 883 M | CC-BY-4.0 | Chunked | NeMo + community ONNX | — | 40 s chunk | EN/DE/ES/FR +tx | 1.48% WER LS-clean |
| Whisper-Large-v3-Turbo | 809 M | MIT | Via shims | whisper.cpp Vulkan/ROCm | CPU workable | 500–1000 ms Simul | 99+ | 12% WER |
| Distil-Whisper large-v3.5 | 756 M | MIT | Via shims | CT2 CPU | 1.5× faster than turbo | 1–2 s shim | EN | Released Mar 2025 |
| faster-whisper small.en | 244 M | MIT | Via shims | CPU/CUDA only | 0.2–0.5 | 1–2 s LocalAgreement | 99+ | Stable baseline |
| whisper.cpp base.en | 74 M | MIT | `stream` example | Vulkan + ROCm on Strix Halo | — | ~1 s chunks | 99+ | 12× speedup on 680M |
| Moshi ASR | — | MIT/Apache | Full-duplex | PyTorch/Rust/MLX | GPU | ~160 ms frame | EN | Full speech-text foundation |
| SeamlessStreaming | Large | CC-BY-NC | Native | PyTorch | Heavy GPU | ~2 s | ~100 langs | Non-commercial |
| FunASR Paraformer-large | 220 M | Apache 2.0 | Streaming variant | PyTorch/ONNX | CPU feasible | ~600 ms | Mandarin+multi | Mature |
| Fun-ASR-Nano-2512 | 1 B | Apache 2.0 | Native | PyTorch | — | Low | 31 langs | Tongyi Lab 2025 |

### 1.3 Inference engines

- **GGML / GGUF (whisper.cpp)**. Whisper-only in practice; no Moonshine,
  Parakeet, Voxtral ports. Vulkan backend works on AMD iGPU
  ([Phoronix 12× uplift on Radeon 680M][phor]). ROCm works on Strix
  Halo per [whisper.cpp#3460][wcpp-sh] — 35-min audio in ~35 s with
  base. [jason-ni/parakeet.cpp][parakcpp] exists but immature.
- **CTranslate2 (faster-whisper)**. Whisper, distil-whisper, some
  seq2seq. No ROCm, no Vulkan — CUDA and CPU only
  ([AMD GPU tracker][amd-gpu]). Community ROCm forks are hacky.
  AVX2/AVX-512 optimized on Ryzen. int8 base.en runs ~0.2 RTF on
  mid-tier Ryzen.
- **ONNX Runtime**. Emerging universal runtime for the 2026 zoo.
  Moonshine ships `.ort` flatbuffers. Parakeet v2/v3 via
  [`onnx-asr`][onnxasr] (`pip install onnx-asr[cpu,hub]`). Canary-1B-v2
  via [istupakov/canary-1b-v2-onnx][canonnx]. ROCm EP exists but
  fragile; Vulkan EP is not production on Linux as of early 2026.
  For AMD laptops, CPU EP with int8 is the pragmatic path.
- **TensorRT**. NVIDIA only.
- **CoreML / MLX**. Not Linux.

Summary for AMD Vulkan: whisper.cpp is the only ASR engine with solid
Vulkan on Linux. For non-Whisper (Moonshine, Parakeet ONNX), CPU-int8
is realistic.

[phor]: https://www.phoronix.com/news/Whisper-cpp-1.8.3-12x-Perf
[wcpp-sh]: https://github.com/ggml-org/whisper.cpp/discussions/3460
[parakcpp]: https://github.com/jason-ni/parakeet.cpp
[amd-gpu]: https://llm-tracker.info/howto/AMD-GPUs
[onnxasr]: https://pypi.org/project/onnx-asr/
[canonnx]: https://huggingface.co/istupakov/canary-1b-v2-onnx

### 1.4 VAD and chunking

| VAD | Size | Latency | License | Notes |
|---|---|---|---|---|
| [Silero VAD v5][silero] | ~2 MB | <1 ms/30 ms chunk | MIT | Proven; several-hundred-ms endpoint delay in TEN comparison |
| [TEN-VAD][tenvad] | Smaller | Faster transitions | Apache 2.0 | 2025 release, better boundary precision |
| webrtcvad | Tiny | <1 ms | BSD | Legacy; precision poor |
| Kyutai semantic VAD | Built-in | 500 ms | CC-BY-4.0 | Kyutai-only |
| Voxtral built-in | Built-in | — | Apache 2.0 | Voxtral-only |

Chunking strategies:
- **LocalAgreement-n** ([whisper_streaming][wsstream]): confirm prefix
  when N consecutive hypotheses agree. Latency ≈ 2× chunk size.
- **AlignAtt / SimulStreaming** ([ufal/SimulStreaming][simulstream]):
  attention-alignment-based; ~5× faster than whisper_streaming.
  Default in WhisperLiveKit 2026.
- **Hold-n**: older, mostly superseded.
- **Native streaming encoders** (Moonshine, Kyutai, Voxtral): no shim.

[silero]: https://github.com/snakers4/silero-vad
[tenvad]: https://github.com/TEN-framework/ten-vad
[wsstream]: https://github.com/ufal/whisper_streaming
[simulstream]: https://github.com/ufal/SimulStreaming

### 1.5 Benchmarks on modest hardware

| Model | Hardware | First-partial | RTF | Source |
|---|---|---|---|---|
| Moonshine v2 Tiny | Apple M3 CPU | 50 ms | ~0.05 | [arXiv 2602.12241][moon2] |
| Moonshine v2 Small | Apple M3 CPU | 148 ms | ~0.1 | same |
| Moonshine v2 Medium | Apple M3 CPU | 258 ms | ~0.2 | same |
| Kyutai STT 1B | L40S GPU | 500 ms (125 ms flush) | batch-64 3× RT | [kyutai.org/stt][kyutai-stt] |
| Voxtral-Mini-Realtime 480 ms | Single 16 GB GPU | 480 ms | 12.5 tok/s | [HF card][voxtral-rt] |
| Parakeet-TDT-0.6B-v2 ONNX int8 | Consumer Ryzen CPU | ~2 s chunk | "blazing fast" | [achetronic/parakeet][achepar] |
| whisper.cpp base.en Vulkan | Ryzen 7 6800H + 680M | ~1 s chunk | 3–4× RT | [Phoronix][phor] |
| whisper.cpp base.en ROCm | Strix Halo gfx1151 | — | 60× RT | [#3460][wcpp-sh] |
| faster-whisper small.en int8 | Ryzen CPU | ~1.5 s | ~0.3 RTF | [neurlcreators][nc] |

WER on multilingual content:
- English (LibriSpeech-clean): Voxtral-Mini-Realtime 2.08%, Moonshine
  Medium 2.08%, Parakeet-v3 1.93%, Whisper-v3-Turbo ~5%, Moonshine Tiny
  4.49%.
- Romance (FLEURS avg): Parakeet-v3 ~11.97%, Voxtral-Mini-Realtime ~8.7%.
- Hindi: Voxtral-Mini-Realtime yes; Parakeet no; Whisper-v3 yes (mixed).
- Sanskrit: no model natively good (see §4).

[moon2]: https://arxiv.org/abs/2602.12241v1
[kyutai-stt]: https://kyutai.org/stt
[voxtral-rt]: https://huggingface.co/mistralai/Voxtral-Mini-4B-Realtime-2602
[achepar]: https://github.com/achetronic/parakeet
[nc]: https://neurlcreators.substack.com/p/how-do-you-build-a-real-time-speech

### 1.6 Linux packaging status (nixpkgs)

- `openai-whisper-cpp` — present, CUDA optional, ROCm variant has
  [build failures late 2025][nixpkgs-497745].
- `openai-whisper` Python — present.
- `wyoming-faster-whisper` — present as
  `services.wyoming.faster-whisper`.
- Moonshine, Parakeet, Voxtral, Kyutai, WhisperLiveKit — **none in
  nixpkgs**. All are `pip install` paths.
- Rust `moshi-server` — `cargo install`, straightforward Nix wrap.

Easiest to package: whisper.cpp (already in nixpkgs).
Medium: sherpa-onnx (C++, ONNX).
Harder: Moonshine, onnx-asr + Parakeet (Python + ONNX).
Hardest: Voxtral (vLLM + CUDA or Transformers v5), Kyutai Python chain.

[nixpkgs-497745]: https://github.com/NixOS/nixpkgs/issues/497745

### 1.7 Conclusion for laptop tier

**Moonshine v2 Small ONNX on CPU** is the only open model clearing
sub-200 ms first-partial latency on a Ryzen laptop without a dGPU.
Binding constraint: English-only.

If multilingual is required: **Parakeet-TDT-0.6B-v3 via onnx-asr int8**
on CPU — 25 EU languages, ~1–2 s chunk latency, CC-BY-4.0. Accept the
latency bump as the price of multilingual.

For the rest (Hindi, Arabic, Sanskrit): punt to Prometheus. The laptop
draft does not need to handle every language; it needs to be fast and
"mostly right" so the user sees something immediately.

---

## 2. Server-side ASR + LLM correction on Strix Halo

Full report lives here; the design doc takes the conclusions.

### 2.1 Candidates and verdict matrix

| Model | Multilingual | GGUF / Vulkan | Streaming | Sanskrit | Fit |
|---|---|---|---|---|---|
| whisper large-v3 / turbo | 99 | Yes | Chunked | Mediocre, fine-tunable | **Primary candidate** |
| Parakeet-TDT-0.6B-v3 | 25 EU | ONNX (CPU) | Yes (Rust) | No | Strong secondary |
| Canary-Qwen-2.5B | EN only | No | No | No | Skip |
| Voxtral-Mini-3B | 8 | Yes (GGUF, mtmd) | No (30-s chunks) | No | Good Pass-2 rewriter |
| Voxtral-Mini-4B-Realtime | 13 | Not yet | Yes (vLLM) | No | Watch, don't deploy |
| Kyutai STT 2.6B / 1B | EN / EN+FR | No (PyTorch) | Yes (500 ms) | No | Niche |
| SeamlessM4T v2 | ~100 | No | No | Yes | Only for Sanskrit fallback |
| Qwen3-Omni Captioner | Many | Yes (GGUF) | No | Weak | **Good Pass-2 audio-grounded rewriter** |

**Whisper-large-v3 / turbo** remains the default multilingual baseline:
9.0% CV-15 WER for large-v3, 10.2% for turbo (216× realtime on GPU)
([HF card][whisper-turbo], [Artificial Analysis][aa]). Ships in
whisper.cpp (Vulkan, GGUF, first-class Strix Halo support),
faster-whisper (CPU-only on AMD iGPU: ~2–4× RT with large-v3),
WhisperX (adds VAD + alignment + diarization; heavier than needed).

Sanskrit status: officially supported, poor out-of-box.
[arXiv 2501.10024][sa-whisper] reports 15.42% WER after fine-tuning
`whisper-medium` on Vāksañcayaḥ. Realistic Sanskrit story requires a
domain-specific fine-tune.

**Canary-Qwen-2.5B** tops the OpenASR leaderboard at 5.63% WER but is
effectively English-only and NeMo-PyTorch-only. No GGUF, no Vulkan.
Skip for voice-typing with ES/FR/Sanskrit requirements.
[Canary-1B-v2 (arXiv 2509.14128)][can-paper] is the newer multilingual
cousin but same constraints.

**Parakeet-TDT-0.6B-v3** is the interesting one for server-side in
addition to laptop. Covers 25 EU languages, 9.7% avg WER, 6.34% on
well-covered set. Available via:
- [onnx-asr][onnxasr] — ONNX Runtime, working Vulkan/DirectML provider,
  solid CPU path.
- [altunenes/parakeet-rs][parak-rs] — Rust + ONNX, fast even on CPU.
- [parakeet-tdt-0.6b-v3-fastapi-openai][parak-fastapi] — OpenAI-
  compatible FastAPI wrapper.

No Sanskrit. For English/ES/FR, arguably the highest-accuracy /
lowest-memory option without CUDA.

**Voxtral**. Three variants:
- [Voxtral-Small-24B-2507][vox-small] and
  [Voxtral-Mini-3B-2507][vox-mini] — GGUF via bartowski and stduhpf;
  llama.cpp supports via `libmtmd` ([multimodal.md][llama-mmd]).
  Caveat ([llama.cpp#13759][llama-13759], [FOSDEM 2026][fosdem26]):
  llama-server audio in 30-second chunks, no streaming. Good for
  utterance-at-a-time, not live partials.
- [Voxtral-Mini-4B-Realtime-2602][voxtral-rt] — Feb 2026, Apache 2.0,
  natively streaming, configurable 80–2400 ms delay, 4.9% WER English
  at 480 ms, 13 languages ([Red Hat guide][rh-vox], [MarkTechPost][mtpv]).
  Served via vLLM `/v1/realtime`. Tracking
  [llama.cpp#20914][llama-20914] for GGUF support; today vLLM-only and
  vLLM on Strix Halo Vulkan is not well-trodden.

**Kyutai STT**. [stt-2.6b-en][kyutai-26] (2.5 s delay, English) and
[stt-1b-en_fr][kyutai-1b] (500 ms, EN+FR, built-in semantic VAD).
MIT/Apache/CC-BY-4.0. Built on Moshi/Mimi and
[delayed-streams-modeling][kyutai-dsm]. Rust server, websocket API.
No GGUF — PyTorch/CUDA or MLX. On Strix Halo: PyTorch-ROCm; model
small enough the KV-cache bug doesn't bite.

**SeamlessM4T v2 Large**. [facebook/seamless-m4t-v2-large][seam].
~100 languages incl. Sanskrit (text), Hindi (speech). But >10 GB VRAM,
PyTorch-only, translation + ASR bundled. Use only if translation is
a side-effect you want. Not recommended as primary.

**Audio-capable LLMs**:
- [Qwen2.5-Omni 3B/7B GGUF][qwen25-omni] and
  [Qwen3-Omni 30B-A3B][qwen3-omni] — GGUF builds, llama.cpp mtmd list.
  Qwen3-Omni has a "Captioner" variant for low-hallucination
  transcription. Qwen3-ASR is inside the family.
- Phi-4 Multimodal, Gemma 3 audio — mtmd-supported but flagged
  "highly experimental, reduced quality".
- Ultravox 0.5, SeaLLM-Audio — also in mtmd list.

Think of these as Pass-2 *audio-grounded* rewriters (good for
utterance-level rewrites given audio + text), not primary ASR.

[whisper-turbo]: https://huggingface.co/openai/whisper-large-v3-turbo
[aa]: https://artificialanalysis.ai/speech-to-text/models/whisper
[sa-whisper]: https://arxiv.org/html/2501.10024
[can-paper]: https://arxiv.org/abs/2509.14128
[parak-rs]: https://github.com/altunenes/parakeet-rs
[parak-fastapi]: https://github.com/groxaxo/parakeet-tdt-0.6b-v3-fastapi-openai
[vox-small]: https://huggingface.co/mistralai/Voxtral-Small-24B-2507
[vox-mini]: https://huggingface.co/bartowski/mistralai_Voxtral-Mini-3B-2507-GGUF
[llama-mmd]: https://github.com/ggml-org/llama.cpp/blob/master/docs/multimodal.md
[llama-13759]: https://github.com/ggml-org/llama.cpp/discussions/13759
[fosdem26]: https://fosdem.org/2026/schedule/event/LRZJEH-llama-cpp-multimodal/
[rh-vox]: https://developers.redhat.com/articles/2026/02/06/run-voxtral-mini-4b-realtime-vllm-red-hat-ai
[mtpv]: https://www.marktechpost.com/2026/02/04/mistral-ai-launches-voxtral-transcribe-2-pairing-batch-diarization-and-open-realtime-asr-for-multilingual-production-workloads-at-scale/
[llama-20914]: https://github.com/ggml-org/llama.cpp/issues/20914
[kyutai-26]: https://huggingface.co/kyutai/stt-2.6b-en
[kyutai-1b]: https://huggingface.co/kyutai/stt-1b-en_fr
[kyutai-dsm]: https://github.com/kyutai-labs/delayed-streams-modeling
[seam]: https://huggingface.co/facebook/seamless-m4t-v2-large
[qwen25-omni]: https://huggingface.co/unsloth/Qwen2.5-Omni-3B-GGUF
[qwen3-omni]: https://github.com/QwenLM/Qwen3-Omni

### 2.2 Running ASR on Strix Halo with Vulkan

whisper.cpp 1.8.3 landed a [12× perf boost on iGPUs][phor]; Vulkan
backend is "~10× faster than CPU" on AMD ([discussion #2375][wc-2375],
[maroonmed writeup][mm]). Positive Strix Halo report in
[whisper.cpp#3460][wcpp-sh] — 1.8.0 working on gfx1151 via ROCm 7.0.1
with `GPU_TARGETS="gfx1151"`. No Vulkan-specific RDNA 3.5 regressions
found; generic Vulkan issues are old (RDNA1 crash [#3611][wc-3611],
`--processors > 1` [#2415][wc-2415], old "bad recognition"
[#2400][wc-2400] largely resolved).

**Memory coexistence with 76.5 GB LLM**: `ggml-large-v3.bin` ~3.1 GB,
`large-v3-turbo` ~1.6 GB, `medium` ~1.5 GB. KV/activation for a single
30-s utterance under 1 GB. On 128 GB unified: total ~80 GB leaves
~48 GB headroom. No need to evict LLM for ASR. Pin the ASR model;
evict only if adding a second large audio LLM.

**CPU-only ASR on Zen5 16-core**: whisper.cpp large-v3 hits ~0.3–0.5
RTF on modern desktop Zen5 — a 10 s utterance transcribes in 3–5 s.
With turbo or medium.en: ~0.1–0.15 RTF. Useful fallback, not primary.

**Vulkan-vs-ROCm ranking on RDNA 3.5**: per Nov-2025
[llama.cpp#15021][llama-15021] and [kyuz0 backend grid][kyuz0],
Vulkan-RADV now beats ROCm/HIP for MoE prompt processing and token
generation on gfx1151. Expect same for whisper.cpp.

[wc-2375]: https://github.com/ggml-org/whisper.cpp/discussions/2375
[mm]: https://www.maroonmed.com/subtitle-edit-and-whisper-cpp-stt-on-amd-and-other-non-nvidia-gpus-with-vulkan/
[wc-3611]: https://github.com/ggml-org/whisper.cpp/issues/3611
[wc-2415]: https://github.com/ggml-org/whisper.cpp/issues/2415
[wc-2400]: https://github.com/ggml-org/whisper.cpp/issues/2400
[llama-15021]: https://github.com/ggml-org/llama.cpp/discussions/15021
[kyuz0]: https://kyuz0.github.io/amd-strix-halo-toolboxes/

### 2.3 OpenAI-compatible ASR servers

| Server | Backend | Transport | Streaming | Verdict |
|---|---|---|---|---|
| [Speaches][spch] (ex-faster-whisper-server) | faster-whisper + Piper/Kokoro | OpenAI REST, SSE, WS live | Yes | **Recommended**, actively maintained, also does TTS |
| faster-whisper-server legacy | faster-whisper | OpenAI REST, SSE, WS | Yes | Superseded by Speaches |
| whisper.cpp server / litongjava | whisper.cpp Vulkan | OpenAI REST | Batch, partial WS fork | Use for Vulkan end-to-end |
| [WhisperX][wx] wrappers | faster-whisper + wav2vec2 + pyannote | REST | Batch | Only if you need word alignment + diarization |
| wyoming-faster-whisper | faster-whisper | Wyoming | HA-style | Not OpenAI-compatible |
| vLLM `/v1/realtime` | Voxtral / Voxtral-Realtime | WS, OpenAI Realtime | Yes | Great API, Strix Halo Vulkan not prod-ready |

Conclusion: run Speaches (CPU) for reliable OpenAI-compat, or
whisper.cpp-server (Vulkan) for iGPU. Both can coexist; router fronts.

[spch]: https://github.com/speaches-ai/speaches
[wx]: https://github.com/m-bain/whisperX

### 2.4 LLM post-correction: the GenSEC literature

Key papers, 2024–2025:
- [Chen et al., IEEE SLT 2024, arXiv 2409.09785][gensec] — GenSEC
  challenge, N-best-to-final baseline. Data at
  [huggingface.co/GenSEC-LLM][gensec-hf].
- [Hu et al., arXiv 2409.09554][hu] — consistent WER reductions across
  prompt-only, fine-tuned, N-best-rescoring.
- [Amazon, arXiv 2309.15649][amz] — "task-activating prompting":
  describe the rescoring task before showing N-best.
- [ProGRes, arXiv 2409.00217][progres] — current SOTA direction:
  concatenate N-best + LLM-generated candidates, interpolate scores.
- [Evolutionary prompt design, arXiv 2407.16370][evo] — prompts matter;
  genetic search recovers last 10%.
- [Fewer Hallucinations arXiv 2505.24347][fh] — 2025 result: LLMs
  over-correct; decompose to localize→assess→propose→select.
- [Findings ACL 2025 GEC][acl25] and [CHSER arXiv 2505.18463][chser] —
  28.5% relative WER reduction with a small Flan-T5 fine-tuned on
  domain-matched GenSEC data. **Modest models fine-tuned on your
  domain beat frontier models zero-shot.**
- [Shmyrev, Alphacephei Mar 2025][shm] — practitioner confirmation:
  tiny fine-tune on paired (hyp, ref) data beats any zero-shot prompt.
- [Ma et al., arXiv 2407.21414][ma] — **gate correction on confidence**:
  if ASR posterior is high, don't send to LLM; it will sometimes
  introduce errors into already-correct transcripts.

Canonical prompt skeleton that works across literature:

```
System: You are a post-ASR corrector. You receive N-best + glossary.
Return exactly one polished transcript — same language, same content,
fix misrecognitions, add punctuation, preserve code-mixed tokens.
Do not paraphrase. Do not translate.

User:
<glossary>...</glossary>
<nbest>
  <h score="-2.31">hypothesis 1</h>
  ...
</nbest>
Output:
```

Token cost: ~150 tokens frame + ~30 glossary + ~30 × N hyps. At
Qwen3.5-122B-A10B (~26 tok/s decode), ~40 output tokens ≈ 1.5 s
end-to-end for Pass 2, or ~300 ms with a smaller dedicated model.

[gensec]: https://arxiv.org/abs/2409.09785
[gensec-hf]: https://huggingface.co/GenSEC-LLM
[hu]: https://arxiv.org/html/2409.09554v2
[amz]: https://ar5iv.labs.arxiv.org/html/2309.15649
[progres]: https://arxiv.org/html/2409.00217
[evo]: https://arxiv.org/abs/2407.16370
[fh]: https://arxiv.org/html/2505.24347v2
[acl25]: https://aclanthology.org/2025.findings-acl.125.pdf
[chser]: https://arxiv.org/html/2505.18463
[shm]: https://alphacephei.com/nsh/2025/03/15/generative-error-correction.html
[ma]: https://arxiv.org/html/2407.21414v1

### 2.5 Pass-2 model sizing

The CHSER 2025 result and multiple GenSEC submissions show:
**3–8 B fine-tuned on (hyp, ref) pairs outperforms 70 B+ zero-shot**
at ~5× the tok/s. For per-utterance latency:

- Best accuracy, highest latency: reuse resident Qwen3.5-122B-A10B.
  Prefill ~150–250 tok ≈ 0.3–0.5 s; decode ~40 tok at ~26 tok/s ≈
  1.5 s. Too slow for per-utterance; use for paragraph polish only.
- Sweet spot: resident Qwen2.5-7B or Qwen3-8B Q4/Q5 Vulkan, fine-tuned
  on 50–500 pairs. ~100–200 tok/s decode on 8060S → Pass 2 ~200–300 ms.
- Cheapest: 3B class (Qwen2.5-3B, Phi-4-mini) at ~100–150 ms.

One big (resident) MoE for reasoning + one small (pinned) corrector.
Router LRU already does pinning.

### 2.6 Pipeline diagram and latency

```
┌──── laptop ────┐        ┌──── Prometheus ──────────────────────┐
│ mic (16 kHz)  │        │                                       │
│      │         │        │  Pass 1: Whisper-Vulkan               │
│      ▼         │ 20 ms  │  whisper.cpp or Speaches              │
│ VAD + tiny     │ chunks │  1-best + N-best                      │
│ whisper draft  │───────▶│            │                          │
│      │         │ WS     │            ▼                          │
│      ▼         │        │  Pass 2: small LLM (Qwen3-8B GGUF)    │
│ gray "draft"   │        │  glossary + N-best → polished         │
│                │◀───────│                                       │
│ replace with   │ final  │  Optional Pass 3: 122B MoE for        │
│ black "final"  │        │  paragraph polish, async              │
└────────────────┘        └───────────────────────────────────────┘
```

Budget (end-of-utterance to final text):
- LAN return: 10–30 ms
- Whisper-Vulkan 5-s utterance: 200–500 ms
- 7B corrector, ~40 out: 200–400 ms
- Return + UI: 30 ms
- **Total: ~0.5–1.0 s**

Sanskrit path: if VAD + language-ID says "Sanskrit", route to
Vāksañcayaḥ-fine-tuned medium; give Pass 2 a Devanagari-biased glossary.

### 2.7 Pass 3 — frontier API

User-triggered, paragraph+ scale, not hot path.
- Claude Sonnet/Opus for long-form editorial polish, preserves voice.
- Gemini 2.5 for cheap long context (whole journal entry).
- GPT-4.x for formatting-heavy tasks.

Never on per-utterance critical path — 1 s target dies the moment TLS +
queueing enter.

---

## 3. Wayland voice-typing apps and text injection

### 3.1 App landscape

**Tier A — actively maintained, relevant**:

- [cjpais/Handy][handy] — Tauri cross-platform, 100% offline via
  whisper.cpp or Parakeet V2/V3. Wayland support "limited"; relies on
  user-supplied `wtype` or `dotool`. Single-shot, no LLM post-correct,
  no custom endpoints.
- [LeonardoTrapani/hyprvoice][hyprv] — Go daemon, PipeWire, Unix-socket
  IPC, 26 STT backends, streaming where backend supports, **optional
  LLM post-correction**, three injection paths. Docs Hyprland-specific
  but daemon is compositor-agnostic. **Closest off-the-shelf match to
  the design**; runs on niri unchanged.
- [sevos/waystt][waystt] — Rust, Unix-philosophy, SIGUSR1, pipe to
  `ydotool type --file -` or `wl-copy`. OpenAI Whisper, Google STT,
  local whisper-rs. **Ships a niri keybind example**.
- [sevos/niri-transcribe][niri-tr] — same author, explicitly
  niri-targeted, Node.js, REST API, PipeWire. "Vibecoded with Claude
  Code, use at your own risk." Not production.
- [jatinkrmalik/vocalinux][vocal] — GPLv3, VOSK + whisper.cpp + OpenAI
  Whisper, Vulkan. Injects through **IBus** — which needs
  `zwp_input_method_v2` that niri lacks. **Does not work on niri**.
- [mkiol/dsnote][dsnote] (Speech Note) — Flathub, whisper.cpp, VOSK,
  Coqui, TTS+MT. Shells out to `ydotool`. Note-taking app, not
  system-wide voice-typing.
- [ronb1964/TalkType][talktype] — Python/GTK AppImage, press-to-talk,
  Whisper local, `ydotool`. Niri untested; ydotool path compat.
- **Speed of Sound** ([OMG! Ubuntu coverage][omgu]) — April-2026 app.
  Uses **XDG Desktop Portal** for injection (RemoteDesktop/InputCapture),
  forward-looking path. Optional LLM polish. Niri's xdg-desktop-portal
  backend is weak; not yet the answer.
- [MySuperWhisper][mysw], [whisrs][whisrs], [meain/ojut][ojut] — thin
  Whisper wrappers. ojut advertises **OpenAI-compat + LLM
  post-processing + personal dictionary**, but macOS-first.

**Tier B — specialized or legacy**:
- [ideasman42/nerd-dictation][nerd] — still the reference. VOSK only.
  Docs for wtype, ydotool, dotool. No LLM, no streaming beyond VOSK.
- [Numen][numen] — voice control, not dictation. VOSK + grammars.
- Rhasspy/Wyoming — HA voice ecosystem. Great protocol for
  capture-vs-transcription split.
- [Deepgram voice-keyboard-linux][dgvk] — Flux streaming demo (~240 ms
  cadence), via `/dev/uinput` so Wayland-agnostic. Cloud-only.
- [Mor-Li/Whisper-Input-Next][wi-next] — most explicit **dual-pass
  design** in FOSS: streaming + batch with smart UI transitions.
  macOS/Windows, not Wayland — **worth copying the architecture**.

**Engines (not apps)**: WhisperNow, WhisperLiveKit (bundles
SimulStreaming + NLLB 200-lang translation), SimulStreaming (~5×
faster than whisper_streaming, IWSLT 2025 winner).

Dead by 2026: kalliope, Spokestack.

[handy]: https://github.com/cjpais/Handy
[hyprv]: https://github.com/LeonardoTrapani/hyprvoice
[waystt]: https://github.com/sevos/waystt
[niri-tr]: https://github.com/sevos/niri-transcribe
[vocal]: https://github.com/jatinkrmalik/vocalinux
[dsnote]: https://github.com/mkiol/dsnote
[talktype]: https://github.com/ronb1964/TalkType
[omgu]: https://www.omgubuntu.co.uk/2026/04/speed-of-sound-linux-voice-typing-app
[mysw]: https://github.com/OlivierMary/MySuperWhisper
[whisrs]: https://github.com/y0sif/whisrs
[ojut]: https://github.com/meain/ojut
[nerd]: https://github.com/ideasman42/nerd-dictation
[numen]: https://numenvoice.org/
[dgvk]: https://github.com/deepgram/voice-keyboard-linux
[wi-next]: https://github.com/Mor-Li/Whisper-Input-Next

### 3.2 Wayland text-injection mechanics

| Path | Protocol/subsystem | Root? | Unicode? | niri? |
|---|---|---|---|---|
| `wtype` | `zwp_virtual_keyboard_v1` | no | yes (keymap upload) | **flaky** |
| `ydotool` / `ydotoold` | `/dev/uinput` | daemon in input group | yes | **yes** |
| `dotool` | `/dev/uinput` | same | yes | yes |
| IBus / Fcitx5 | `zwp_input_method_v2` + `zwp_text_input_v3` | no | native | **no** (niri lacks both) |
| wl-clipboard + paste | clipboard | no | perfect | yes, loses Ctrl-V focus |
| XDG portal RemoteDesktop | libei + virtual-keyboard | no | yes | **unknown** — no niri-native portal |

**wtype** bug cluster on niri (as of 2025–2026):
- [niri#2314][niri-2314] "wtype makes input unusable" — after wtype
  exits, focused app stops receiving real keyboard events until
  refocus. Open since Aug 2025.
- [niri#2280][niri-2280] "wtype produces gibberish with another window
  selected".
- [niri#1546][niri-1546] "Keyboard gets remapped".
- [niri#3394][niri-3394] "wtype wrong keycodes after 74d14be" —
  regression.

Conclusion: wtype works for one-shot bursts but cannot be trusted as
primary injection on niri today.

**ydotool** bypasses Wayland entirely, writes scancodes to
`/dev/uinput`. Requires persistent `ydotoold` as a user in the input
group (NixOS has the module). Compositor-agnostic; niri wtype bugs
don't apply. Non-Latin Unicode via temporary XKB layout, same
technique as wtype but at kernel-input layer. Works reliably for
Devanagari/IAST. **This is what Speech Note, TalkType, waystt default
to on Wayland**.

**Input-method protocol** (`zwp_input_method_v2`,
`zwp_text_input_v3`) would be the *correct* path — used by fcitx5/ibus.
**niri does not implement them.** Tracker: [niri#2476][niri-2476]
(Sep 2025, no assignee, no linked PR). Related smithay bug
[#1883][smith-1883]. [NixOS wiki][nix-niri] confirms: "niri does not
support text-input-v1" with partial experimental
`--wayland-text-input-version=3` flag. Until that lands, IBus-based
injection won't work on niri.

**Input-method popup positioning** broken ([niri#221][niri-221]).

**Recommended injection on niri in 2026**: ydotool with persistent
ydotoold user service. This is the advice in Speech Note docs, the
Vocalinux issue tracker, and waystt README's niri example.

**Noctalia / QuickShell text-input hooks**: none. Noctalia IPC
([docs][noc-ipc]) exposes bar/settings/notifications/volume/media/
launcher/wallpaper/brightness/darkMode/lockScreen/power/WiFi/Bluetooth
+ `toast.send()`. Nothing for emitting synthesized keystrokes. The
shell is a consumer of input, not a producer.

[niri-2314]: https://github.com/niri-wm/niri/issues/2314
[niri-2280]: https://github.com/niri-wm/niri/issues/2280
[niri-1546]: https://github.com/niri-wm/niri/issues/1546
[niri-3394]: https://github.com/niri-wm/niri/issues/3394
[niri-2476]: https://github.com/niri-wm/niri/issues/2476
[smith-1883]: https://github.com/smithay/smithay/issues/1883
[nix-niri]: https://wiki.nixos.org/wiki/Niri
[niri-221]: https://github.com/niri-wm/niri/issues/221
[noc-ipc]: https://deepwiki.com/noctalia-dev/noctalia-shell/8.3-ipc-and-external-control

### 3.3 Hotkey, PTT, capture

**niri keybinds** invoke `spawn`, no shell ([wiki][niri-keys]). Use
`spawn "sh" "-c" "..."` or `spawn-sh` when env expansion needed. Every
binding also available as `niri msg action` — wire hotkeys to user
services.

**PTT vs toggle vs VAD**: PTT lowest-latency, most robust; aligns
capture window with intent. Toggle friendlier for long dictation but
needs clear feedback. VAD always-on sensitive to noise + privacy
concerns. For coder workflow PTT is right default; toggle secondary.

**niri lacks true key-release action**. Practical pattern: `spawn
"dictate-start"` binding + separate VAD or key-release inside daemon.
Hack: `pkill -USR1 dictate-daemon` toggle (waystt pattern).

**Audio capture latency**: PipeWire can hit sub-10 ms with quantum=64–
128 at 48 kHz ([Arch wiki][arch-pw]). Fastest path: native
`libpipewire`, `pw-cat`, GStreamer `pipewiresrc`, or Rust `pipewire-rs`.
`parec` adds PulseAudio shim. Python `sounddevice` through PortAudio
through PipeWire ALSA compat: adequate for dictation (~20–40 ms), not
ideal for sub-10 ms. Hyprvoice uses native PipeWire in Go.

[niri-keys]: https://github.com/niri-wm/niri/wiki/Configuration:-Key-Bindings
[arch-pw]: https://wiki.archlinux.org/title/PipeWire

### 3.4 UX patterns for multi-pass

Three strategies:

1. **Floating preview, commit on finalize** (Superwhisper, VoiceInk,
   Speed of Sound): safe, no flicker in target app, user can abort;
   text appears all at once, feels less live. Compositor must allow
   floating over focused window (Noctalia can host as QuickShell
   overlay).
2. **Stream-then-revise in-place** (Deepgram Flux, partially Hyprvoice
   with streaming backends): partial typed as speaking; later passes
   send backspaces + retype. Feels continuous, Mac-like. **But emits
   backspaces into whatever has focus** — catastrophic in terminal
   running a build, Emacs with kbd macros, apps where backspace deletes
   paragraphs. Not suitable as universal default.
3. **Commit fast, queue revision, offer accept/reject** — no FOSS Linux
   app does this today (gap). Fast pass injected immediately; slow
   pass arrives seconds later as suggested revision in Noctalia toast
   or overlay, user can accept (diff-based retype) or ignore. Cleanest
   for the design here, **genuine gap in the ecosystem**.

### 3.5 Status indicator / feedback

- `notify-send`/libnotify coarse — better for "done" than for "listening".
- **Noctalia integration**: no public IPC method for a bespoke
  dictation pill on the bar. Cleanest paths:
  1. `toast.send()` for transient states — supported.
  2. Fork/extend noctalia-shell with QuickShell `IpcHandler` named
     `dictation` exposing `start`, `stop`, `interim(text)`,
     `final(text)`. QuickShell is declarative QML; Noctalia IPC
     singleton pattern documented on DeepWiki, easy to copy.
  3. Tiny independent QuickShell overlay layered over niri's
     layer-shell — lowest coupling, no bar integration.
- **D-Bus service** on `org.criomos.Dictation` with signals
  `StateChanged(s)` and `PartialTranscript(s)` is idiomatic for
  multiple observers without polling.

### 3.6 Recommendation

No off-the-shelf app is a clean fit. Ranking:

1. **Hyprvoice** — 80% fit. Go daemon, multi-backend, optional LLM
   pass, socket IPC. Verify survives niri wtype bugs or switch to
   ydotool (already supported). Add niri keybind binding to
   `hyprvoice toggle`. Bridge status socket to Noctalia toast or
   QuickShell pill. Zero custom STT code.
2. **waystt** — 60% fit. Minimal, composable, niri-documented, Rust.
   No streaming, no LLM post-correction. Wrapper needed for dual-pass.
3. **Build bespoke** — right call for the stream-then-revise-with-accept
   UX (§3.4.3) which nothing delivers today.

Minimal bespoke component: Rust/Go daemon, native PipeWire 16 kHz mono,
optional VAD, PTT primary, SIGUSR1/D-Bus start/stop; fast local pass
(whisper.cpp or Parakeet V3); slow pass to OpenAI-compat endpoint with
LLM post-correction including glossary; ydotool default injection,
wl-copy fallback, later switch to XDG-portal when niri portal
stabilizes; one D-Bus service emitting State and Partial; Noctalia
toast for interim; QuickShell overlay for revision accept/reject;
niri config with two bindings (toggle + abort).

Roughly 1–2 weekends on top of existing libraries (whisper.cpp
bindings, zbus, pipewire-rs).

---

## 4. Multilingual code-switching ASR + Sanskrit

### 4.1 Code-switching in major ASR

**Whisper large-v3 / turbo** is structurally hostile to code-switching.
Auto language detection looks at first 30 s and emits a **single
language token** that conditions the entire decoder. GitHub discussions
[#49][w49], [#529][w529], [#2694][w2694] confirm even when `language=`
is set, model not strictly constrained — under uncertainty can drift;
inverse also true: force `en` and Sanskrit words get Anglicized into
phonetic English garbage ("uttman" for ātman, "praanaayaam" for
prāṇāyāma). [Subtitle-Edit #10101][se-10101] is a long thread of users
requesting multi-language segments.

2024–2025 research grafted adapters: ["Adapting Whisper for
Code-Switching through Encoding Refining and Language-Aware
Decoding"][w-cs1] and Interspeech 2025 ["Adapting Whisper for
Parameter-efficient Code-Switching ASR"][w-cs2]. Not first-class
production HF checkpoints for EN/SA/ES/FR.

Whisper large-v3 remains SOTA for monolingual EN/ES/FR (3–6% WER per
[NovaScribe 2026 numbers][ns26]) but weak for mixed-language utterances.

[w49]: https://github.com/openai/whisper/discussions/49
[w529]: https://github.com/openai/whisper/discussions/529
[w2694]: https://github.com/openai/whisper/discussions/2694
[se-10101]: https://github.com/SubtitleEdit/subtitleedit/issues/10101
[w-cs1]: https://arxiv.org/html/2412.16507v2
[w-cs2]: https://www.isca-archive.org/interspeech_2025/yang25p_interspeech.pdf
[ns26]: https://novascribe.ai/how-accurate-is-whisper

**NVIDIA Canary family**:
- [canary-1b][c1b]: EN/DE/FR/ES. Four languages, no code-switch.
- [canary-1b-v2][c1bv2]: 25 European languages. **No Indic**.
- [canary-qwen-2.5b][cq25]: English-only.
- [Canary-1B-v2 paper][can-paper] explicitly scopes European.

Strong EN/ES/FR engine but **cannot see Sanskrit**. Rule out.

[c1b]: https://huggingface.co/nvidia/canary-1b
[c1bv2]: https://huggingface.co/nvidia/canary-1b-v2
[cq25]: https://huggingface.co/nvidia/canary-qwen-2.5b

**Voxtral / Voxtral Transcribe 2**. [Voxtral][vox-ann] (July 2025)
advertises auto-lang-detect across EN/ES/FR/PT/Hindi/DE/NL/IT.
[Voxtral Transcribe 2][vox-t2] (Feb 2026, [MarkTechPost][mtpv]) covers
13 languages incl. **Hindi**, with sub-200 ms latency, diarization,
**context biasing**, word-level timestamps. Mistral claims beats
Whisper large-v3 on multilingual. **Sanskrit explicitly not listed.**
Hindi helps with nothing Sanskrit-specific — shared Devanagari but
phonology and vocabulary differ (Hindi no long/short vowel distinction
as Sanskrit, no visarga, no ḷ).

[vox-ann]: https://mistral.ai/news/voxtral
[vox-t2]: https://mistral.ai/news/voxtral-transcribe-2

**SeamlessM4T v2 / SeamlessStreaming**. [facebook/seamless-m4t-v2-large][seam]
handles ~100 languages incl. Sanskrit in text and Hindi in speech, but
**ASR side does not include Sanskrit speech input**. Code-switching
not advertised.

**Gemini 2.5 / GPT-4o-audio / Claude audio**. Only models that
empirically handle code-switching reasonably. [Gemini Audio][gem-aud]
supports multilingual in single session; users report it will
transcribe mixed EN/ES/FR without fumbling. But closed API, latency,
cost, privacy, network dep. Baseline reference, not building block.

[gem-aud]: https://deepmind.google/models/gemini-audio/

**Kyutai Moshi / Unmute / STT**. stt-1b-en_fr EN+FR only; stt-2.6b-en
English only. No Sanskrit, no Spanish in primary checkpoints. Excellent
latency story (0.5 s VAD) but wrong language mix.

**AI4Bharat IndicWhisper / IndicConformer**.
[indicconformer_stt_sa_hybrid_ctc_rnnt_large][ai4-sa]: Hybrid CTC-RNNT
Conformer 120 M specifically for Sanskrit. Per [Vistaar paper][vistaar],
Sanskrit WER ~48% — weakest in their suite, reflecting tiny labeled
data. [Shrutilipi][shruti] has only ~27 h Sanskrit audio.
[IndicWhisper][iwhisp] fine-tunes Whisper on Vistaar; lowest WER on
39/59 benchmarks but similar Sanskrit struggles.

[ai4-sa]: https://huggingface.co/ai4bharat/indicconformer_stt_sa_hybrid_ctc_rnnt_large
[vistaar]: https://arxiv.org/pdf/2305.15386
[shruti]: https://huggingface.co/datasets/ai4bharat/Shrutilipi
[iwhisp]: https://github.com/AI4Bharat/vistaar

**MMS (Meta, 2023)**. [facebook/mms][mms] covers 1,107 languages from
Bible recordings. Technically includes Sanskrit but narrow domain
(religious reading voices); generalizes poorly to conversational /
code-switched. Native-script output.

[mms]: https://huggingface.co/docs/transformers/en/model_doc/mms

**Omnilingual ASR (Meta, Nov 2025)**. [Omnilingual][omni]
([arXiv 2511.09690][omni-paper], [repo][omni-repo]): 7B wav2vec-2.0 +
LLM decoder covering 1,600+ languages, CER <10 for 78%. AllASR corpus:
120k hours labeled over 1,690 languages. Few-shot extension to new
languages. Indic coverage explicit; Sanskrit-specific WER not
advertised. Most plausible single-model for tail languages but still
single-language-token-per-clip at decoder.

[omni]: https://ai.meta.com/blog/omnilingual-asr-advancing-automatic-speech-recognition/
[omni-paper]: https://arxiv.org/abs/2511.09690
[omni-repo]: https://github.com/facebookresearch/omnilingual-asr

**Qwen3-ASR (Jan 2026)**. [Qwen3-ASR][qasr] supports 30 languages +
22 Chinese dialects, incl. Hindi **but not Sanskrit**. First-class
context biasing and language ID, built into speech-aware LLM. Strong
for EN/ES/FR if Sanskrit handled separately.

[qasr]: https://github.com/QwenLM/Qwen3-ASR

**2025 papers**: Interspeech 2025 ["Better Pseudo-labeling with
Multi-ASR Fusion and Error Correction by SpeechLLM"][im-fusion] and
ACL 2026 survey ["Beyond Monolingual Assumptions"][cs-survey] conclude
**speech LLMs with post-hoc LLM correction are dominant architecture
for code-mixed speech**, outperforming custom code-switch adapter
approaches.

[im-fusion]: https://www.isca-archive.org/interspeech_2025/prakash25_interspeech.pdf
[cs-survey]: https://github.com/gentaiscool/code-switching-papers

### 4.2 Sanskrit ASR specifically

**Viable in 2026? Marginally yes, not human quality.** Current SOTA:

- [IndicWhisper on Vedavani][vedavani-acl]: **WER 23.14% (IAST), CER
  4.12%** — best multilingual on Vedic poetry.
- Whisper large on IAST: 26.05% WER; on Devanagari: 20.71%.
- [Sanskrit Whisper-medium fine-tune, arXiv 2501.10024][sa-whisper]:
  **15.42% WER on Vāksañcayaḥ** (best single number), Devanagari
  output; 37.22% WER out-of-domain.
- IndicConformer sa: ~48% WER (older).

Datasets:
- [Vāksañcayaḥ (IIT-B)][vaks]: 78 h, 45,953 sentences, SLP1 +
  Devanagari.
- [Shrutilipi Sanskrit][shruti]: 27 h.
- [Vedavani][vedavani]: 54 h Vedic poetry (Rig Veda 20,782 verses +
  Atharva Veda 9,997), IAST + Devanagari.

Whisper's `sa` token: [tokenizer][w-tok] includes `"sa": "sanskrit"` —
can force Sanskrit language, but base Whisper Sanskrit WER on real
data is poor (60–90% pre-finetune). Fine-tunes like
[Bidwill/whisper-medium-sanskrit-try-2][bidwill] exist but niche,
unevaluated OOD.

[Vyoma Labs][vyoma] mentions "Vyoma-STT" product; nothing open or
benchmarked publicly. IIT-B, IIIT-H, AI4Bharat (IIT-M) are real
academic sources. **No production-grade open Sanskrit ASR in 2026.**

[vedavani-acl]: https://aclanthology.org/2025.wsc-csdh.6.pdf
[vaks]: https://www.cse.iitb.ac.in/~asr/
[vedavani]: https://huggingface.co/datasets/sanganaka/Vedavani-Dataset
[w-tok]: https://github.com/openai/whisper/blob/main/whisper/tokenizer.py
[bidwill]: https://huggingface.co/Bidwill/whisper-medium-sanskrit-try-2
[vyoma]: https://vyoma.org/

### 4.3 Romanization scheme for user

- **IAST** — academic and yoga-publishing standard (ātman, prāṇāyāma,
  saṃskāra). Unicode diacritics. [Wikipedia][iast-wiki].
- Harvard-Kyoto — ASCII-only (A, I, U, R, M, H, z, S, J, G). Ugly.
- ITRANS — ASCII extension (aa, ii, uu, RRi, shh, ~N). Shell-code look.
- SLP1 — one ASCII char per Devanagari letter (A=ā, I=ī, M=ṃ).
  Computer-friendly but visually cryptic.

For yoga/philosophy prose, **IAST is unambiguously right default**.
Devanagari as opt-in toggle. Avoid ASCII "atman" — collapses distinctions
(e.g. śiva vs siva, pāda vs pada).

Transliteration tooling (mature, offline, Python):
- [aksharamukha][aksh] ([repo][aksh-repo]) — 120 scripts, 21
  romanizations incl. IAST, ISO, HK, ITRANS, Velthuis, SLP1, WX.
  Bi-directional. Strongest single library.
- [indic-transliteration][indic-tr] ([repo][indic-tr-repo]) — focused
  on Indic, simpler API.

Pipeline: Devanagari from ASR → `aksharamukha.transliterate.process(
"Devanagari", "IAST", text)` → IAST in final text.

[iast-wiki]: https://en.wikipedia.org/wiki/Devanagari_transliteration
[aksh]: https://pypi.org/project/aksharamukha/
[aksh-repo]: https://github.com/virtualvinodh/aksharamukha-python
[indic-tr]: https://pypi.org/project/indic-transliteration/
[indic-tr-repo]: https://github.com/indic-transliteration/indic_transliteration_py

### 4.4 Code-switching strategy — honest evaluation

**(a) Single multilingual model, language=auto.** Whisper large-v3
with `language=None`. Locks to dominant (English for user), butchers
Sanskrit into phonetic English. Spanish/French mid-sentence fragments
often get English-spelled or translated ("hola" → "ola" or "hello").
Baseline bad but usable for ~90% English monolingual.

**(b) Multilingual model + LLM post-corrector with user glossary.**
Whisper large-v3 (or Voxtral Transcribe 2 Realtime for latency) forced
English, then pass `{audio_context, transcript, user_glossary[]}` to
local LLM (Qwen3, Llama-3.3 on the LLM server). LLM sees "uttman" and
rewrites to "ātman" because glossary says so. Approach in
[Amazon's LLM-correction paper][amz-paper] and Interspeech 2025
[SpeechLLM fusion paper][im-fusion]. **Right answer for this user.**
Fits existing LLM server, keeps ASR simple, glossary extensible.

**(c) Multiple ASR passes + merge.** Whisper@en + Whisper@sa +
Voxtral@auto reconcile. 3× compute, fragile merge, does not fix core
problem (each pass still thinks clip is one language). Not worth it.

**(d) Cloud multimodal.** Genuinely best accuracy on mixed-language
today. External dependency, privacy, latency, cost. For a self-hosted
CriomOS user, sensible only as occasional fallback for high-stakes
material. Escape hatch, not default.

**Verdict: strategy (b) wins.** Inherits strong EN/ES/FR from
Whisper/Voxtral, handles Sanskrit via LLM rewrite rather than a
second ASR.

[amz-paper]: https://assets.amazon.science/77/26/6c265e0a42d7a40d2ee8bdd158e6/generative-speech-recognition-error-correction-with-large-language-models-and-task-activating-prompting.pdf

### 4.5 Custom vocabulary / domain adaptation

- **Whisper `initial_prompt`**: 224-token prompt conditioning decoder
  first pass. Helpful for priming spellings but unreliable — prompt
  biases but does not constrain, long prompts crowd audio. Canonical
  hack ([whisper#963][w963], [HF forums][hf-cust]) works 40–60% on
  rare terms.
- **faster-whisper `hotwords`**: logit bias during beam search. Better
  than initial_prompt for short lists, still probabilistic.
- **Parakeet / Canary context biasing**: NVIDIA's
  [GPU-PB phrase boosting][nemo-wb] with shallow fusion at decode
  time, no retraining. [sherpa-onnx PR #3077][sherpa-3077] adds
  hotword for NeMo transducers. Strong engineering but NeMo can't do
  Sanskrit — helps EN/ES/FR only.
- **Voxtral Transcribe 2 context biasing**: advertised first-class.
- **LLM correction with glossary**: most reliable for *rare* tokens.
  Prompt like "Rewrite transcript. Known terms match glossary exactly:
  ātman, citta-vṛtti, prāṇāyāma, Bhagavad-Gītā, saṃskāra, nāmarūpa,
  … Preserve English, Spanish (María), French (père, ça) diacritics.
  Output IAST for Sanskrit." works extremely well with Qwen3-32B or
  Llama-3.3-70B, tolerably with 7–14B if glossary small.
- **Speech-to-style**: 2025 papers like [Lexical Error Guard][leg] and
  [UAST][uast] describe pattern — ASR produces noisy hypothesis,
  second-stage rewrites to canonical. Production-ready.

[w963]: https://github.com/openai/whisper/discussions/963
[hf-cust]: https://discuss.huggingface.co/t/adding-custom-vocabularies-on-whisper/29311
[nemo-wb]: https://docs.nvidia.com/nemo-framework/user-guide/latest/nemotoolkit/asr/asr_customization/word_boosting.html
[sherpa-3077]: https://github.com/k2-fsa/sherpa-onnx/pull/3077
[leg]: https://arxiv.org/html/2309.09552v4
[uast]: https://arxiv.org/pdf/2203.14277

### 4.6 Script normalization recommendation

Default output: **IAST with Unicode diacritics** for Sanskrit, plain
English/Spanish/French with native diacritics. Matches yoga and
Indology publishing conventions; inline-natural ("working on prāṇāyāma
this morning"), degrades gracefully if fonts fail.

Three configurable modes:
1. `iast` — default.
2. `devanagari` — ātman → आत्मन्. `aksharamukha IAST→Devanagari`.
3. `ascii` — ātman → atman. Lossy; logs/filenames/URLs only.

### 4.7 Spanish and French

Whisper large-v3 and Voxtral both 3–6% WER with diacritics preserved.
[bofenghuang/whisper-large-v3-french][boffr] predicts casing,
punctuation, numbers correctly. Callouts:
- Diacritic loss on single words embedded in English (lone "déjà vu"
  sometimes comes out "deja vu"). LLM corrector fixes trivially.
- Whisper sometimes translates instead of transcribing if language
  token drifts. Force dominant language, rely on correction.

No special handling. ç and all accents in Whisper vocabulary.

[boffr]: https://huggingface.co/bofenghuang/whisper-large-v3-french

### 4.8 Concrete 2026 recommendation (user's stack)

1. **Primary ASR**: whisper-large-v3-turbo via faster-whisper, forced
   `language="en"`, `hotwords=<glossary>` + compact `initial_prompt`
   listing top 20 Sanskrit terms. Fast on Strix Halo Vulkan.
   Alternative: Voxtral Mini 4B Realtime for lower latency + built-in
   diarization; Parakeet TDT 0.6B v3 for English-only speed.
2. **LLM post-corrector**: local Qwen3 or Llama-3.3 on LLM server,
   system prompt with Sanskrit rules + user glossary, outputs IAST.
3. **Transliteration**: `aksharamukha` Python module: `to_iast()`,
   `to_devanagari()`, `to_ascii()`. Called only on explicit re-render.
4. **Optional Sanskrit specialist**: long philosophical dictations
   (lectures, japa) where Sanskrit dominates → Sanskrit
   whisper-medium or IndicConformer-sa, then aksharamukha
   Devanagari→IAST. Gate on user toggle or auto-detect by segment.
5. **Escape hatch**: Gemini 2.5 / GPT-4o-audio via local shim for
   marked "high-fidelity" material.

**Personal glossary over time**: seed ~/.config/criomos/
sanskrit-glossary.json with ~100 terms (Yoga Sūtras, Bhagavad-Gītā,
Upaniṣads, yoga-studio vocab). Each corrector rewrite logs (heard,
corrected) to jsonl; weekly batch job reviews with LLM and promotes.
CLI `criomos-vocab add prāṇāyāma` + one-tap Noctalia notification to
teach. Seed from [Monier-Williams][mw] + [Vedanta Society glossary][vs]
at bootstrap.

**Not recommended**:
- Fine-tune custom Whisper on user voice — not enough labeled audio
  yet; LLM-correction captures 90% of wins at 1% engineering cost.
- IndicConformer as *primary* — no English/Spanish/French support.
- Relying on Whisper `initial_prompt` alone — too unreliable for
  philosophy-text dictation.

[mw]: https://www.sanskrit-lexicon.uni-koeln.de/
[vs]: https://vedanta.org/glossary-of-sanskrit-terms/

---

## 5. Style and vocabulary adaptation

### 5.1 Vocabulary in ASR stage

**Whisper `initial_prompt`**:
- Token limit: **224 tokens** (decoder window 448, first half reserved
  for context). ~150–180 English words; less with Sanskrit/IAST which
  tokenizes badly — often 3–6 BPE tokens per IAST word — realistically
  60–90 IAST terms + framing. Confirmed in
  [openai/whisper#1386][w1386].
- **Prompt leakage**: Whisper treats prompt as prior "heard" text, so
  artifacts (punctuation, casing, emoji, sign-offs) bleed into output.
  Classic failure: prompt literally re-emitted, especially on silence.
  See [community.openai.com on hallucinations][coai-hall],
  [Gladia bias writeup][gladia].
- **Language-detection bias**: prompt seen before language ID; mixed
  prompt can flip detection to Hindi or German. Safer: pass
  `language="en"` explicitly.
- **Only first 30-s segment sees it**: in standard Whisper (and
  faster-whisper) prompt is overwritten by decoder output as condition
  after segment 0. For short dictation utterances fine; for long-form
  set `condition_on_previous_text=False` and re-inject each segment
  ([faster-whisper#590][fw-590]).

Verdict: useful and free, budget-constrained. Best as *rotating*
100-token window of most relevant proper nouns + tiny style hint.

[w1386]: https://github.com/openai/whisper/discussions/1386
[coai-hall]: https://community.openai.com/t/how-to-avoid-hallucinations-in-whisper-transcriptions/125300
[gladia]: https://www.gladia.io/blog/ai-model-biases-what-went-wrong-with-whisper-by-openai
[fw-590]: https://github.com/SYSTRAN/faster-whisper/issues/590

**faster-whisper `hotwords`**: logit bias per token rather than prior
text, so don't leak as output. Caveats:
- Hotwords concatenated into a string that's internally treated as
  another prompt if `prefix` is None; in practice they still partly
  behave like initial_prompt. See [Prompt And Hotwords.pdf][fw-ph].
- Community consensus: use initial_prompt for domain jargon + style,
  hotwords only for handful of rare terms not well served by prompting.
  Stacking both helps modestly.
- No public WER benchmarks specific to hotwords as of early 2026.
  Closest academic: OV-KWS ([arXiv 2309.09552][leg]) — 1.4–2.4%
  absolute MER reduction on domain terms for Whisper small/medium/large.

[fw-ph]: https://github.com/CheshireCC/faster-whisper-GUI/blob/main/Prompt%20And%20Hotwords.pdf

**WhisperX custom vocabulary**: no first-class API;
[whisperX#324][wx-324] is reference. Practical: use WhisperX only for
forced-alignment + diarization; implement biasing upstream via
faster-whisper. Recent whisper.cpp [PR #3555][wcpp-3555] eliminates
hard-coded vocab tables — opens door to shipping fine-tuned tokenizer
(fine-tune path, not runtime injection).

[wx-324]: https://github.com/m-bain/whisperX/issues/324
[wcpp-3555]: https://github.com/ggml-org/whisper.cpp/pull/3555

**Parakeet / Canary contextual biasing**: CC-BY-4.0, competitive with
Whisper large-v3 on English, lower latency on Parakeet side.
- Canary (AED): phrase boosting via standard NeMo `word_boosting` API
  ([docs][nemo-wb]). Internally WFST-style context graph (CTC-WS,
  [arXiv 2406.07096][ctc-ws]).
- Parakeet-TDT: issues [#14500][nemo-14500], [#14772][nemo-14772]
  track phrase-boost; late 2025 Parakeet v2 users reported WER
  *worsening* with increased boost alpha. NVIDIA developing shallow-
  fusion boosting for RNNT/TDT no-fine-tune.
  [NeMo ASR_Context_Biasing tutorial][nemo-ctx] canonical.
- GPU-PB supported for CTC, RNN-T/TDT and Canary AED in NeMo 2.x.

Open interface: Python list of phrases + per-phrase weights; no
training.

[ctc-ws]: https://arxiv.org/html/2406.07096v1
[nemo-14500]: https://github.com/NVIDIA-NeMo/NeMo/issues/14500
[nemo-14772]: https://github.com/NVIDIA-NeMo/NeMo/issues/14772
[nemo-ctx]: https://github.com/NVIDIA-NeMo/NeMo/blob/main/tutorials/asr/ASR_Context_Biasing.ipynb

**Pronunciation dictionaries / G2P in NeMo**: NeMo supports classical
G2P ([docs][nemo-g2p]). G2P-Conformer CTC ~20× smaller than ByT5. For
single-user dictation overkill — Parakeet-TDT is character/BPE,
"pronunciation injection" happens through phrase-boost list. For exotic
Sanskrit pronunciation, lowest-friction: record 3–10 s audio per term,
force-align with wav2vec2, pin label as hotword + boosted phrase. No
G2P needed.

[nemo-g2p]: https://docs.nvidia.com/nemo-framework/user-guide/latest/nemotoolkit/tts/g2p.html

### 5.2 LLM post-correction

Most personalization yield lives here. Approach well supported:
[OpenReview "Enhancing SR with LLMs in Post-Correction"][pc-or],
[arXiv 2409.09785 GenSEC][gensec], recent [arXiv 2601.21347
LLM-Agent Post-ASR Correction][llm-agent] using Judge-Editor frame.
Key result: LLM post-editing helps when raw WER > 10%; can *hurt* on
already-clean transcripts (paraphrastic drift). Corrector must be
conservative by default, aggressive only when raw confidence is low.

[pc-or]: https://openreview.net/forum?id=lcFaopqn9a
[llm-agent]: https://arxiv.org/html/2601.21347v1

**Few-shot style examples — budget**. Qwen3.5-122B-A10B native
[128K context][qwen3-ctx] (256K with YaRN). Budgets at 128K:
- 1 token ≈ 0.75 English word → 128K ≈ 96K words ≈ 200 typeset pages.
- Keep generation headroom: aim 100K input, 4K output.
- **Last** examples dominate (recency bias well-known on Qwen/Llama).
  Put most-like-this-utterance examples last.
- [Amazon conversation style transfer][amz-conv] shows 3–5 well-chosen
  paired examples recover most style gain; 5→50 marginal unless
  diverse domains.

Practical: ~20 pairs selected by similarity, 4–6K tokens, beats
stuffing 500 static. 128K better spent on RAG.

[qwen3-ctx]: https://huggingface.co/Qwen/Qwen3-32B/discussions/18
[amz-conv]: https://assets.amazon.science/2e/13/09db2e194e01ac743a2767b5c703/conversation-style-transfer-using-few-shot-learning.pdf

**Retrieval-augmented correction**. Pull N most similar prior writings
as reference voice:
- **llama.cpp embeddings**: `llama-server --embeddings` exposes
  OpenAI-compat `/v1/embeddings` from same process; serve
  Qwen3-Embedding-0.6B or BGE-M3 locally ([tutorial #7712][ll-emb]).
  Latency on Strix Halo: 5–20 ms per 512-tok doc.
- **Vector store**: for single-user corpus of thousands-to-tens-of-
  thousands, [LanceDB][lancedb] wins — embedded (no server),
  Arrow/Lance, 40–60 ms queries with ~88% recall@1. [Qdrant][qdrant]
  better filter perf + 20–30 ms with 95% recall@1 if willing to run
  server. Chroma easier to start but slower at scale; SurrealDB
  vector less mature.
- **Latency budget 300 ms**: encode query (10 ms) + ANN over
  10K–100K (30 ms LanceDB) + rerank top-50 with small cross-encoder
  bge-reranker-v2-m3 (50–150 ms on Strix Halo Vulkan) = under 300 ms.
  Skip rerank for P50 wins.

RAG-for-style differs from RAG-for-facts: retrieve because *voice*
matches, not because content matches. Embed on prose signatures
(sentence length, register, domain tags) as much as on topic. Cheap
trick: concatenate topic embedding with "style fingerprint" (mean
embedding of user's domain-tagged chunks) and search hybrid space.

[ll-emb]: https://github.com/ggml-org/llama.cpp/discussions/7712
[lancedb]: https://medium.com/@vinayak702010/lancedb-vs-qdrant-for-conversational-ai-vector-search-in-knowledge-bases-793ac51e0b81
[qdrant]: https://qdrant.tech/documentation/frameworks/llama-index/

**Glossary injection: `term → canonical` vs free-form notes**. Flat
curated list of `raw_variant → canonical` pairs outperforms free-form
style notes for terminology. Finding behind medical ASR like
[United-MedASR][umed] and [Google MedASR][gmed] — both use explicit
glossaries (ICD-10, MIMS, FDA). Mechanism: LLM excellent at substring
replacement when told "if you see these left-column strings, replace
with right-column." Less good at "rewrite in Li's voice" without
examples.

Use both: glossary for named entities and vocabulary (high-precision,
deterministic), prose examples for rhythm and diction (generative).

[umed]: https://arxiv.org/html/2412.00055v1
[gmed]: https://developers.google.com/health-ai-developer-foundations/medasr

**"Constitution" prompts vs example-only**. For *stylistic imitation*,
examples win. Consistent across [Learn Prompting few-shot docs][lpfs],
[PromptHub guide][phfs], Amazon style transfer. Constitution ("use
em-dashes, avoid Latinate verbs, prefer active, render Sanskrit in
IAST") does real work as prior but cannot capture texture that 3–5
good before/after examples convey implicitly. Use short constitution
(200–500 tokens) as system for hard rules (IAST canonicalization,
code-block preservation, never-invent-facts), put examples in
user/assistant history for style.

[lpfs]: https://learnprompting.org/docs/basics/few_shot
[phfs]: https://www.prompthub.us/blog/the-few-shot-prompting-guide

### 5.3 Fine-tuning / LoRA for personal style

**Strix Halo training**: better than a year ago.
[Framework Community "Finetuning LLMs on Strix Halo"][frame-sh] and
[kyuz0/amd-strix-halo-toolboxes][kyuz0] document working full/LoRA/
QLoRA pipelines for Gemma-3, Qwen-3, gpt-oss-20B on Strix Halo via
ROCm. With 128 GB unified can full-fine-tune up to ~12B, QLoRA tune
20–30B locally. Vulkan llama.cpp still inference-only; **training
through ROCm** (PyTorch ROCm 6.3+ for gfx1151, or Unsloth's Triton/
ROCm path that landed quietly in 2025). [ROCm Strix Halo Guide][rocm-sh]
has setup. Unsloth [QLoRA guide][un-qlora] works on ROCm v2025.10.

Single evening 8B QLoRA on ~2K pairs: 2–4 hours on Strix Halo. Viable.

**Cloud H100 alternative**: one-shot LoRA on H100 via RunPod/Lambda/
Modal ~$2–5/hr. Qwen3-14B QLoRA on 5K pairs: 30–45 min, $1.50–4.
Export safetensors, convert to GGUF adapter with
`llama.cpp/convert_lora_to_gguf.py`, load via `llama-server --lora`.
Zero compromise on local inference after.

**Dataset size** ([Databricks LoRA guide][dbr], [introl 2025][intr]):
- <200 pairs: overfitting; memorization; minor gains.
- 500–1,000: first useful zone for style transfer.
- 2,000–5,000: sweet spot for personal-voice LoRA.
- 10K+: diminishing returns without new axes.

For dictation-correction LoRA where signal is tight (raw → polished)
and rewrite style consistent, 1K–2K plausibly enough. Start collecting
now, train at 1K.

**Distillation**: let the 122B MoE do corrections for a month, log
(raw, 122B-output, user-edit) triples, distill into 8B LoRA via
[Thinking Machines On-Policy Distillation][tm-dist]. 8B becomes
fast-path (sub-second), 122B stays for low-confidence. Cheapest way
to get 122B-quality style + 8B-latency.

[frame-sh]: https://community.frame.work/t/finetuning-llms-on-strix-halo-full-lora-and-qlora-on-gemma-3-qwen-3-and-gpt-oss-20b/76986
[rocm-sh]: https://github.com/ollama/ollama/issues/14855
[un-qlora]: https://docs.unsloth.ai/get-started/fine-tuning-llms-guide/lora-hyperparameters-guide
[dbr]: https://www.databricks.com/blog/efficient-fine-tuning-lora-guide-llms
[intr]: https://introl.com/blog/fine-tuning-infrastructure-lora-qlora-peft-scale-guide-2025
[tm-dist]: https://thinkingmachines.ai/blog/on-policy-distillation/

### 5.4 Continuous learning loops

**Capturing edits**: every user edit of dictation output = free
`(raw_ASR, first_pass_LLM, final_user_text)` triple. Strategy:
- Hook editor (jj pre-commit, notes-app save handler) to diff pre- and
  post-edit within N seconds of dictation.
- Store as JSONL: `audio_hash`, `raw`, `llm_draft`, `final`,
  `timestamp`, `context_window` (surrounding paragraph).
- `llm_draft == final` = positive; `llm_draft != final` = preference
  pair (final preferred).

**Preference pair → DPO/KTO/ORPO**: after several hundred pairs run
DPO/KTO/ORPO:
- **DPO** default lowest-friction.
- **KTO** ([Unsloth docs][un-dpo]) no paired data — works with unary
  good/bad labels, which matches edit stream better. Often right pick
  for personalization.
- **ORPO** combines SFT + preference in one pass, useful if data is
  mostly SFT pairs with occasional preference signal.

[DPO Survey arXiv 2410.15595][dpo-survey].

[un-dpo]: https://unsloth.ai/docs/get-started/reinforcement-learning-rl-guide/preference-dpo-orpo-and-kto
[dpo-survey]: https://arxiv.org/html/2410.15595v3

**Simpler: growing few-shot / RAG pool**. Before preference learning,
just append confirmed (raw, final) pairs to RAG index. System retrieves
automatically when similar utterances come up. "Stone soup" 2025
approach — cheap, self-improving, no training loop. [SPRInG][spring]
formalizes as "selective parametric vs non-parametric personalization";
[CoPL][copl] pushes LoRA-mixture; [Survey of Personalized LLMs][surv]
is best 2025 entry-point. Practical: RAG-first, DPO-second.

[spring]: https://www.arxiv.org/pdf/2601.09974
[copl]: https://arxiv.org/abs/2503.01658
[surv]: https://arxiv.org/abs/2502.11528

### 5.5 Personal vocabulary curation

**Growth rule**: each user edit `X → Y` where `X` is proper noun /
Sanskrit term / technical keyword and `Y` is same phonetic category,
promote `(X, Y)` with "seen N" counter. N ≥ 2 → canonical.

Example: utterance 1 "samskara" → user corrects "saṃskāra" (tentative);
utterance 5 "sumskara" → auto-corrected via existing entry (confirmed);
promoted, added to initial_prompt rotation + hotwords.

**JSONL schema** (no standard):

```json
{"canonical":"saṃskāra","variants":["samskara","sumskara","sanskara"],
 "phonetic":"səmˈskaːrə","language":"sa-IAST","domain":["yoga","philosophy"],
 "definition":"latent impression","seen":7,"promoted":true,
 "last_used":"2026-04-18"}
```

Similar to MedASR/United-MedASR but explicitly multilingual +
domain-tagged.

**Dynamic initial_prompt generation**: at dictation start estimate
context (current file path, recent jj subjects, Niri IPC window title)
to infer domain tags; sample N glossary entries filtered by tags,
fitting ≤200 tokens. Example: 8 Sanskrit + 8 CriomOS/Nix + 4 Rust +
one-sentence style hint. Regenerate on context change, not every
utterance (cache).

### 5.6 Speaker adaptation (acoustic)

For single-speaker with Whisper-large-v3 or Parakeet-v3, **raw-scale
has largely subsumed x-vector conditioning for clean audio accuracy**.
Remaining wins:
- **Parameter-efficient LoRA on Whisper encoder/decoder**
  ([JUNLP@LT-EDI-2025][junlp]): 15–24% WER reduction with ~1–10%
  parameter overhead adapting to specific speaker's acoustic quirks.
  Dataset: ~30 minutes of own speech with GT text.
- **Speaker embedding conditioning** ([arXiv 2503.10446][wsi],
  [arXiv 2409.09543][tsw]) — aimed at *separation* in multi-talker,
  not single-speaker. Not relevant for solo dictation.
- **Diarization-dependent transforms** ([SQ-Whisper][sqw]) — same.

For single-user dictation: skip acoustic adaptation until 2+ hours
own audio with good transcripts; then consider LoRA on Whisper encoder
if raw WER still >5%. Most remaining gain is in *text* style, not
acoustics.

[junlp]: https://aclanthology.org/2025.ltedi-1.4.pdf
[wsi]: https://arxiv.org/html/2503.10446v1
[tsw]: https://arxiv.org/abs/2409.09543
[sqw]: https://arxiv.org/html/2412.05589v1

### 5.7 Phasing recommendation

**Phase 1 — ship this week (prompt + glossary only)**:
- faster-whisper-large-v3 + `initial_prompt` (180 tok) + `hotwords`
  (20 rarest). Fallback Parakeet-TDT-0.6b-v3 via NeMo if latency
  matters. Corrector: Qwen3.5-122B-A10B MoE on llama-server :11434,
  zero-shot with 400-token system + 5-example few-shot.
- Seed glossary (~100 entries) + tool regenerating initial_prompt from
  current context.
- Budget: ASR ~0 tok; corrector input = 400 + 1500 + utterance ≈ 2500
  tok; output ≈ utterance length.
- Latency: Whisper 0.3–0.8 s (Strix Halo Vulkan); Qwen 122B MoE
  ~30–50 tok/s → ~4–8 s for 200-tok correction. Total <10 s fine for
  batch edit; for live streaming use 8B draft + queue 122B for polish.

**Phase 2 — month 2 (RAG + dynamic few-shot)**:
- Local embedding endpoint (Qwen3-Embedding-0.6B); LanceDB of prior
  writings chunked ~300 tok; hybrid retrieval (topic + style-
  fingerprint) top-5; dynamic few-shot replaces static 5.
- Corpus bootstrap: Git log of Emacs/org notes, blog posts, jj commit
  messages, code comments — 50K–500K words.
- Retrieval overhead 50–150 ms; input grows to ~6K tok (5 × 1K +
  utterance), still under 128K.
- Log (raw, draft, edited) from Phase 1 onward — free data.

**Phase 3 — optional after 1K+ pairs (LoRA)**:
- Option A (local): QLoRA Qwen3-14B-Instruct via Unsloth on ROCm on
  Strix Halo toolbox; 3–5 hours; export GGUF adapter; attach as
  `--lora`. 14B becomes fast-path corrector; 122B for low-confidence.
- Option B (cloud one-shot): QLoRA Qwen3-14B on H100 via RunPod, ~$3,
  45 min. Same artifact.
- Option C (KTO on edit stream): once 300+ preference pairs from
  edits, KTO the 14B corrector. Per [Unsloth KTO docs][un-dpo] aligns
  tighter to actual edit behavior than SFT alone.
- Distill 122B → 14B: once RAG-backed 122B pipeline is producing
  mostly-accepted corrections, train 14B to mimic 122B outputs; gets
  122B quality at 14B latency.

| Phase | Input tok | Output tok | E2E latency (Strix Halo) |
|-------|-----------|------------|--------------------------|
| 1 | ~2.5K | ~300 | 5–10 s |
| 2 | ~6K | ~300 | 6–12 s |
| 3A (14B LoRA fast) | ~6K | ~300 | 1–2 s |
| 3B (14B + 122B rescue) | +9K on 5% rescue | ~300 | 1–2 s mean, 8–12 s P99 |

### 5.8 Closing observations

1. **Glossary is highest leverage artifact**. Feeds ASR (initial_prompt,
   hotwords), corrector (system rules, canonicalization), eventually
   LoRA dataset. Curate deliberately.
2. **Log everything from day one**. (audio, raw, llm_draft, committed,
   timestamp, context_tags) JSONL is cheap; becomes the training set
   you cannot reconstruct later.
3. **Do not LoRA early**. Prompt + glossary + RAG carries first
   thousand hours. LoRA warranted when you feel the ceiling — "the
   corrector is consistently making the same small stylistic mistake
   and few-shot doesn't fix it."
4. **Vulkan inference + ROCm training** is the correct Strix Halo
   split in 2026; don't mix them.

---

## Uncertainties and dated claims

- **Voxtral on Strix Halo/ROCm**: no public benchmark confirms
  Voxtral-Mini-Realtime runs well on AMD ROCm as of April 2026. vLLM
  has ROCm support but coverage for newer Mistral audio models lags
  CUDA.
- **Moonshine Linux CPU benchmarks**: 50/148/258 ms numbers are M3.
  Ryzen ONNX Runtime CPU EP likely 1.5–3× longer. Expect Moonshine
  Small ~200–400 ms first-partial on mid-range Ryzen — still best
  available, verify with measurement.
- **Parakeet v3 on CPU**: community claims of "blazing fast on CPU"
  via ONNX not backed by published RTF. Treat plausible-but-unverified
  until tested.
- **Kyutai 125 ms "flush trick"**: mentioned on website as production
  optimization; algorithmic details not in public paper at level needed
  to reproduce.
- **Parakeet-v3 chunked streaming**: [NeMo#15231][nemo-15231] reports
  Canary-v2 "enters stale status" in streaming; similar concerns may
  apply to Parakeet-v3 chunked. Budget shakedown time.
- **ONNX/OpenVINO EP on Ryzen AI NPU**: AMD published
  [Parakeet-TDT demo for Ryzen AI NPU][amd-npu] — Windows-only today;
  not useful for NixOS short-term.
- **niri input-method-v2 / text-input-v3 support**: tracked in
  [niri#2476][niri-2476]; no assignee, no PR linked as of April 2026.
  Re-check quarterly.

[nemo-15231]: https://github.com/NVIDIA-NeMo/NeMo/issues/15231
[amd-npu]: https://github.com/amd/RyzenAI-SW/tree/main/Demos/ASR/Parakeet-TDT
