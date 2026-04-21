vim.api.nvim_create_user_command("GlabRun", function()
  require("glab").run_pipeline()
end, { desc = "Open glab ci run panel" })

vim.api.nvim_create_user_command("GlabView", function()
  require("glab").view_pipeline()
end, { desc = "Open glab ci view in terminal" })