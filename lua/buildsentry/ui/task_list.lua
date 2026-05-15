local M = {}
local state = require("buildsentry.state")

M.ns = vim.api.nvim_create_namespace("buildsentry_tasklist")

function M.generate_task_format(task, selected)
	local selector = selected and "" or " "

	local status_icon = ""
	local status_hl = "DiagnosticInfo"
	if task.status == "OK" then
		status_icon = ""
		status_hl = "DiagnosticOk"
	elseif task.status == "FAIL" then
		status_icon = ""
		status_hl = "DiagnosticError"
	elseif task.status == "TRM" then
		status_icon = ""
		status_hl = "DiagnosticWarn"
	end

	local window = state.windows.task
	local width = 50
	if window and vim.api.nvim_win_is_valid(window) then
		width = vim.api.nvim_win_get_width(window)
	end

	local padded_status = task.status .. string.rep(" ", 4 - #task.status)
	local status_part = string.format(" %s %s %s", selector, status_icon, padded_status)
	local diag_part = string.format(" 󰅚 %d 󰀪 %d ", task.diagnostics.errors, task.diagnostics.warnings)
	local name_part = " " .. task.name

	local status_w = vim.fn.strdisplaywidth(status_part)
	local diag_w = vim.fn.strdisplaywidth(diag_part)
	local name_w = vim.fn.strdisplaywidth(name_part)

	local available_for_name = width - status_w - diag_w
	if name_w > available_for_name then
		local truncated_name = vim.fn.strpart(task.name, 0, math.max(0, available_for_name - 4))
		name_part = " " .. truncated_name .. "..."
		name_w = vim.fn.strdisplaywidth(name_part)
	end

	local padding_len = math.max(0, width - status_w - name_w - diag_w)
	local padding = string.rep(" ", padding_len)

	local line1 = status_part .. name_part .. padding .. diag_part

	local status_start = 1 + #selector + 1
	local status_end = #status_part

	local name_start = status_end
	local name_end = status_end + #name_part

	local diag_start = name_end + #padding
	local diag_end = #line1

	local err_icon_pos = diag_part:find("󰅚")
	local warn_icon_pos = diag_part:find("󰀪")

	local err_icon_start = diag_start + err_icon_pos - 1
	local warn_icon_start = diag_start + warn_icon_pos - 1

	local highlights = {
		{ group = status_hl, start_col = status_start, end_col = status_end },
		{ group = "Title", start_col = name_start, end_col = name_end },
		{ group = "Comment", start_col = diag_start, end_col = diag_end },
		{ group = "DiagnosticError", start_col = err_icon_start, end_col = err_icon_start + #"󰅚" },
		{ group = "DiagnosticWarn", start_col = warn_icon_start, end_col = warn_icon_start + #"󰀪" },
	}

	local prefix = "  out: "
	local prefix_width = vim.fn.strdisplaywidth(prefix)
	local line2 = task.output:gsub("\27%[[0-9;?]*[a-zA-Z]", ""):gsub("^%s+", "")

	local virt_padding = 0
	if window and vim.api.nvim_win_is_valid(window) then
		local available_width = width - prefix_width
		local line2_width = vim.fn.strdisplaywidth(line2)
		virt_padding = available_width - line2_width
		if virt_padding < 0 then
			line2 = vim.fn.strpart(line2, 0, available_width - 3) .. "..."
			virt_padding = 0
		end
	end

	local virt_lines = {}
	local padding_str = virt_padding > 0 and string.rep(" ", virt_padding) or ""

	if selected then
		virt_lines = { { { prefix, "Visual" }, { line2, "Visual" }, { padding_str, "Visual" } } }
	else
		virt_lines = { { { prefix, "Comment" }, { line2, "Directory" }, { padding_str, "" } } }
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

function M.set_output(index)
	index = index or state.active_task_index
	local task = state.tasks[index]
	if not task or not task.bufnr or not vim.api.nvim_buf_is_valid(task.bufnr) then
		return
	end

	local win_out = state.windows.output
	if win_out and vim.api.nvim_win_is_valid(win_out) then
		vim.api.nvim_win_set_buf(win_out, task.bufnr)
		local line_count = vim.api.nvim_buf_line_count(task.bufnr)
		if line_count > 0 then
			vim.api.nvim_win_set_cursor(win_out, { line_count, 0 })
		end
		require("buildsentry.ui").update_guide()
		vim.cmd("redraw")
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

	local removed_idx = nil
	for i, t in ipairs(state.tasks) do
		if t == task then
			removed_idx = i
			table.remove(state.tasks, i)
			break
		end
	end

	if removed_idx then
		if state.active_task_index > #state.tasks then
			state.active_task_index = math.max(1, #state.tasks)
		end
	end

	if #state.tasks > 0 then
		M.set_output()
	else
		require("buildsentry.ui").home()
	end

	if task.bufnr and vim.api.nvim_buf_is_valid(task.bufnr) then
		vim.api.nvim_buf_delete(task.bufnr, { force = true })
	end

	require("buildsentry.ui").refresh()
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
