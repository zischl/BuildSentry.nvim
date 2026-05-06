local M = {}

M.tasks = {}

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

	task.job_id = vim.fn.jobstart(cmd, {
		cwd = cwd or vim.fn.getcwd(),
		term = true,
		on_stdout = function(_, data) end,
		on_exit = function(_, code)
			task.status = code == 0 and "SUCCESS" or "FAILED"
			task.exit_code = code
			print(string.format("BuildSentry: %s finished (%d)", name, code))
			vim.api.nvim_buf_set_option(task.bufnr, "modifiable", true)
		end,
	})

	table.insert(M.tasks, task)
	return task
end

function M.stop_task(task_index)
	local task = M.tasks[task_index]
	if task and task.job_id then
		vim.fn.jobstop(task.job_id)
		print("Terminated: " .. task.name)
	end
end

return M
