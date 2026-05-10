local M = {}
local state = require("buildsentry.state")
local Task = require("buildsentry.task")

function M.exec(name, cmd, cwd)
	local task = Task.new(name, cmd, cwd)
	task:start()

	table.insert(state.tasks, task)

	if state.windows.output and vim.api.nvim_win_is_valid(state.windows.output) then
		vim.api.nvim_win_set_buf(state.windows.output, task.bufnr)
	end

	local ui_ok, ui = pcall(require, "buildsentry.ui")
	if ui_ok then
		ui.refresh()
		ui.highlight_active_task(1)
	end

	return task
end

function M.stop_task(task_index)
	local task = state.tasks[task_index]
	if task then
		task:stop()
		local ui_ok, ui = pcall(require, "buildsentry.ui")
		if ui_ok then
			ui.refresh()
		end
	end
end

function M.restart_task(task_index)
	local task = state.tasks[task_index]
	if task then
		task:restart()
		local ui_ok, ui = pcall(require, "buildsentry.ui")
		if ui_ok then
			ui.refresh()
		end
	end
end

return M
