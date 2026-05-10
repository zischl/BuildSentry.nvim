local M = {}

function M.compute_layout()
	local stats = vim.api.nvim_list_uis()[1]
	local width = stats.width
	local height = stats.height

	local win_height = math.ceil(height * 0.8)
	local win_width = math.ceil(width * 0.8)
	local row = math.ceil((height - win_height) / 2)
	local col = math.ceil((width - win_width) / 2)

	local guide_height = math.ceil(win_height * 0.1)
	local task_height = win_height - guide_height - 2
	local task_width = math.ceil(win_width * 0.3)
	local output_width = math.ceil(win_width * 0.7) - 2

	return {
		row = row,
		col = col,
		win_width = win_width,
		win_height = win_height,
		task_height = task_height,
		task_width = task_width,
		guide_height = guide_height,
		output_width = output_width,
	}
end

function M.create_float(buf, opts)
	local win_opts = {
		relative = "editor",
		row = opts.row,
		col = opts.col,
		width = opts.width,
		height = opts.height,
		style = "minimal",
		border = opts.border or "rounded",
	}

	if opts.title then
		win_opts.title = opts.title
		win_opts.title_pos = opts.title_pos or "center"
	end

	return vim.api.nvim_open_win(buf, opts.focus or false, win_opts)
end

return M
