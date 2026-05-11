# BuildSentry.nvim

> ⚠️ **Still under active development** — APIs and behaviour may change.

A Neovim plugin for managing and monitoring build/run tasks directly inside the editor. It provides a multi-pane floating UI with a live task list, real-time output streaming, and first-class integration with [cmake-tools.nvim](https://github.com/Civitasv/cmake-tools.nvim).

---
## Demo
<img width="1568" height="868" alt="Screenshot 2026-05-11 161403" src="https://github.com/user-attachments/assets/fc298cb0-b1ae-4aeb-9a9b-e22b18720a57" />


## Features

- **Floating UI** — a centred panel with three panes: task list, live output, and a context-sensitive key guide.
- **Live task list** — newest task appears at the top; each entry shows status icon, status label, task name, and the last output line as a virtual line.
- **Colour-coded status** — `RUNNING` (info), `SUCCESS` (ok), `FAILED` (error), `TERMINATED` (warning), using your theme's diagnostic colours.
- **Real-time output streaming** — PTY-backed job output is piped directly into a terminal buffer and updated incrementally.
- **Error jump** — when a build fails, press `e` to close the UI and jump straight to the offending file/line.
- **Restart / Kill** — restart or kill any task without leaving the UI.
- **cmake-tools adapter** — registers itself as both the `executor` and `runner` backend for cmake-tools so all CMake configure, build, and run commands flow through BuildSentry automatically.

---

## Requirements

- Neovim **≥ 0.10** (extmarks, `nvim_open_term`, float titles required)
- [cmake-tools.nvim](https://github.com/Civitasv/cmake-tools.nvim) *(optional — only needed for the CMake integration)*

---

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

#### Example for BuildSentry 

```lua
-- BuildSentry.nvim
{
  "zischl/BuildSentry.nvim",
  opts = {
    attach_cmake_tools = true, 
    --Basically nothing will be there if set to false cuz I only made a cmake tools adapter for now
  },
}
```

#### Example for cmake-tools.nvim 

```lua
-- cmake-tools.nvim
{
  "Civitasv/cmake-tools.nvim",
  opts = {
    cmake_command = "cmake",  --Not really necessary for BuildSentry
    ctest_command = "ctest",  --This too, u do u
    cmake_regenerate_on_save = true,  --Personal preference
    cmake_generate_options = { "-DCMAKE_EXPORT_COMPILE_COMMANDS=1" }, --To generate compile_commands.json
    cmake_build_directory = "build/${variant:buildType}",  --Personal preference

  },
}
```


## Configuration

`setup()` accepts the following options, no need to manually call it though (defaults shown):

```lua
require("buildsentry").setup({
  -- Automatically registers BuildSentry as the executor and runner if set to true
  attach_cmake_tools = false,
})
```

---

## Usage

### Opening the UI

```vim
:BuildSentry
" or
:BuildSentryOpen
```

From Lua:

```lua
require("buildsentry").open()
```


---

## UI Key Bindings

These bindings are active while the **Tasks** pane is focused:

| Key | Action |
|-----|--------|
| `q` | Close the BuildSentry UI |
| `r` | Restart the selected task |
| `x` | Kill (terminate) the selected task |
| `e` | Jump to the error location *(shown only when the task has a recorded error)* |

Navigate the task list with standard Neovim cursor movement (`j` / `k` / `up arrow` / `down arrow`). The output pane and the key guide update automatically as you move between tasks.

---

## cmake-tools Integration

When `attach_cmake_tools = true`, BuildSentry registers itself as the `buildsentry` executor and runner inside cmake-tools. Once both are set, all cmake-tools commands — **CMake Configure**, **CMake Build**, **CMake Run** — will open BuildSentry automatically.

Task names are inferred from the command:

| cmake-tools command | BuildSentry task name |
|---------------------|-----------------------|
| Configure | `CMake Configure` |
| Build (all) | `CMake Build` |
| Build `<target>` | `CMake Build: <target>` |
| Run executable | `Run: <executable>` |
| Custom title via `opts.title` | *( whatever title you put there )* |

---

## Architecture

```
plugin/
  BuildSentry.lua          -- registers :BuildSentry user commands

lua/buildsentry/
  init.lua                 -- public API (setup / open / exec)
  config.lua               -- option defaults & merging
  state.lua                -- shared runtime state (tasks, windows, buffers)
  task.lua                 -- Task class (lifecycle, PTY streaming, error parsing)
  executor.lua             -- exec / stop_task / restart_task helpers

  adapter/
    cmake.lua              -- cmake-tools executor/runner adapter

  ui/
    init.lua               -- UI orchestrator (open / close / refresh)
    window.lua             -- float creation & layout calculation
    task_list.lua          -- incremental task list rendering via extmarks
    guide.lua              -- context-sensitive key guide pane
    actions.lua            -- action registry (keybindings & callbacks)
```

---

## Task Statuses

| Status | Meaning |
|--------|---------|
| `RUNNING` | Job is currently executing |
| `SUCCESS` | Job exited with code 0 |
| `FAILED` | Job exited with a non-zero code |
| `TERMINATED` | Job was manually killed |

---

## License

MIT — see [LICENSE](LICENSE).
