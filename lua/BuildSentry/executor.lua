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
	}

	vim.api.nvim_buf_call(bufnr, function()
		task.job_id = vim.fn.termopen(cmd, {
			cwd = cwd or vim.fn.getcwd(),
			on_exit = function(_, code)
				task.status = code == 0 and "SUCCESS" or "FAILED"
				task.exit_code = code
			end,
		})
	end)

	table.insert(state.tasks, task)

	if state.windows.output and vim.api.nvim_win_is_valid(state.windows.output) then
		print(state.windows.output, task.bufnr)
		vim.api.nvim_win_set_buf(state.windows.output, task.bufnr)
	end

	return task
end

function M.stop_task(task_index)
	local task = state.tasks[task_index]
	if task and task.job_id then
		vim.fn.jobstop(task.job_id)
		task.status = "TERMINATED"
		print("Terminated: " .. task.name)
	end
end

return M
