# glab.nvim

A Neovim plugin for running GitLab CI pipelines via [glab](https://gitlab.com/gitlab-org/cli).

## Requirements

- [glab](https://gitlab.com/gitlab-org/cli) CLI installed and authenticated
- [folke/snacks.nvim](https://github.com/folke/snacks.nvim)

## Installation

```lua
-- lazy.nvim
{
  "mirai-toto/glab.nvim",
  keys = {
    { "<leader>glr", function() require("glab").run_pipeline() end, desc = "Run pipeline (glab)" },
    { "<leader>glp", function() require("glab").view_pipeline() end, desc = "Pipeline CI (glab)" },
  },
}
```

## Commands

| Command | Description |
|---------|-------------|
| `:GlabRun` | Open the CI run panel |
| `:GlabView` | Open `glab ci view` in a terminal |

## CI Run Panel

`:GlabRun` opens a vertical split with a form to build and trigger `glab ci run` on the current branch.

```
  key                     type      value
────────────────────────────────────────────────────────
  [my_var            ]    str       my_value
────────────────────────────────────────────────────────
  $ glab ci run -b main --input 'my_var:my_value'

  <a> add  <d> del  <Tab> col  <i> edit  <r> run  <q> quit
```

### Keys

| Key | Action |
|-----|--------|
| `i` | Edit the focused field |
| `<Tab>` / `<S-Tab>` | Move between columns |
| `j` / `k` | Move between rows |
| `a` | Add a row |
| `d` | Delete the current row |
| `r` | Run the pipeline |
| `q` / `<Esc>` | Close the panel |

When the cursor is on the **type** column, `i` cycles through: `str → int → flt → bool → arr`.

## Input Autofill

Place a `.glab-inputs.json` file at the root of your git repository to pre-populate the form on open:

```json
{
  "my_var": "default_value",
  "another_var": "123"
}
```

All values are loaded as `string` type. You can change the type in the panel after loading.
