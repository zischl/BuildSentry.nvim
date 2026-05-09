local M = {}
local state = require("BuildSentry.state")

local group = vim.api.nvim_create_augroup("BuildSentryUI", { clear = true })

function M.init()
	state.task_ns = vim.api.nvim_create_namespace("task")
	state.task_hl_ns = vim.api.nvim_create_namespace("task_hl")
	vim.api.nvim_set_hl(0, "BuildSentryStatus", { bg = "#458588", fg = "#ebdbb2", bold = false })
	vim.api.nvim_set_hl(0, "BuildSentrySuccess", { fg = "#b8bb26", bold = true })
	vim.api.nvim_set_hl(0, "BuildSentryFailed", { fg = "#fb4934", bold = true })
	vim.api.nvim_set_hl(0, "BuildSentryRunning", { fg = "#fabd2f", bold = true })
	vim.api.nvim_set_hl(0, "BuildSentryTerminated", { fg = "#928374", bold = true })
end

function M.highlight_active_task(line)
	local start_line = math.floor((line - 1) / 2) * 2

	local task_buf = state.buffers.task
	if not task_buf or not vim.api.nvim_buf_is_valid(task_buf) then
		return
	end

	vim.api.nvim_buf_clear_namespace(task_buf, state.task_ns, 0, -1)

	vim.api.nvim_buf_set_extmark(task_buf, state.task_ns, start_line, 0, {
		id = 1,
		end_row = start_line + 2,
		hl_group = "Visual",
		hl_eol = true,
	})
end

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
		local task_index = math.ceil(line / 2)
		local executor = require("BuildSentry.executor")
		executor.stop_task(task_index)
	end, opts)

	vim.keymap.set("n", "r", function()
		print("Restarting Task... Not implemented yet")
	end, opts)
end

function M.open()
	if not state.buffers.task or not vim.api.nvim_buf_is_valid(state.buffers.task) then
		state.buffers.task = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_name(state.buffers.task, "BuildSentry Tasks")

		vim.api.nvim_create_autocmd("CursorMoved", {
			group = group,
			buffer = state.buffers.task,
			callback = function()
				state.cursor_row = vim.api.nvim_win_get_cursor(0)[1]
				M.highlight_active_task(state.cursor_row)

				local active_task_index = math.floor((state.cursor_row - 1) / 2) + 1

				if active_task_index < 1 then
					active_task_index = 1
				end
				if #state.tasks > 0 and active_task_index > #state.tasks then
					active_task_index = #state.tasks
				end

				if state.active_task_index == active_task_index then
					return
				end

				state.active_task_index = active_task_index
				M.refresh()

				if state.windows.output and vim.api.nvim_win_is_valid(state.windows.output) then
					local task = state.tasks[active_task_index]
					if task and task.bufnr and vim.api.nvim_buf_is_valid(task.bufnr) then
						vim.schedule(function()
							if vim.api.nvim_win_is_valid(state.windows.output) then
								vim.api.nvim_win_set_buf(state.windows.output, task.bufnr)

								local line_count = vim.api.nvim_buf_line_count(task.bufnr)
								if line_count > 0 then
									vim.api.nvim_win_set_cursor(state.windows.output, { line_count, 0 })
								end

								vim.cmd("redraw")
							end
						end)
					end
				end
			end,
		})

		set_keymap()
	end

	if not state.buffers.output or not vim.api.nvim_buf_is_valid(state.buffers.output) then
		state.buffers.output = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_name(state.buffers.output, "BuildSentry Output")
	end

	if state.windows.output and vim.api.nvim_win_is_valid(state.windows.output) then
		vim.api.nvim_win_close(state.windows.output, true)
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
		local idx = state.active_task_index or 1
		if idx > #state.tasks then
			idx = #state.tasks
		end
		if state.tasks[idx] and state.tasks[idx].bufnr then
			current_output_buf = state.tasks[idx].bufnr
		end
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

	M.refresh()
end

function M.refresh()
	if not state.buffers.task or not vim.api.nvim_buf_is_valid(state.buffers.task) then
		return
	end

	local lines = {}
	local highlights = {}

	for i, task in ipairs(state.tasks) do
		local is_selected = i == state.active_task_index
		local selector = is_selected and "" or " "

		local status_icon = ""
		local hl_group = "BuildSentryRunning"

		if task.status == "SUCCESS" then
			status_icon = ""
			hl_group = "BuildSentrySuccess"
		elseif task.status == "FAILED" then
			status_icon = ""
			hl_group = "BuildSentryFailed"
		elseif task.status == "TERMINATED" then
			status_icon = ""
			hl_group = "BuildSentryTerminated"
		end

		local line1 = string.format(" %s %s %s name: %s", selector, status_icon, task.status, task.name)
		local line2 = string.format("   out: %s", task.output)

		table.insert(lines, line1)
		table.insert(lines, line2)
	end

	vim.api.nvim_buf_set_lines(state.buffers.task, 0, -1, false, lines)
end

return M
