local M = {}
local state = require("buildsentry.state")

M.ns = vim.api.nvim_create_namespace("buildsentry_tasklist")

function M.generate_task_format(task, selected)
	local selector = selected and "" or " "

	local status_icon = ""
	local status_hl = "DiagnosticInfo"
	if task.status == "SUCCESS" then
		status_icon = ""
		status_hl = "DiagnosticOk"
	elseif task.status == "FAILED" then
		status_icon = ""
		status_hl = "DiagnosticError"
	elseif task.status == "TERMINATED" then
		status_icon = ""
		status_hl = "DiagnosticWarn"
	end

	local line1 = string.format(" %s %s %s Task: %s", selector, status_icon, task.status, task.name)

	local prefix = "  out: "
	local prefix_width = vim.fn.strdisplaywidth(prefix)
	local line2 = task.output:gsub("\27%[[0-9;?]*[a-zA-Z]", ""):gsub("^%s+", "")

	local window = state.windows.task
	local padding = 0
	if window and vim.api.nvim_win_is_valid(window) then
		local width = vim.api.nvim_win_get_width(window)
		local available_width = width - prefix_width
		local line2_width = vim.fn.strdisplaywidth(line2)
		padding = available_width - line2_width
		if padding < 0 then
			line2 = vim.fn.strpart(line2, 0, available_width - 3) .. "..."
			padding = 0
		end
	end

	local status_start = 1 + #selector + 1
	local status_end = status_start + #status_icon + 1 + #task.status
	local name_start = status_end + 7

	local highlights = {
		{ group = status_hl, start_col = status_start, end_col = status_end },
		{ group = "Comment", start_col = status_end, end_col = name_start },
		{ group = "Title", start_col = name_start, end_col = -1 },
	}

	local virt_lines = {}
	local padding_str = padding > 0 and string.rep(" ", padding) or ""

	if selected then
		virt_lines = { { { prefix, "Visual" }, { line2, "Visual" }, { padding_str, "Visual" } } }
	else
		virt_lines = { { { prefix, "Comment" }, { line2, "Directory" }, { padding_str, "Normal" } } }
	end

	return {
		line1 = line1,
		line2 = line2,
		virt_lines = virt_lines,
		highlights = highlights,
	}
end

function M.get_buf()
	return state.buffers.task
end

function M.refresh()
	local buf = M.get_buf()
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	local lines = {}
	local task_formats = {}
	vim.api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)

	for i, task in ipairs(state.tasks) do
		local selected = i == state.active_task_index
		local tf = M.generate_task_format(task, selected)
		table.insert(lines, tf.line1)
		table.insert(task_formats, tf)
	end

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	for i, task in ipairs(state.tasks) do
		local selected = i == state.active_task_index
		local tf = task_formats[i]

		for _, hl in ipairs(tf.highlights) do
			vim.api.nvim_buf_add_highlight(buf, M.ns, hl.group, i - 1, hl.start_col, hl.end_col)
		end

		local opts = {
			id = task.extmark_id,
			virt_lines = tf.virt_lines,
		}
		if selected then
			opts.line_hl_group = "Visual"
		end

		task.extmark_id = vim.api.nvim_buf_set_extmark(buf, M.ns, i - 1, 0, opts)
	end
end

function M.add(task)
	local buf = M.get_buf()
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		table.insert(state.tasks, 1, task)
		return
	end

	table.insert(state.tasks, 1, task)
	state.active_task_index = 1

	local tf = M.generate_task_format(task, true)
	vim.api.nvim_buf_set_lines(buf, 0, 0, false, { tf.line1 })

	for _, hl in ipairs(tf.highlights) do
		vim.api.nvim_buf_add_highlight(buf, M.ns, hl.group, 0, hl.start_col, hl.end_col)
	end

	local opts = {
		virt_lines = tf.virt_lines,
		line_hl_group = "Visual",
	}

	task.extmark_id = vim.api.nvim_buf_set_extmark(buf, M.ns, 0, 0, opts)

	local win = state.windows.task
	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_set_cursor(win, { 1, 0 })
	end
end

function M.update(task)
	local buf = M.get_buf()
	if not buf or not vim.api.nvim_buf_is_valid(buf) or not task.extmark_id then
		return
	end

	local mark = vim.api.nvim_buf_get_extmark_by_id(buf, M.ns, task.extmark_id, {})
	if not mark or #mark == 0 then
		return
	end

	local task_line = mark[1]
	local task_index = task_line + 1
	local selected = task_index == state.active_task_index

	local tf = M.generate_task_format(task, selected)

	vim.api.nvim_buf_clear_namespace(buf, M.ns, task_line, task_line + 1)
	vim.api.nvim_buf_set_lines(buf, task_line, task_line + 1, false, { tf.line1 })

	for _, hl in ipairs(tf.highlights) do
		vim.api.nvim_buf_add_highlight(buf, M.ns, hl.group, task_line, hl.start_col, hl.end_col)
	end

	local opts = {
		id = task.extmark_id,
		virt_lines = tf.virt_lines,
	}
	if selected then
		opts.line_hl_group = "Visual"
	end

	task.extmark_id = vim.api.nvim_buf_set_extmark(buf, M.ns, task_line, 0, opts)
end

function M.remove(task)
	local buf = M.get_buf()
	if not buf or not vim.api.nvim_buf_is_valid(buf) or not task.extmark_id then
		return
	end

	local mark = vim.api.nvim_buf_get_extmark_by_id(buf, M.ns, task.extmark_id, {})
	if not mark or #mark == 0 then
		return
	end

	local task_line = mark[1]
	vim.api.nvim_buf_set_lines(buf, task_line, task_line + 1, false, {})
	vim.api.nvim_buf_del_extmark(buf, M.ns, task.extmark_id)

	for i, t in ipairs(state.tasks) do
		if t == task then
			table.remove(state.tasks, i)
			break
		end
	end

	M.refresh()
end

function M.on_cursor_moved()
	local window = state.windows.task
	if not window or not vim.api.nvim_win_is_valid(window) then
		return
	end

	local cursor_line = vim.api.nvim_win_get_cursor(window)[1]

	local active_task_index = cursor_line
	if active_task_index < 1 then
		active_task_index = 1
	end
	if #state.tasks > 0 and active_task_index > #state.tasks then
		active_task_index = #state.tasks
	end

	if state.active_task_index == active_task_index then
		return
	end

	local old_index = state.active_task_index
	state.active_task_index = active_task_index

	if state.tasks[old_index] then
		M.update(state.tasks[old_index])
	end
	if state.tasks[active_task_index] then
		M.update(state.tasks[active_task_index])
	end

	local ui = require("buildsentry.ui")
	if state.windows.output and vim.api.nvim_win_is_valid(state.windows.output) then
		local task = state.tasks[active_task_index]
		if task and task.bufnr and vim.api.nvim_buf_is_valid(task.bufnr) then
			vim.schedule(function()
				if state.windows.output and vim.api.nvim_win_is_valid(state.windows.output) then
					vim.api.nvim_win_set_buf(state.windows.output, task.bufnr)
					local line_count = vim.api.nvim_buf_line_count(task.bufnr)
					if line_count > 0 then
						vim.api.nvim_win_set_cursor(state.windows.output, { line_count, 0 })
					end
					ui.update_guide()
					vim.cmd("redraw")
				end
			end)
		end
	end
end

return M
