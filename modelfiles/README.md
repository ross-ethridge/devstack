# Local coding models for the `pi` agent

Ollama **Modelfiles** + the full [`pi`](https://pi.dev) setup for running a local coding
**agent** (one that actually uses tools) on this machine — 8 GB RTX 4060, Pop!_OS. No cloud
API, no per-token cost. One Modelfile per model:

| Model | Dir | Role |
|-------|-----|------|
| **Qwen3-8B** → `qwen3` | `qwen/` | **Default.** Tool calls work on Ollama; ~2× gemma speed; mostly on GPU. |
| Gemma-4-12B → `gemma4-coder` | `gemma4/` | Fallback. Tools work but slow (CPU-split) and drifts under load. |

> **The deciding factor was tool calling, not raw model quality.** A local *agent* is
> useless if its tool calls don't execute. On this Ollama (v0.30.6):
> - **Gemma-4-12B** — tools work (native parser), but CPU-split on 8 GB → ~17 tok/s, and
>   loses coherence under heavy tool context (once drifted into Japanese).
> - **Qwen2.5-Coder-7B** — fast and fully on GPU, but **its tool calls are broken on
>   Ollama** (emitted as text JSON, `tool_calls` stays null — a [known bug](https://github.com/anomalyco/opencode/issues/7030)). Unusable as an agent. **Removed.**
> - **Qwen3-8B** — tool calls **parse correctly**, ~36 tok/s (~2×), mostly on GPU. **Winner.**

```
 ┌─────────┐   OpenAI /v1   ┌──────────────┐   ┌──────────────┐
 │   pi    │ ─────────────▶ │ Ollama :11434│ ─▶│ qwen3 (def.) │
 │ (agent) │ ◀── tool_calls │              │   │ gemma4-coder │
 └─────────┘                └──────────────┘   └──────────────┘
   + MCP servers (tools) · extensions (memory) · AGENTS.md (rules)
```

---

## ⚠️ Tool calling on Ollama depends on the model's parser

This is the single most important lesson here. When pi sends `tools`, Ollama must (a)
render them into the prompt and (b) parse the model's tool-call output back into a
structured `tool_calls` field. **(b) only works for models Ollama has a working parser
for.** If it fails, the model "calls" the tool as **text JSON in `content`** and nothing
executes — you'll see a `{"name": ..., "arguments": ...}` block printed in chat.

| Model | Ollama parser | Tools execute? |
|-------|---------------|----------------|
| gemma4 | native `RENDERER/PARSER gemma4` | ✅ |
| qwen3 | qwen3 parser | ✅ |
| qwen2.5-coder | template only, no working parser | ❌ (known bug) |

**Diagnose:** `curl /v1/chat/completions` with a `tools` array and check whether
`choices[0].message.tool_calls` is populated vs. the call leaking into `content`.
**If a model you want has broken tools on Ollama,** the fix is a different runner with a
proper parser — `llama.cpp` server with `--jinja`, or vLLM/SGLang with
`--tool-call-parser` — but here we stayed on Ollama and picked qwen3.

---

## The config files

| File | Location | Owns |
|------|----------|------|
| `qwen/qwen3.Modelfile`, `gemma4/gemma4-coder.Modelfile` | this repo | How Ollama loads each model. |
| `~/.pi/agent/models.json` | pi config | Registers both models. |
| `~/.pi/agent/settings.json` | pi config | Default model, thinking level, compaction, packages. |
| `~/.pi/agent/mcp.json` | pi config | MCP servers (tools). |
| `~/.pi/agent/AGENTS.md` | pi config | Behavioral rules ([see below](#where-instructions-live)). |
| `/etc/systemd/system/ollama.service.d/*.conf` | system | Ollama tuning. |

### Modelfiles

**`qwen/qwen3.Modelfile`** (default):
```dockerfile
FROM qwen3:8b
PARAMETER num_ctx      32768   # MUST be baked (Ollama defaults to 4096); native max 40960
PARAMETER num_predict  8192
PARAMETER temperature  0.6     # Qwen3 thinking-mode rec (don't use greedy/temp 0)
PARAMETER top_p        0.95
PARAMETER top_k        20
PARAMETER repeat_penalty 1.05
```
Note: qwen3:8b (8.2B) won't quite hit 100% GPU with useful context (~85% GPU / 15% CPU at
32K). Lowering `num_ctx` shifts a little more onto GPU; raising toward 40960 costs a bit
more CPU. 32K is the balance.

**`gemma4/gemma4-coder.Modelfile`** (fallback): `FROM gemma4:12b`, `num_ctx 65536`,
`num_batch 256`, no custom template. See [Gemma notes](#gemma-notes).

Rebuild after editing, then drop the keep-alive-pinned copy so the rebuild loads:
```bash
ollama create qwen3 -f qwen/qwen3.Modelfile && ollama stop qwen3
```

### `~/.pi/agent/models.json`
Both under the `ollama` provider (`baseUrl: http://localhost:11434/v1`,
`api: openai-completions`, `apiKey: "ollama"` — required but ignored):
- `qwen3:latest` — `reasoning: true` (thinking model), `contextWindow: 32768`, `maxTokens: 8192`
- `gemma4-coder:latest` — `reasoning: true`, `contextWindow: 65536`, `maxTokens: 8192`

Keep each `contextWindow`/`maxTokens` in sync with that model's `num_ctx`/`num_predict`.

### `~/.pi/agent/settings.json`
```json
{
  "defaultProvider": "ollama",
  "defaultModel": "qwen3:latest",
  "defaultThinkingLevel": "medium",
  "enabledModels": ["ollama/*"],
  "compaction": { "enabled": true },
  "packages": ["npm:pi-mcp-extension", "npm:pi-hermes-memory"]
}
```
- `defaultModel` → plain `pi` launches qwen3. Ctrl+P cycles to gemma.
- Both are thinking models — `defaultThinkingLevel` (Shift+Tab live) applies. Drop to `low`/`off` if a model over-deliberates.
- `compaction: true` — pi auto-summarizes old turns so context doesn't overflow (constant compaction / meter in the red = window too small).

---

## Where instructions live

**pi sends its own system prompt, which overrides the Modelfile `SYSTEM` block.** So
Modelfile `PARAMETER`s apply, but `SYSTEM` text is ignored by pi (only used by direct
`ollama run`). Behavioral rules go in **`~/.pi/agent/AGENTS.md`** (loaded every session):
MCP-usage conventions, step-by-step execution rules, and **"ground factual claims in web
search (Playwright) and cite sources."**

**Shared with Claude Code:** it reads `CLAUDE.md`, not `AGENTS.md`, so they're bridged —
`~/.claude/CLAUDE.md` has `@~/.pi/agent/AGENTS.md`; per-repo a `CLAUDE.md` with `@AGENTS.md`.

---

## GPU / memory

8 GB RTX 4060. The constraint is **weights**, and CPU layers are the slow part.

| Model | Weights | On 8 GB | Speed | Tools |
|-------|---------|---------|-------|-------|
| Gemma 12B Q4 | ~7.3 GB | CPU-split (~70% GPU) | ~17 tok/s | ✅ |
| **Qwen3 8B Q4 (default)** | ~5.2 GB | ~85% GPU @32K | **~36 tok/s** | ✅ |
| Qwen2.5-coder 7B Q4/Q6 | 4.7–6.3 GB | 100% GPU | ~40–52 tok/s | ❌ removed |

Takeaway: a model that **fits + has working tools** beats a faster one whose tools don't
fire. Qwen3-8B is the best balance here.

### Ollama service settings (systemd drop-ins)
`/etc/systemd/system/ollama.service.d/*.conf`, then
`sudo systemctl daemon-reload && sudo systemctl restart ollama`:

| Env var | Value | Why |
|---------|-------|-----|
| `OLLAMA_KEEP_ALIVE` | `-1` | Keep model loaded. `sudo systemctl stop ollama` to free VRAM. |
| `OLLAMA_FLASH_ATTENTION` | `1` | Less memory, faster; required for KV quant. |
| `OLLAMA_KV_CACHE_TYPE` | `q8_0` | Quantize KV cache (~half size). |

```bash
ollama ps    # PROCESSOR split; UNTIL = Forever
nvidia-smi --query-gpu=memory.used,memory.free --format=csv
```

---

## MCP servers (the agent's tools)

Enabled by `pi-mcp-extension`, configured in `~/.pi/agent/mcp.json` (`"directTools": true`).

| Server | Type | Lifecycle | Gives the agent | Needs |
|--------|------|-----------|-----------------|-------|
| `playwright` | native | eager | Browser / **web search** (headless) | system Chrome `.deb` (below) |
| `kubernetes` | native | lazy | `kubectl` tools | kubeconfig w/ current-context |
| `filesystem` | native | eager | read/write in `/home/rossethridge/code` | (npx) |
| `gopls` | native | eager | Go intelligence | `gopls` |
| `ruby-lsp` | LSP→MCP bridge | eager | Ruby intelligence + lint | `mcp-language-server`, `ruby-lsp` |
| `python-pyright` | LSP→MCP bridge | eager | Python intelligence | `mcp-language-server`, `pyright` |

- **Lifecycle:** `eager` = auto-start; `lazy` (default) = **manual `/mcp:start <name>`** (not auto-on-use; a stopped lazy server exposes no tools → 0 context). Commands: `/mcp`, `/mcp:start`, `/mcp:stop`.
- **MCP ≠ LSP:** wrap LSP-only servers with the [`mcp-language-server`](https://github.com/isaacphi/mcp-language-server) bridge (one per language). gopls speaks MCP natively (`gopls mcp`).
- **Playwright needs real Chrome.** Pop!_Shop Chrome is a sandboxed **Flatpak** (unusable) and `npx playwright install chrome` **refuses on Pop** (`ID=pop`). Fix: Google's `.deb`:
  ```bash
  curl -fsSLO https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  sudo apt-get install -y ./google-chrome-stable_current_amd64.deb
  ```
  Then the MCP runs `--headless` (no `--executable-path`; don't pin a `~/.cache/...` path).
- **Installs:** `gopls`, `mcp-language-server` (`go install …isaacphi/mcp-language-server@latest`), `ruby-lsp` (gem), `pyright` (npm). On PATH via **mise** shims (use absolute shim paths in `command` if pi can't find them).
- **Security:** `filesystem` scoped to `/home/rossethridge/code` (read+write). `bash-mcp` removed (unrestricted shell). Pylance unusable (MS-licensed); `pyright` is its open core.

---

## Extensions

- **`pi-mcp-extension`** — MCP support + the `/mcp*` commands (without it, no MCP).
- **`pi-hermes-memory`** — persistent memory: **SQLite FTS5 + markdown, no embedding model** (fully local), ~5 always-on tools. Auto-saves (~every 10 turns; corrections immediately). Setup once: `/memory-interview`, `/memory-index-sessions`, `/learn-memory-tool`. Stores under `~/.pi/agent/pi-hermes-memory/` + `~/.pi/agent/projects-memory/<project>/`. If a Node (mise) upgrade breaks it: `cd ~/.pi/agent/npm && npm rebuild better-sqlite3`.

---

## Daily use

```bash
pi                         # default = qwen3
pi -p "summarise x.rb"     # one-shot
```
- **Ctrl+P** switch model · **Shift+Tab** thinking level · **`/mcp`** server status · **`/memory-insights`** audit memory.
- `sudo systemctl stop ollama` when done to free VRAM.

---

## Gemma notes

Fallback. Gemma 4 has native thinking (the renderer/parser handles `<|think|>`/`<|channel>`
— **never hand-roll a `TEMPLATE`**; an early one with `stop "<channel|>"` gave empty
replies). Sliding-window attention keeps its KV tiny, so `num_ctx` barely affects VRAM
(it's at 64K). Tools work, but on 8 GB it's CPU-split/slow and degrades under heavy
context — hence qwen3 is default.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Tool call printed as **text JSON**, nothing runs | Model's tool calls aren't parsed by Ollama (e.g. qwen2.5-coder). Use a model with a working parser (qwen3, gemma4) or a different runner (`llama.cpp --jinja`). |
| **Slow** generation | CPU-split model — prefer qwen3 (mostly GPU). Check `ollama ps`. |
| Model **loses coherence / switches language** | Small model degrading under big/noisy context — use qwen3, fresh session, avoid huge tool-output dumps. |
| **Empty** reply (tools loaded) | Context overflow — session `usage` shows `input ≈ num_ctx`, `stopReason: length`. Rely on compaction; bigger `num_ctx`; trim tools. |
| Empty reply on raw `curl` | `num_predict` too small (thinking/output cut). pi uses 8192. |
| Constant compaction / meter red | Window too small — bigger `num_ctx` or trim tools; ensure `compaction.enabled: true`. |
| Behavioral instruction ignored | It was in Modelfile `SYSTEM` (pi overrides). Put it in `~/.pi/agent/AGENTS.md`. |
| Model loads at 4096 context | `num_ctx` not baked — must be in the Modelfile (OpenAI API can't set it). |
| `cudaMalloc … OOM` | Footprint > 8 GB — smaller quant / lower `num_ctx`; confirm flash-attn + q8 KV set. |
| Playwright "chrome not found" | Install Google Chrome `.deb` (Flatpak won't work). |
| MCP **command not found** | Use the absolute mise shim path in `command`. |
| `lazy` server's tools missing | Expected — `/mcp:start <name>` or set it `eager`. |


