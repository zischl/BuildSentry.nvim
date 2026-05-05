local BuildSentry = {}
BuildSentry.state = {}
BuildSentry.tasks = {}

local function set_keymap()
	local task_buf = BuildSentry.state.task_buf

	local opts = { buffer = task_buf, silent = true }

	vim.keymap.set("n", "q", function()
		local state = BuildSentry.state
		if state.task_window and vim.api.nvim_win_is_valid(state.task_window) then
			vim.api.nvim_win_close(state.task_window, true)
		end
		if state.output_window and vim.api.nvim_win_is_valid(state.output_window) then
			vim.api.nvim_win_close(state.output_window, true)
		end
		if state.guide_win and vim.api.nvim_win_is_valid(state.guide_win) then
			vim.api.nvim_win_close(state.guide_win, true)
		end
	end, opts)

	vim.keymap.set("n", "x", function()
		local line = vim.api.nvim_win_get_cursor(0)[1]
		local task = BuildSentry.tasks[line]
		if task and task.job_id then
			vim.fn.jobstop(task.job_id)
			print("Terminated: " .. task.name)
		end
	end, opts)

	vim.keymap.set("n", "r", function()
		print("Restarting Task")
	end, opts)
end

function BuildSentry.open()
	local task_buf = vim.api.nvim_create_buf(false, true)
	local output_buf = vim.api.nvim_create_buf(false, true)

	local stats = vim.api.nvim_list_uis()[1]
	local width = stats.width
	local height = stats.height

	local win_height = math.ceil(height * 0.8)
	local win_width = math.ceil(width * 0.8)
	local row = math.ceil((height - win_height) / 2)
	local col = math.ceil((width - win_width) / 2)

	local guide_height = math.ceil(win_height * 0.1)
	local task_height = win_height - guide_height - 2

	local task_window = vim.api.nvim_open_win(task_buf, true, {
		relative = "editor",
		row = row,
		col = col,
		width = math.ceil(win_width * 0.3),
		height = task_height,
		style = "minimal",
		title = " Tasks ",
		title_pos = "center",
		border = "rounded",
	})

	local guide_buf = vim.api.nvim_create_buf(false, true)

	vim.api.nvim_buf_set_lines(guide_buf, 0, -1, false, { " q:quit  x:kill  r:restart " })

	local guide_win = vim.api.nvim_open_win(guide_buf, false, {
		relative = "editor",
		row = row + task_height + 2,
		col = col,
		width = math.ceil(win_width * 0.3),
		height = guide_height,
		style = "minimal",
		border = "rounded",
	})

	local output_window = vim.api.nvim_open_win(output_buf, false, {
		relative = "editor",
		row = row,
		col = col + math.ceil(win_width * 0.3) + 2,
		width = math.ceil(win_width * 0.7) - 2,
		height = win_height,
		style = "minimal",
		border = "rounded",
		title = " Output ",
		title_pos = "center",
	})

	BuildSentry.state = {
		task_window = task_window,
		output_window = output_window,
		task_buf = task_buf,
		output_buf = output_buf,
		guide_win = guide_win,
	}

	set_keymap()
end

function BuildSentry.exec(name, cmd, cwd)
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

	table.insert(BuildSentry.tasks, task)
	return task
end

return BuildSentry
