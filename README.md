# nvim_hs – Neovim × Hammerspoon Command Framework

能在nvim與hammerspoon來通信，使得也能用nvim來操作hammerspoon的相關函數

---


## 原理

```lua
require("hs.ipc") -- 當hammerspoon使用了IPC, 那麼終端機就能使用指令`hs -c ...`這個就能使用
```


```sh
hs -c 'return require("myLib")'        # 當中的查找的路徑包含了: ~/.hammerspoon/myLib/init.lua
hs -c 'return require("myLib.hello")'  # ~/.hammerspoon/myLib/hello.lua
# 因此只要把想要的實作，寫入到這些檔案即可. hs裡面提供了很多操控系統的函數能使用，這比直接從nvim去寫相關內容會輕鬆許多
```

> [!WARNING] 需要注意的是require的內容如果只寫module而是只接展開，那麼require的特性多次引用只會有一次，所以下次再呼叫將會無效

至於nvim與其溝通的部份，只要讓nvim去用

> `hs -c '...'`

想辦法做到這事，那麼剩下來就是hammerspoon的lua來決定

而為了讓IPC能夠順利, 會將內容用b64來傳

```lua
-- `git show -p 6d65aeb5:nvim/lua/nvim_hs/transport.lua | bat -l lua -P -r 12:23`
return string.format(
  [[return require("nvim_hs").handle(%q)]],  -- nvim_hs 指的是: ./hammerspoon/nvim_hs/init.lua
  b64
)
```

## ✨ 特色

- 統一: 只用一個指令`:Hs`就能做所有的事: 複雜的參數可用json來傳. 因為在nvim上可以有補全和歷史輸入記錄, 所以即便參數很複雜也不會太難輸入


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
│       ├── encoding/
│       │   ├── json.lua
│       │   └── base64.lua
│       └── actions/
│           ├── system.lua        # system.ping / system.list
│           ├── audiodevice.lua   # audiodevice.set_volume
│           └── window.lua        # window marks + snapshot/apply + hotkeys
└── nvim/                         # Neovim side (Lua plugin)
    └── lua/
        ├── nvim_hs.lua           # Public API: require("nvim_hs").run(...)
        └── nvim_hs/
            ├── transport.lua     # ONLY module that knows about `hs -c`
            ├── protocol.lua      # Request encoding + response decoding
            ├── command.lua       # :Hs user-command frontend
            └── marks_buffer.lua  # :HsMarks scratch buffer
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
[nvim_hs] framework loaded – actions: audiodevice.set_volume, system.list, system.ping, window.clear_slot, window.focus_slot, window.list_marks, window.mark
```


## 3. Neovim setup

能用建立連結的方式來安裝此[nvim的插件](./nvim)

因為我們打算用`vim.cmd.packadd`來加入, 所以可以自己找想要的路徑

用以下的方式查詢nvim的runtimepath
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

-- 基本用法（completion cache 預設為 nil = 只抓一次後永久快取）
require("nvim_hs.command").setup()

-- 或指定 cache TTL（秒）
-- require("nvim_hs.command").setup({
--   completion_cache_ttl = 30,  -- 30 秒後重新向 Hammerspoon 查詢
--   -- completion_cache_ttl = nil,  -- 只抓一次，之後永遠用 cache（預設）
-- })
```

`:Hs` 的補全會動態呼叫 `system.list`（Hammerspoon registry 是唯一真相來源），不再 hardcode

若你新增了 action 並 reload 了 Hammerspoon，但 Neovim 還在用舊 cache，可手動清除：

```lua
require("nvim_hs.command").refresh_completions()
```


---

## 4. Usage

### From Lua

```lua
local hs = require("nvim_hs")

local r1 = hs.run("system.ping")
-- → { ok = true, data = "pong" }

local r2 = hs.run("system.list")
print(vim.inspect(require("nvim_hs").run("system.list")))
-- → { ok = true, data = { "system.list", "system.ping" } }

local r3 = hs.run("foo.bar")
-- → { ok = false, error = { code = "ACTION_NOT_FOUND", message = "Unknown action: foo.bar" } }

print(vim.inspect(require("nvim_hs").run('audiodevice.set_volume', { value=30 }))) -- `git show -p 6d65aeb5:nvim/lua/nvim_hs.lua | bat -l lua -P -r 14:24 -r 53`
```

### From the command line inside Neovim

```vim
" require("nvim_hs.command").setup()

:Hs system.ping
:Hs system.list
```

`:Hs` is only a thin frontend that calls [nvim_hs.run()](https://github.com/CarsonSlovoka/nvim_hs/blob/b25185b5e03788b740709e2510aacfd9bd2cde84/nvim/lua/nvim_hs.lua#L14-L50)


```vim
:Hs audiodevice.set_volume {"value":30}
```

---

## 5. Window Marks（視窗標記槽）

類似世紀帝國的部隊編隊，可把目前 focused 的視窗標記到 slot `1`–`9` 或 `a`–`z`，之後快速切換。

Slot 的 source of truth 是 Hammerspoon 端的 `SLOT_ORDER`（`"1"`..`"9"` 然後 `"a"`..`"z"`）。從 Neovim 傳 `slot` 時：

- 數字 `1`–`9` 仍可用（會正規化成字串 `"1"`–`"9"`）
- 字母請傳小寫字串，例如 `"a"`（大小寫都會被 lower）

### 熱鍵（Hammerspoon modal）

全域只佔一個前置鍵。標記 / 切換的按鍵只在 mode 內生效，因此不會長期佔領 `Cmd+A` 或數字鍵。

| 熱鍵 | 行為 |
|------|------|
| `Cmd + F2` | 進入 Window Marks mode |
| *mode 內* `Cmd + 1`–`9` / `a`–`z` | 把目前 focused 視窗標記到對應 slot，然後離開 mode |
| *mode 內* `1`–`9` / `a`–`z` | 切換到該 slot 的視窗，然後離開 mode |
| *mode 內* `Escape` 或再按一次 `Cmd + F2` | 離開 mode |
| 進入 mode 後約 5 秒沒動作 | 自動離開 mode |

平時（未按 `Cmd+F2`）這些按鍵 **不會**被這個 framework 攔截。

- 進入 mode：畫面中央會出現「Window Marks」
- 標記成功：畫面中央會出現短提示
- 切換成功：**不顯示**提示（乾淨）
- 被標記的視窗若已縮小（minimize）或 App 被隱藏（Cmd+H），`focus_slot` 會先還原再聚焦
- 該 slot 是空的：顯示「Slot X is empty」
- 被標記的視窗被關掉時，該 slot 會自動清除
- **不持久化**（Hammerspoon reload 後清空）
- 若 `Cmd+F2` 沒反應：系統設定裡把 F1、F2 等當成標準功能鍵，或改按 `Fn+Cmd+F2`

### 對應的 nvim_hs actions

```vim
:Hs window.mark {"slot":3}
:Hs window.mark {"slot":"a"}
:Hs window.focus_slot {"slot":"a"}
:Hs window.list_marks
:Hs window.clear_slot {"slot":"a"}
:Hs window.snapshot
```

或在 Lua 中：

```lua
local hs = require("nvim_hs")

hs.run("window.mark", { slot = 3 })
hs.run("window.mark", { slot = "a" })
hs.run("window.focus_slot", { slot = "a" })
hs.run("window.list_marks")
-- → { ok = true, data = { { slot = "3", window = { ... } }, { slot = "a", window = { ... } }, ... } }
```

### 用 Neovim buffer 批次編鍵

`require("nvim_hs.command").setup()` 會一併註冊 `:HsMarks`

```vim
:HsMarks
```

會開一個 scratch buffer（快照），例如：

```text
# slot<TAB>id<TAB>app<TAB>title
# slot = 1-9 / a-z to assign,  -  to leave unmarked.
# Delete a line to unmark.  Duplicate slot or id is rejected.
# :w applies the whole buffer.  :HsMarks refreshes the snapshot.
#
a	12345	Safari	GitHub
3	67890	Code	window.lua
-	11111	Finder	Downloads
```

> [!NOTE] 沒有任何 slot 時，視窗列第一欄會是 `-`，改成 `a` / `3` 再 `:w` 即可

編輯規則：

- 改第一欄：換槽（`a` → `s`）
- 改成 `-` 或刪掉該行：取消標記
- 未編的行把 `-` 改成 `a`：新編
- 同一個 slot 或同一個 id 出現兩次：整批拒絕，marks 不會被改到一半
- 套用時視窗已關掉：該行 skip，其餘照套
- `id` 是身份，不要改；`app` / `title` 只是給人看的

```vim
:w          " 把整張表套用到 Hammerspoon
:HsMarks    " 重新拉 snapshot（編到一半視窗有開關時用）
```

Buffer 文字只在 Neovim 解析。送給 Hammerspoon 的是：

```json
{
  "items": [
    { "slot": "a", "id": 12345 },
    { "slot": "3", "id": 67890 }
  ]
}
```

熱鍵日常切換仍可用；這張表負責批次重排

#### 原理

在nvim中建立一個buffer, 記得設定`buftype=acwrite`使得`:w`時可以觸發事件: `BufWriteCmd`

之後再該事件觸發:

> hs -c "require("nvim_hs").handle(b64_para)"

當中的參數可以是buffer中的內容，再編碼而成 (這裡是觸發`window.apply_marks`)

如此再寫hammerspoon所對應的接口(apply_marks)即可完成

```sh
git show -p 571d7cce:nvim/lua/nvim_hs/marks_buffer.lua | bat -l lua -P \
      -r 203:210            \
      -r 168:184            \
      -r 137 -r 145:148

# 203:210 command
# 168:184 acwrite, apply_buf
# 137:148 告知hs執行模組: window.apply_marks

# nvim_hs.run 的細節
git show -p 6d65aeb5:nvim/lua/nvim_hs.lua | bat -l lua -P -r 18 -r 29 -r 34 -r 39 -r 52:53
## hs -c "require("nvim_hs").handle(b64_para)" 👈 這個就是跑hs的lua模組. 例如: window.apply_marks
git show -p 2373ffc8:nvim/lua/nvim_hs/transport.lua | bat -l lua -P -r 32 \
    -r 34 \
    -r 16:23 \
    -r 36:44

# hammerspoon端
git show -p 571d7cce:hammerspoon/nvim_hs/actions/window.lua | bat -l lua -P \
    -r 368 -r 374:375 \
    -r 301:302 \
    -r 307:309 -r 311 -r 326:329 \
    -r 331 -r 335 -r 345 -r 351 \
    -r 357:359 -r 365 \
    -r 21 -r 39
```


## 6. Protocol

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

## 7. Testing the full round-trip (manual)

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

## 8. Automated / unit tests

### Neovim-side protocol tests

```sh
nvim -l tests/test_hs_framework.lua
nvim -l tests/test_marks_buffer.lua
```

These cover:

- protocol encode / decode round-trip
- registry lookup & list
- dispatcher success path
- dispatcher unknown-action error
- dispatcher invalid-request error
- full `handle()` path for `system.ping`

---

## 9. Common troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `HS_NOT_FOUND` | `hs` not in PATH | Run `hs.ipc.cliInstall()` once, check `which hs` |
| `HS_NOT_RUNNING` / Unable to connect | Hammerspoon not running or `hs.ipc` not required | Start HS, ensure `require("hs.ipc")` is in init.lua, reload |
| `ACTION_NOT_FOUND` | Typo or action not registered | Check `:Hs system.list` |
| Empty / garbage response | Framework not loaded on HS side | Check HS console for load errors, verify `package.path` |
| Permission / symlink issues with CLI | Broken previous install | `hs.ipc.cliUninstall()` then `cliInstall()` again |

---

## 10. Architecture summary (v1)

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
