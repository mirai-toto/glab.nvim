local M = {}

local config = {}

M.setup = function(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})
end

M.view_pipeline = function()
  Snacks.terminal("glab ci view")
end

M.run_pipeline = function()
  require("glab.run").open()
end

return M