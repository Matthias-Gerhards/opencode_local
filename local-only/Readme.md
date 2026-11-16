# opencode (local-only) for Windows x64

## Contents

| File | Purpose |
| --- | --- |
| `opencode.exe` | opencode, built from `github.com/Matthias-Gerhards/opencode_local` |
| `rg.exe` | ripgrep 15.1.0 (file search, required by opencode) |
| `install.bat` | Creates `opencode.jsonc` from the template with your organisation name, model name and server URL |
| `opencode-offline.cmd` | Start script: sets the offline settings and finds `rg.exe` |
| `opencode.jsonc_template` | Configuration template (never changed by `install.bat`) |

## Setup

1. Copy this folder to a permanent location, e.g. `C:\Tools\opencode-windows\`.
2. Run `install.bat` in this folder and enter, one after the other:
   - `Organisations_Name`: display name of the provider, e.g. `ACME LLM`
   - `Model_Name`: the model ID as returned by `GET <baseURL>/models`, e.g. `qwen3-coder:30b` (also used as the model's
     display name)
   - `Model_Url`: address of your organisation's LLM server, e.g. `http://llm.intern:8000/v1`
   - `Windows_Username`: the Windows user who will run opencode (press Enter for the current user)

   `install.bat` creates `opencode.jsonc` from `opencode.jsonc_template` in this folder and copies it to
   `C:\Users\<Windows_Username>\.config\opencode\opencode.jsonc`. The folder `.config\opencode` is created if
   needed; the user folder `C:\Users\<Windows_Username>` must already exist, otherwise `install.bat` stops with an
   error and changes nothing. In both places, an existing `opencode.jsonc` is saved as `opencode.jsonc.bak` first
   (replacing the backup of the previous run).
   You can run `install.bat` again to correct a value; manual edits to `opencode.jsonc` are then only kept in
   `opencode.jsonc.bak`. If `"context"` / `"output"` do not match the model, adjust them in
   `C:\Users\<Windows_Username>\.config\opencode\opencode.jsonc`.

   To edit it by hand instead, copy `opencode.jsonc_template` to `%USERPROFILE%\.config\opencode\opencode.jsonc`
   and fill in the `"organisation"` section:
   - `"baseURL"`: address of your organisation's LLM server, e.g. `http://llm.intern:8000/v1`
   - the model ID instead of `"model-id"` (as returned by `GET <baseURL>/models`)
   - `"context"` / `"output"` to match the model

   At the very top, set `"model"` to the same model ID: `"organisation/<model-id>"`.

   The provider name `organisation` can be changed, but it must be identical in all five places marked
   `[organisation]` in `opencode.jsonc` (the provider key, `"model"` and three entries under `"policies"`).
3. If the server requires an API key: in `opencode-offline.cmd`, enable the line `rem set ORGANISATION_API_KEY=...` and
   enter the key. If you rename the variable, use the same name under `"env"` in `opencode.jsonc`.
4. Always start opencode through `opencode-offline.cmd`, never directly through `opencode.exe`. In the project
   folder:

   ```bat
   C:\Tools\opencode-windows\opencode-offline.cmd
   ```

## Check

```bat
opencode-offline.cmd models
```

The output must list `organisation/<model-id>`.

## Troubleshooting

- **The model does not read files / does not call tools:** the server must support tool calling. For reasoning
  models, set `"body": { "reasoning_effort": "none" }` on the model in `opencode.jsonc`.
- **"Timed out waiting for response headers":** add e.g. `"headerTimeout": 900000` (milliseconds) under
  `"settings"`.
- **"ripgrep not found":** `rg.exe` must be in the same folder as `opencode.exe`.
- **"ECONNREFUSED", or an Ollama / LM Studio model is used:** set `"model": "organisation/<model-id>"` in
  `opencode.jsonc`.
- **The provider is missing from `opencode-offline.cmd models` after renaming it:** the name in one of the five
  `[organisation]` places in `opencode.jsonc` does not match. The policies block every provider that is not allowed
  by name, without an error message.
- **Web search:** it is disabled in the program itself and cannot be turned on.
- **Internet access happens anyway:** on first launch opencode starts a background server that keeps running
  after you close opencode and is reused on every start. If it was ever started without `opencode-offline.cmd`,
  it lacks the offline settings. Fix:

  ```bat
  opencode-offline.cmd service stop
  ```

  Then start opencode again as usual.

## Updating to a new version

1. Close opencode and stop the background server:

   ```bat
   opencode-offline.cmd service stop
   ```

2. Replace `opencode.exe` with the new file.
3. Compare the new `opencode.jsonc_template` with your own `opencode.jsonc` and copy over new entries (e.g. `"model"`). Do not simply
   overwrite your own file, otherwise `baseURL` and the model ID are placeholders again.

### Updating from a release up to 2026-11-10

Releases up to 2026-11-10 stored sessions in `opencode-local-tree-sitter.db`; newer releases use
`opencode-local-only.db`. Without the following step, opencode starts with an empty session list (the old sessions
are not deleted). To keep them, do this after step 1 and before the first start of the new version:

1. Show the database path of the new version:

   ```bat
   opencode-offline.cmd debug paths
   ```

   The `db` line ends in `opencode-local-only.db`.
2. In that folder, rename `opencode-local-tree-sitter.db` to `opencode-local-only.db`. If files ending in
   `-wal` or `-shm` exist next to it, rename them the same way (`opencode-local-only.db-wal`,
   `opencode-local-only.db-shm`).
