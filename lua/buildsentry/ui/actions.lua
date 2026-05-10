local M = {}
local executor = require("buildsentry.executor")

M.global = {
	{
		key = "q",
		label = "q:quit",
		fn = function()
			require("buildsentry.ui").close()
		end,
	},
}

M.task_list = {
	{
		key = "x",
		label = "x:kill",
		fn = function(_, idx)
			executor.stop_task(idx)
		end,
	},
	{
		key = "r",
		label = "r:restart",
		fn = function(_, idx)
			executor.restart_task(idx)
		end,
	},
	{
		key = "e",
		label = "e:goto error",
		enabled = function(task)
			return task and task.error ~= nil
		end,
		fn = function(task)
			local item = task.error
			require("buildsentry.ui").close()
			if item.bufnr and item.bufnr > 0 and vim.api.nvim_buf_is_valid(item.bufnr) then
				vim.schedule(function()
					vim.cmd("tabnew")

					vim.api.nvim_win_set_buf(0, item.bufnr)

					vim.api.nvim_win_set_cursor(0, { item.lnum, math.max(0, item.col - 1) })
				end)
			end
		end,
	},
}

return M
