# opencode local – what this fork does differently

This fork is opencode that runs without internet access. It is meant for networks with no internet connection:
models run on your own server (Ollama, LM Studio, vLLM, llama.cpp, …), and opencode does not connect to
opencode.ai, GitHub, npm or any cloud provider.

For everyday use, the regular opencode [README](README.md) applies. This file only covers what is different and
what you need to know to run it.

> Technical details on every change (for merging with upstream): [`FORK-CHANGES.md`](local-only/FORK-CHANGES.md)

---

## What is changed in the program

These changes are built in and cannot be reverted through the config.

| Area | Upstream behavior | In this fork |
| --- | --- | --- |
| **Model catalog** | downloads the model list from `models.opencode.ai` | uses the bundled catalog. A custom catalog can be supplied via `OPENCODE_MODELS_PATH` (file) or `OPENCODE_MODELS_URL` (local mirror) |
| **ripgrep** (file search) | downloads `rg` from GitHub when needed | downloads nothing. `rg` must be installed, otherwise you get a clear error message |
| **Syntax highlighting** in the terminal | downloads grammars from GitHub | grammars are bundled. Languages that are not included are shown without colors |
| **Web search** | the model may search the web (Exa even without an API key) | **always off**. Search queries could carry code from the session to the outside. The lock is compiled in and takes precedence over any config |

---

## What is disabled through the config

The file [`opencode.jsonc`](local-only/opencode.jsonc) is a ready-made template. Place it at
`~/.config/opencode/opencode.jsonc` (Windows: `%USERPROFILE%\.config\opencode\opencode.jsonc`).

It disables or sets:

- **Updates**: no update check (`"update": "disable"`)
- **Sharing**: no session links via opencode.ai (`"share": "disabled"`)
- **Formatters**: no automatic download of prettier & co. from npm (`"formatter": false`)
- **webfetch**: requests to the internet are denied, only `localhost`/`127.0.0.1` are allowed. If needed, webfetch
  can be enabled with a confirmation prompt before each request (commented-out lines in the template).
- **Cloud providers and accounts** (OpenAI, Anthropic, Copilot, opencode Console, …): blocked
- **Local providers**: Ollama, LM Studio and a company server (`"firma"`) are allowed
- **Default model**: set explicitly so opencode does not pick a model whose server isn't running

Every user can change these settings in their own config. Only what is listed above under "What is changed in the
program" is built in.

---

## Setup

### 1. Adjust the config

In `opencode.jsonc`:

1. For the `"firma"` provider, enter the address of your LLM server (`"baseURL"`) and, under `"models"`, the model
   ID exactly as the server reports it at `<baseURL>/models`.
2. Set `"model"` to `"firma/<model-id>"`.
3. Remove unused local providers (Ollama, LM Studio) from `"policies"` and `"providers"`.
4. If the server requires an API key, set the environment variable `FIRMA_API_KEY`.

Note for reasoning models (e.g. Qwen3): if the model produces no tool calls after thinking, the
`reasoning_effort` hint in the template helps.

### 2. Set environment variables

**macOS / Linux:** source [`offline.env`](local-only/offline.env), e.g. in `~/.zshrc`:

```sh
set -a; source /path/to/local-only/offline.env; set +a
```

**Windows:** put [`opencode-offline.cmd`](local-only/opencode-offline.cmd) next to `opencode.exe` and `rg.exe` and
start opencode through it. The script sets the same variables and finds `rg.exe` in the same folder.

### 3. Provide ripgrep

- macOS: `brew install ripgrep` (before moving into the offline network) or put `rg` on your `PATH`
- Linux: package `ripgrep`
- Windows: `rg.exe` next to `opencode.exe`

---

## Verifying that everything stays offline

- Start opencode: it must start without internet, show the model list and work with the local server.
- Watch outgoing connections, e.g. `lsof -i -P | grep opencode` or with Little Snitch / LuLu (macOS).
  Only connections to `127.0.0.1` or your own LLM server are expected.

---

## What the fork does not prevent

The locks prevent **the model** from sending data to the outside on its own. They do not protect against a user who
deliberately sets this up:

- **MCP servers** can still be added to the config, including ones with an internet address.
- The **shell tool** can run commands such as `curl` (with a confirmation prompt, depending on permission settings).
- **Plugins** are code with full privileges.

Reliable isolation is only possible at the network level (firewall, proxy, or a network without internet access).

---

## Updating the fork

The fork has two main branches:

- **`local`**: this fork's state with all changes. This is the branch you build and use.
- **`dev`**: unmodified opencode (upstream). It serves as the comparison baseline and is only synced with upstream.

A new opencode version arrives in `dev` via "Sync fork" and is then merged into `local`. Afterwards, run
`local-only/check-fork.sh` from the repo root.
The script reports whether any fork change was lost during the merge and lists internet addresses in the code that
may have been added. The exact procedure is described in [`FORK-CHANGES.md`](local-only/FORK-CHANGES.md).
