local M = {}
local state = require("BuildSentry.state")

function M.exec(name, cmd, cwd)
	local bufnr = vim.api.nvim_create_buf(false, true)

	local task = {
		name = name,
		cmd = cmd,
		bufnr = bufnr,
		status = "RUNNING",
		exit_code = nil,
		job_id = nil,
		output = nil,
	}

	vim.api.nvim_buf_call(bufnr, function()
		task.job_id = vim.fn.termopen(cmd, {
			cwd = cwd or vim.fn.getcwd(),
			on_exit = function(_, code)
				task.status = code == 0 and "SUCCESS" or "FAILED"
				task.exit_code = code
				vim.schedule(function()
					local ui_ok, ui = pcall(require, "BuildSentry.ui")
					if ui_ok then
						ui.refresh()
					end
				end)
			end,
		})
	end)

	table.insert(state.tasks, task)

	if state.windows.output and vim.api.nvim_win_is_valid(state.windows.output) then
		vim.api.nvim_win_set_buf(state.windows.output, task.bufnr)
	end

	local ui_ok, ui = pcall(require, "BuildSentry.ui")
	if ui_ok then
		ui.refresh()
		ui.highlight_active_task(1)
	end

	return task
end

function M.stop_task(task_index)
	local task = state.tasks[task_index]
	if task and task.job_id then
		vim.fn.jobstop(task.job_id)
		task.status = "TERMINATED"
		print("Terminated: " .. task.name)
		local ui_ok, ui = pcall(require, "BuildSentry.ui")
		if ui_ok then
			ui.refresh()
		end
	end
end

return M
