if vim.g.loaded_buildsentry then
	return
end
vim.g.loaded_buildsentry = 1

vim.api.nvim_create_user_command("BuildSentry", function()
	require("buildsentry").open()
end, { desc = "Open BuildSentry UI" })

vim.api.nvim_create_user_command("BuildSentryOpen", function()
	require("buildsentry").open()
end, { desc = "Open BuildSentry UI" })
