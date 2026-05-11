local M = {}
local executor = require("buildsentry.executor")

M.global = {
	{
		key = "q",
		label = "q:quit",
		enabled = true,
		fn = function()
			require("buildsentry.ui").close()
		end,
	},
	{
		key = "h",
		label = "h:home",
		enabled = true,
		get_state = function()
			local state = require("buildsentry.state")
			if not state.windows.output or not vim.api.nvim_win_is_valid(state.windows.output) then
				return false
			end
			local current_buf = vim.api.nvim_win_get_buf(state.windows.output)
			return current_buf ~= state.buffers.output
		end,
		fn = function()
			require("buildsentry.ui").home()
		end,
	},
}

M.task_list = {
	{
		key = "x",
		label = "x:kill",
		enabled = true,
		get_state = function(task)
			return task and task.status == "RUNNING"
		end,
		fn = function(_, idx)
			executor.stop_task(idx)
		end,
	},
	{
		key = "r",
		label = "r:restart",
		enabled = true,
		fn = function(_, idx)
			executor.restart_task(idx)
		end,
	},
	{
		key = "e",
		label = "e:goto error",
		enabled = false,
		get_state = function(task)
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

	{
		key = "d",
		label = "d:delete",
		enabled = true,
		fn = function(task)
			if task then
				task:stop()
				require("buildsentry.ui.task_list").remove(task)
				require("buildsentry.ui").refresh()
			end
		end,
	},

	{
		key = "C",
		label = "C:clear completed",
		enabled = true,
		fn = function()
			local state = require("buildsentry.state")
			local task_list = require("buildsentry.ui.task_list")
			for i = #state.tasks, 1, -1 do
				local t = state.tasks[i]
				if t.status ~= "RUNNING" then
					task_list.remove(t)
				end
			end
			require("buildsentry.ui").refresh()
		end,
	},

	{
		key = "c",
		label = "c:copy cmd",
		enabled = true,
		fn = function(task)
			if task and task.cmd then
				vim.fn.setreg("+", task.cmd)
				vim.notify("Copied command to clipboard")
			end
		end,
	},
	{
		key = "o",
		label = "o:output",
		enabled = true,
		get_state = function()
			local state = require("buildsentry.state")
			if not state.windows.output or not vim.api.nvim_win_is_valid(state.windows.output) then
				return false
			end
			local current_buf = vim.api.nvim_win_get_buf(state.windows.output)
			return current_buf == state.buffers.output
		end,
		fn = function()
			require("buildsentry.ui.task_list").set_output()
		end,
	},
}

return M
