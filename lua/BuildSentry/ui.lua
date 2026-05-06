local M = {}
local state = require("BuildSentry.state")

local function set_keymap()
	local task_buf = state.buffers.task
	local opts = { buffer = task_buf, silent = true }

	vim.keymap.set("n", "q", function()
		if state.windows.task and vim.api.nvim_win_is_valid(state.windows.task) then
			vim.api.nvim_win_close(state.windows.task, true)
		end
		if state.windows.output and vim.api.nvim_win_is_valid(state.windows.output) then
			vim.api.nvim_win_close(state.windows.output, true)
		end
		if state.windows.guide and vim.api.nvim_win_is_valid(state.windows.guide) then
			vim.api.nvim_win_close(state.windows.guide, true)
		end
		state.windows = { task = nil, output = nil, guide = nil }
	end, opts)

	vim.keymap.set("n", "x", function()
		local line = vim.api.nvim_win_get_cursor(0)[1]
		local executor = require("BuildSentry.executor")
		executor.stop_task(line)
	end, opts)

	vim.keymap.set("n", "r", function()
		print("Restarting Task... Not implemented yet")
	end, opts)
end

function M.open()
	if not state.buffers.task or not vim.api.nvim_buf_is_valid(state.buffers.task) then
		state.buffers.task = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_name(state.buffers.task, "BuildSentry Tasks")
	end

	if not state.buffers.output or not vim.api.nvim_buf_is_valid(state.buffers.output) then
		state.buffers.output = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_name(state.buffers.output, "BuildSentry Output")
	end

	local stats = vim.api.nvim_list_uis()[1]
	local width = stats.width
	local height = stats.height

	local win_height = math.ceil(height * 0.8)
	local win_width = math.ceil(width * 0.8)
	local row = math.ceil((height - win_height) / 2)
	local col = math.ceil((width - win_width) / 2)

	local guide_height = math.ceil(win_height * 0.1)
	local task_height = win_height - guide_height - 2

	state.windows.task = vim.api.nvim_open_win(state.buffers.task, true, {
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
	vim.api.nvim_buf_set_lines(guide_buf, 0, -1, false, { " q:quit x:kill r:restart " })
	state.buffers.guide = guide_buf

	state.windows.guide = vim.api.nvim_open_win(guide_buf, false, {
		relative = "editor",
		row = row + task_height + 2,
		col = col,
		width = math.ceil(win_width * 0.3),
		height = guide_height,
		style = "minimal",
		border = "rounded",
	})

	local current_output_buf = state.buffers.output
	if #state.tasks > 0 then
		current_output_buf = state.tasks[#state.tasks].bufnr
	end

	state.windows.output = vim.api.nvim_open_win(current_output_buf, false, {
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

	set_keymap()
end

return M
