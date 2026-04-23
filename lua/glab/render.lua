local form = require("glab.form")
local utils = require("glab.utils")

local M = {}

local NS = vim.api.nvim_create_namespace("glab_pipeline_run")

local COL_WIDTHS = { key = 20, type = 8, value = 22 }

-- │ (U+2502) is 3 bytes in UTF-8; extmarks use byte offsets
local COL_SEP       = " │ "
local COL_SEP_BYTES = 5  -- 1 (space) + 3 (│) + 1 (space)

-- Byte offsets for extmarks
local KEY_START   = 2
local KEY_END     = KEY_START + COL_WIDTHS.key      -- 22
local TYPE_START  = KEY_END + COL_SEP_BYTES          -- 27
local TYPE_END    = TYPE_START + COL_WIDTHS.type     -- 35
local VALUE_START = TYPE_END + COL_SEP_BYTES         -- 40
local VALUE_END   = VALUE_START + COL_WIDTHS.value   -- 62

-- Display width: 2 + 20 + 3 + 8 + 3 + 22 = 58, +4 padding
M.WIDTH = 2 + COL_WIDTHS.key + 3 + COL_WIDTHS.type + 3 + COL_WIDTHS.value + 4

local SEPARATOR = string.rep("─", 2 + COL_WIDTHS.key)
  .. "─┼─"
  .. string.rep("─", COL_WIDTHS.type)
  .. "─┼─"
  .. string.rep("─", COL_WIDTHS.value + 2)

local HELP_LINE = "  <a> add  <d> del  <Tab> col  <CR> edit  <r> run  <q> quit"
local HELP_SEGMENTS = {
  { "  ",      "Comment" },
  { "<a>",     "Special" },
  { " add  ",  "Comment" },
  { "<d>",     "Special" },
  { " del  ",  "Comment" },
  { "<Tab>",   "Special" },
  { " col  ",  "Comment" },
  { "<CR>",    "Special" },
  { " edit  ", "Comment" },
  { "<r>",     "Special" },
  { " run  ",  "Comment" },
  { "<q>",     "Special" },
  { " quit",   "Comment" },
}

-- ─── Helpers ─────────────────────────────────────────────────────────────────

local function pad(str, len)
  str = str or ""
  if #str >= len then
    return str:sub(1, len)
  end
  return str .. string.rep(" ", len - #str)
end

local function make_header()
  return "  " .. pad("key", COL_WIDTHS.key) .. COL_SEP .. pad("type", COL_WIDTHS.type) .. COL_SEP .. pad("value", COL_WIDTHS.value)
end

local function make_row_line(row, is_active, cursor_col)
  local key_str = pad(row:display("key"), COL_WIDTHS.key)
  local type_str = pad(row:display("type"), COL_WIDTHS.type)
  local value_str = pad(row:display("value"), COL_WIDTHS.value)

  if is_active then
    if cursor_col == 1 then
      key_str = "[" .. pad(row:display("key"), COL_WIDTHS.key - 2) .. "]"
    end
    if cursor_col == 2 then
      type_str = "[" .. pad(row:display("type"), COL_WIDTHS.type - 2) .. "]"
    end
    if cursor_col == 3 then
      value_str = "[" .. pad(row:display("value"), COL_WIDTHS.value - 2) .. "]"
    end
  end

  return "  " .. key_str .. COL_SEP .. type_str .. COL_SEP .. value_str
end

-- ─── Highlight header ────────────────────────────────────────────────────────

local function highlight_header(buf)
  vim.api.nvim_buf_set_extmark(buf, NS, 0, 0,           { end_col = KEY_START,   hl_group = "Comment" })
  vim.api.nvim_buf_set_extmark(buf, NS, 0, KEY_START,   { end_col = KEY_END,     hl_group = "Identifier" })
  vim.api.nvim_buf_set_extmark(buf, NS, 0, KEY_END,     { end_col = TYPE_START,  hl_group = "Comment" })
  vim.api.nvim_buf_set_extmark(buf, NS, 0, TYPE_START,  { end_col = TYPE_END,    hl_group = "Type" })
  vim.api.nvim_buf_set_extmark(buf, NS, 0, TYPE_END,    { end_col = VALUE_START, hl_group = "Comment" })
  vim.api.nvim_buf_set_extmark(buf, NS, 0, VALUE_START, { end_col = VALUE_END,   hl_group = "String", hl_eol = true })
end

-- ─── Highlight help line ─────────────────────────────────────────────────────

local function highlight_help(buf, line)
  local col = 0
  for _, seg in ipairs(HELP_SEGMENTS) do
    vim.api.nvim_buf_set_extmark(buf, NS, line, col, { end_col = col + #seg[1], hl_group = seg[2] })
    col = col + #seg[1]
  end
end

-- ─── Highlight one data row ──────────────────────────────────────────────────

local function highlight_row(buf, line, row, is_active, cursor_col)
  local hl_key   = is_active and cursor_col == 1 and "CursorLine" or "Identifier"
  local hl_type  = is_active and cursor_col == 2 and "CursorLine" or row.type.hl
  local hl_value = is_active and cursor_col == 3 and "CursorLine" or "String"

  vim.api.nvim_buf_set_extmark(buf, NS, line, KEY_START,   { end_col = KEY_END,   hl_group = hl_key })
  vim.api.nvim_buf_set_extmark(buf, NS, line, KEY_END,     { end_col = TYPE_START, hl_group = "Comment" })
  vim.api.nvim_buf_set_extmark(buf, NS, line, TYPE_START,  { end_col = TYPE_END,  hl_group = hl_type })
  vim.api.nvim_buf_set_extmark(buf, NS, line, TYPE_END,    { end_col = VALUE_START, hl_group = "Comment" })
  vim.api.nvim_buf_set_extmark(buf, NS, line, VALUE_START, { end_col = VALUE_END, hl_group = hl_value })
end

-- ─── Main render ─────────────────────────────────────────────────────────────

M.render = function()
  local S = form.STATE
  if not vim.api.nvim_buf_is_valid(S.buf) then
    return
  end

  vim.bo[S.buf].modifiable = true
  vim.api.nvim_buf_clear_namespace(S.buf, NS, 0, -1)

  local lines = {}

  table.insert(lines, make_header())
  table.insert(lines, SEPARATOR)

  for i, row in ipairs(S.rows) do
    table.insert(lines, make_row_line(row, S.cursor.row == i, S.cursor.col))
  end

  table.insert(lines, SEPARATOR)
  table.insert(lines, "  $ " .. utils.build_cmd(S.branch, S.rows))
  table.insert(lines, "")
  table.insert(lines, HELP_LINE)

  vim.api.nvim_buf_set_lines(S.buf, 0, -1, false, lines)

  -- Header + separators
  highlight_header(S.buf)
  vim.api.nvim_buf_set_extmark(S.buf, NS, 1, 0, { end_row = 1, hl_group = "Comment", hl_eol = true })

  -- Data rows
  for i, row in ipairs(S.rows) do
    highlight_row(S.buf, i + 1, row, S.cursor.row == i, S.cursor.col)
  end

  -- Bottom
  local sep_line = #S.rows + 2
  vim.api.nvim_buf_set_extmark(S.buf, NS, sep_line, 0, { end_row = sep_line, hl_group = "Comment", hl_eol = true })
  vim.api.nvim_buf_set_extmark(
    S.buf,
    NS,
    sep_line + 1,
    0,
    { end_row = sep_line + 1, hl_group = "Special", hl_eol = true }
  )
  vim.api.nvim_buf_set_extmark(
    S.buf,
    NS,
    sep_line + 3,
    0,
    { end_row = sep_line + 3, hl_group = "Comment", hl_eol = true }
  )
  highlight_help(S.buf, sep_line + 3)

  vim.bo[S.buf].modifiable = false

  if vim.api.nvim_win_is_valid(S.win) then
    local col_offsets = { KEY_START, TYPE_START, VALUE_START }
    vim.api.nvim_win_set_cursor(S.win, { S.cursor.row + 2, col_offsets[S.cursor.col] })
  end
end

return M