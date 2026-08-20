# nvim_hs – Neovim × Hammerspoon Command Framework

Minimal, structured, end-to-end command framework that lets Neovim call named actions running inside Hammerspoon.

**First version (bootstrap)** only implements:

- `system.ping`
- `system.list`

All other domains (`app.*`, `window.*`, …) are intentionally deferred until the core transport / protocol / registry path is proven stable.

---

## 1. Repository structure

```text
.
├── README.md
├── hammerspoon/                  # Hammerspoon side
│   ├── init.lua                  # Minimal bootstrap (IPC + framework)
│   └── nvim_hs/
│       ├── init.lua              # Framework entry – exposes handle()
│       ├── protocol.lua          # JSON ↔ Base64 encode/decode, ok/err helpers
│       ├── registry.lua          # action name → handler (source of truth)
│       ├── dispatcher.lua        # request → lookup → call → response
│       └── actions/
│           └── system.lua        # system.ping / system.list
└── nvim/                         # Neovim side (Lua plugin)
    └── lua/
        └── nvim_hs/
            ├── init.lua          # Public API: require("nvim_hs").run(...)
            ├── transport.lua     # ONLY module that knows about `hs -c`
            ├── protocol.lua      # Request encoding + response decoding
            └── command.lua       # :Hs user-command frontend
```

---

## 2. Hammerspoon setup

### 2.1 取得: hammerspoon

```sh
brew install hammerspoon
```


### 2.2 Load this project


```sh
git clone https://github.com/CarsonSlovoka/nvim_hs ~/nvim_hs
```


可以用建立連結的方式來將對應的檔案放到 hammerspoon 下

```bash
# example (看專案的位置clone到哪)
ln -s ~/nvim_hs/hammerspoon/nvim_hs ~/.hammerspoon/nvim_hs

# 或者
ln -siv $(realpath ./hammerspoon/nvim_hs) ~/.hammerspoon/nvim_hs
```

接著加入以下的內容到[~/.hammerspoon/init.lua](~/.hammerspoon/init.lua) 如果沒有這個檔案就新增它

> [!IMPORTANT] 內容參考[init.lua](hammerspoon/init.lua)

---

完成之後，重新reload. (`hs.reload()`或者用UI介面來重啟都可以)

成功後會在hammerspoon的console視窗看到以下的內容

```text
[nvim_hs] framework loaded – actions: system.list, system.ping
```


## 3. Neovim setup

Add the `nvim/` directory to your runtime path, e.g. in `init.lua`:

```lua
vim.opt.rtp:prepend("/path/to/this/repo/nvim")
```

(or use a plugin manager that points at the `nvim/` folder).

Then register the `:Hs` command (recommended once at startup):

```lua
require("nvim_hs.command").setup()
```

或者也可以用建立連結的方式

```lua
for _, path in  vim.split(vim.opt.runtimepath._value, ",") do
  print(path)
end
-- 例如，你可能會看到以下的路徑
-- ~/.local/share/nvim/site
-- /etc/xdg/nvim
-- /usr/share/nvim/site
--
-- 所以生成的內容在以下的位置都行
-- ~/.local/share/nvim/site/pack/*/opt/{name}  👈 我們選這個來加
-- /etc/xdg/nvim/pack/*/opt/{name}
-- /usr/share/nvim/site/pack/*/opt/{name}

```


```sh
mkdir -pv ~/.local/share/nvim/site/pack/mine/opt/
ln -siv   $(realpath ./nvim) ~/.local/share/nvim/site/pack/mine/opt/nvim_hs
```

完成之後在 nvim 中可以使用 vim.cmd.packadd 來加入


```lua
vim.cmd.packadd("nvim_hs") -- nvim/lua/nvim_hs.lua
require("nvim_hs.command").setup()
```


---


```sh
# 底下樣加了之後，去跑 tests/test_hs_framework.lua 會失敗, 因為nvim_hs會抓錯人
# ln -siv $(realpath ./nvim/lua/nvim_hs)     ~/.config/nvim/lua/nvim_hs
# ln -siv $(realpath ./nvim/lua/nvim_hs.lua) ~/.config/nvim/lua/nvim_hs.lua # 讓 require("nvim_hs") 能有用
```

---

## 4. Usage

### From Lua

```lua
local hs = require("nvim_hs")

local r1 = hs.run("system.ping")
-- → { ok = true, data = "pong" }

local r2 = hs.run("system.list")
-- → { ok = true, data = { "system.list", "system.ping" } }

local r3 = hs.run("foo.bar")
-- → { ok = false, error = { code = "ACTION_NOT_FOUND", message = "Unknown action: foo.bar" } }
```

### From the command line inside Neovim

```vim
" require("nvim_hs.command").setup()

:Hs system.ping
:Hs system.list
```

`:Hs` is only a thin frontend that calls `nvim_hs.run()`.

---

## 5. Protocol

### Request (Neovim → Hammerspoon)

```json
{
  "version": 1,
  "action": "system.ping",
  "payload": {}
}
```

Transport path:

```text
Lua table
  → vim.json.encode
  → vim.base64.encode
  → hs -c 'return require("nvim_hs").handle("<b64>")'
  → hs.base64.decode
  → hs.json.decode
  → dispatcher
```

### Success response

```json
{
  "ok": true,
  "data": <any>
}
```

### Error response

```json
{
  "ok": false,
  "error": {
    "code": "ACTION_NOT_FOUND",
    "message": "Unknown action: foo.bar"
  }
}
```

Common error codes:

| code               | meaning                                      |
|--------------------|----------------------------------------------|
| `HS_NOT_FOUND`     | `hs` binary not in `$PATH`                   |
| `HS_NOT_RUNNING`   | Hammerspoon not running / IPC unavailable    |
| `IPC_ERROR`        | CLI returned non-zero exit                   |
| `DECODE_ERROR`     | Base64 / JSON decode failed                  |
| `INVALID_REQUEST`  | Missing action / wrong version               |
| `ACTION_NOT_FOUND` | Action not registered                        |
| `HANDLER_ERROR`    | Handler raised a Lua error                   |
| `INVALID_RESPONSE` | Response shape unexpected                    |

---

## 6. Testing the full round-trip (manual)

1. Make sure Hammerspoon is running and the framework is loaded (see §2).
2. Open Neovim with the plugin on `rtp`.
3. Run:

```vim
:Hs system.ping
```

Expected output:

```text
pong
```

4. Run:

```vim
:Hs system.list
```

Expected (order may vary, sorted alphabetically):

```text
{ "system.list", "system.ping" }
```

or the `vim.inspect` equivalent.

5. From Lua:

```lua
:lua print(vim.inspect(require("nvim_hs").run("system.ping")))
```

---

## 7. Automated / unit tests

### Neovim-side protocol tests

```sh
nvim -l tests/test_hs_framework.lua
```

These cover:

- protocol encode / decode round-trip
- registry lookup & list
- dispatcher success path
- dispatcher unknown-action error
- dispatcher invalid-request error
- full `handle()` path for `system.ping`

---

## 8. Common troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `HS_NOT_FOUND` | `hs` not in PATH | Run `hs.ipc.cliInstall()` once, check `which hs` |
| `HS_NOT_RUNNING` / Unable to connect | Hammerspoon not running or `hs.ipc` not required | Start HS, ensure `require("hs.ipc")` is in init.lua, reload |
| `ACTION_NOT_FOUND` | Typo or action not registered | Check `:Hs system.list` |
| Empty / garbage response | Framework not loaded on HS side | Check HS console for load errors, verify `package.path` |
| Permission / symlink issues with CLI | Broken previous install | `hs.ipc.cliUninstall()` then `cliInstall()` again |

---

## 9. Architecture summary (v1)

```text
Neovim
  require("nvim_hs").run(action, payload)
      ↓
  protocol.encode_request → Base64
      ↓
  transport.execute  (vim.system { "hs", "-c", expr })
      ↓
  hs CLI  →  Hammerspoon IPC
      ↓
  nvim_hs.handle(b64)
      ↓
  protocol.decode → dispatcher.dispatch
      ↓
  registry.get(action) → handler(payload)
      ↓
  protocol.ok / protocol.err → JSON string
      ↓
  stdout back to Neovim
      ↓
  protocol.decode_response → structured table
```

Only `transport.lua` ever mentions the `hs` binary.
`:Hs` never talks to the process directly.

---

## Next steps (after this bootstrap is verified)

1. Add a few more low-risk system actions (e.g. `system.reload`, `system.version`).
2. Introduce `app.*` / `window.*` once the error-handling surface is solid.
3. Optional: completion for `:Hs` that calls `system.list`.
4. Optional: asynchronous `run_async` API.


## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

**Note:** This project is a client/framework that communicates with [Hammerspoon](https://www.hammerspoon.org/) via its official IPC/`hs` CLI.

Hammerspoon itself is also licensed under the MIT License and is not distributed with this repository.
