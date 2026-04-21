local utils = require("glab.utils")
local form = require("glab.form")
local render = require("glab.render")

local M = {}

-- ─── Actions ─────────────────────────────────────────────────────────────────

local function close()
  if form.STATE.win and vim.api.nvim_win_is_valid(form.STATE.win) then
    vim.api.nvim_win_close(form.STATE.win, true)
  end
  form.STATE.win = nil
  form.STATE.buf = nil
end

local function run_pipeline()
  local cmd = utils.build_cmd(form.STATE.branch, form.STATE.rows)
  close()
  Snacks.terminal(cmd)
end

local function edit_current()
  local row = form.current_row()
  local field = form.col_name(form.STATE.cursor.col)
  if not row or not field then
    return
  end

  if form.col_type(form.STATE.cursor.col) == "TYPE" then
    form.cycle_type()
    render.render()
    return
  end

  Snacks.input({
    prompt = string.format("%s › %s: ", field, row.key ~= "" and row.key or "new"),
    default = row[field],
  }, function(val)
    form.set_field(val)
    render.render()
  end)
end

-- ─── Keymaps ─────────────────────────────────────────────────────────────────

local function set_keymaps()
  local map = function(key, fn)
    vim.keymap.set("n", key, fn, { buffer = form.STATE.buf, nowait = true, silent = true })
  end

  map("q", close)
  map("<Esc>", close)
  map("r", run_pipeline)
  map("<CR>", edit_current)

  map("a", function()
    form.add_row()
    render.render()
  end)

  map("d", function()
    form.delete_row()
    render.render()
  end)

  map("<Tab>", function()
    form.move_cursor(1)
    render.render()
  end)

  map("<S-Tab>", function()
    form.move_cursor(-1)
    render.render()
  end)

  map("j", function()
    form.move_row(1)
    render.render()
  end)

  map("k", function()
    form.move_row(-1)
    render.render()
  end)
end

-- ─── Open ────────────────────────────────────────────────────────────────────

M.open = function()
  local branch = utils.current_branch()
  if not branch then
    vim.notify("[glab] Not in a git repository", vim.log.levels.ERROR)
    return
  end

  local prefill = utils.load_inputs_json()
  form.reset(branch, prefill)

  form.STATE.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[form.STATE.buf].bufhidden = "wipe"
  vim.bo[form.STATE.buf].filetype = "glab_pipeline"

  vim.cmd("rightbelow vsplit")
  form.STATE.win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(form.STATE.win, form.STATE.buf)
  vim.api.nvim_win_set_width(form.STATE.win, render.WIDTH)

  vim.wo[form.STATE.win].cursorline = false
  vim.wo[form.STATE.win].wrap = false
  vim.wo[form.STATE.win].number = false
  vim.wo[form.STATE.win].relativenumber = false
  vim.wo[form.STATE.win].signcolumn = "no"

  vim.api.nvim_buf_set_name(form.STATE.buf, string.format("glab://ci-run/%s", branch))

  vim.api.nvim_create_autocmd("WinLeave", {
    buffer = form.STATE.buf,
    once = true,
    callback = close,
  })

  set_keymaps()
  render.render()
end

return M