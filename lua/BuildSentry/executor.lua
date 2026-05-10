local M = {}
local state = require("buildsentry.state")
local Task = require("buildsentry.task")

function M.exec(name, cmd, cwd)
	local task = Task.new(name, cmd, cwd)
	task:start()

	local ui_ok, ui = pcall(require, "buildsentry.ui")
	if ui_ok then
		ui.task_list.add(task)
	else
		table.insert(state.tasks, 1, task)
	end

	if state.windows.output and vim.api.nvim_win_is_valid(state.windows.output) then
		vim.api.nvim_win_set_buf(state.windows.output, task.bufnr)
	end

	return task
end

function M.stop_task(task_index)
	local task = state.tasks[task_index]
	if task then
		task:stop()
		local ui_ok, ui = pcall(require, "buildsentry.ui")
		if ui_ok then
			ui.task_list.update(task)
			ui.update_guide()
		end
	end
end

function M.restart_task(task_index)
	local task = state.tasks[task_index]
	if task then
		task:restart()
		local ui_ok, ui = pcall(require, "buildsentry.ui")
		if ui_ok then
			ui.task_list.update(task)
			ui.update_guide()
		end
	end
end

return M
