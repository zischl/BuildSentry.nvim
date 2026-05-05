local BuildSentry = {}
BuildSentry.state = {}

local function set_keymap()
	local task_buf = BuildSentry.state.task_buf
	local task_win = BuildSentry.state.task_window
	local output_buf = BuildSentry.state.output_buf
	local output_win = BuildSentry.state.output_window

	local opts = { buffer = task_buf, silent = true }

	vim.keymap.set("n", "q", function()
		local state = BuildSentry.state
		if state.task_window and vim.api.nvim_win_is_valid(state.task_window) then
			vim.api.nvim_win_close(state.task_window, true)
		end
		if state.output_window and vim.api.nvim_win_is_valid(state.output_window) then
			vim.api.nvim_win_close(state.output_window, true)
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

	local task_window = vim.api.nvim_open_win(task_buf, true, {
		relative = "editor",
		row = row,
		col = col,
		width = math.ceil(win_width * 0.3),
		height = win_height,
		style = "minimal",
		border = "rounded",
		title = " Tasks ",
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
	})

	BuildSentry.state = {
		task_window = task_window,
		output_window = output_window,
		task_buf = task_buf,
		output_buf = output_buf,
	}

	set_keymap()
end

return BuildSentry
