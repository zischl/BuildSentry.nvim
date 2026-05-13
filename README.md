# BuildSentry.nvim

> ⚠️ **Still under active development** — APIs and behaviour may change.

A Neovim plugin for managing and monitoring build/run tasks directly inside the editor. It provides a multi-pane floating UI with a live task list, real-time output streaming, and first-class integration with [cmake-tools.nvim](https://github.com/Civitasv/cmake-tools.nvim).

---
## Demo
<table style="width: 100%;">
  <tr>
    <td width="50%">
      <img src="https://github.com/user-attachments/assets/3a5869a6-043e-4565-b126-9664b0e4f425" alt="Screenshot 1" style="width:100%;">
    </td>
    <td width="50%">
      <img src="https://github.com/user-attachments/assets/56795d92-ec58-4445-94d6-c6b5c1e66a16" alt="Screenshot 2" style="width:100%;">
    </td>
  </tr>
  <tr>
    <td width="50%">
      <img src="https://github.com/user-attachments/assets/655e9c62-f22a-451e-81cc-8f2987f48bba" alt="Screenshot 3" style="width:100%;">
    </td>
    <td width="50%">
      <img src="https://github.com/user-attachments/assets/6bb541bd-b54b-49de-8dd1-906205a6163a" alt="Screenshot 4" style="width:100%;">
    </td>
  </tr>
</table>



## Features

- **Floating UI** — a centred panel with three panes: task list, live output, and a context-sensitive dashboard guide.
- **Dashboard Guide** — A new 2-column UI that dynamically shows available actions and their keybindings based on the current context.
- **Live task list** — newest task appears at the top; each entry shows status icon, status label, task name, and the last output line as a virtual line.
- **Interactive Terminal** — Full support for terminal input. Focus the output pane to interact with your running tasks (e.g., for TUI applications or interactive scripts).
- **Focus Toggling** — Seamlessly switch focus between the Task List and the Terminal Output using `<Tab>` and `<S-Tab>`.
- **Colour-coded status** — `RUNNING` (info), `SUCCESS` (ok), `FAILED` (error), `TERMINATED` (warning), using your theme's diagnostic colours.
- **Real-time output** — Integrated terminal output allowing for native terminal behavior and incremental updates.
- **Error jump** — when a build fails, press `e` to close the UI and jump straight to the offending file/line.
- **Adapter Actions** — Access adapter-specific commands (like CMake Build, Run, Debug) directly from within the UI via a dynamic actions picker.
- **cmake-tools adapter** — Registers itself as both the `executor` and `runner` backend for cmake-tools so all CMake configure, build, and run commands flow through BuildSentry automatically.

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

The UI is divided into context-aware panes. The **Dashboard Guide** at the bottom updates its list of shortcuts based on which pane you are currently focusing.

### Tasks Pane Bindings

These bindings are active while the **Tasks** pane is focused:

| Key | Action |
|-----|--------|
| `q` | Close the BuildSentry UI |
| `h` | Return to the Home Dashboard |
| `a` | Open the **Actions** picker (adapter-specific commands) |
| `r` | Restart the selected task |
| `x` | Kill (terminate) the selected task |
| `e` | Jump to the error location *(shown only when the task has a recorded error)* |
| `d` | Delete the selected task from the registry |
| `C` | Clear all completed tasks |
| `c` | Copy the full command of the selected task to the clipboard |
| `o` | Open the output buffer for the selected task |
| `<Tab>` | Focus the **Output** pane |

Navigate the task list with standard Neovim cursor movement (`j` / `k` / `up arrow` / `down arrow`).

### Output Pane Bindings

These bindings are active while the **Output** (Terminal) pane is focused:

| Key | Action |
|-----|--------|
| `<S-Tab>` | Focus back to the **Tasks** pane |

*Note: In the Output pane, standard terminal interaction is enabled. Use `<S-Tab>` to return to task navigation.*

---

## cmake-tools Integration

When `attach_cmake_tools = true`, BuildSentry registers itself as the default `buildsentry` executor and runner inside cmake-tools. All cmake-tools commands **CMake Configure**, **CMake Build**, **CMake Run** will open BuildSentry automatically.

### Adapter Actions

By pressing `a` in the Tasks pane, you can access common CMake commands without leaving the BuildSentry UI:
- **Build** / **Run** / **Debug**
- **Generate** / **Clean**
- **Select Target** / **Select Kit**
- **Select Build Type** / **Select Build/Config Preset**
- **Select Build Type** and **Edit Build Directory**

### Task Naming

Task names are automatically inferred:

| cmake-tools command | BuildSentry task name |
|---------------------|-----------------------|
| Configure | `CMake Configure` |
| Build (all) | `CMake Build` |
| Build `<target>` | `CMake Build: <target>` |
| Run executable | `Run: <executable>` |
| Custom title via `opts.title` | *( whatever title you put there )* |

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

