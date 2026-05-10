local M = {}
local state = require("buildsentry.state")

M.ns = vim.api.nvim_create_namespace("buildsentry_tasklist")

function M.generate_task_format(task, selected)
	local selector = selected and "" or " "

	local status_icon = ""
	if task.status == "SUCCESS" then
		status_icon = ""
	elseif task.status == "FAILED" then
		status_icon = ""
	elseif task.status == "TERMINATED" then
		status_icon = ""
	end

	local line1 = string.format(" %s %s %s name: %s", selector, status_icon, task.status, task.name)
	local line2 = string.format("   out: %s", task.output:gsub("\27%[[0-9;?]*[a-zA-Z]", ""))

	return { line1, line2 }
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
	vim.api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)

	for i, task in ipairs(state.tasks) do
		local selected = i == state.active_task_index
		local t_lines = M.generate_task_format(task, selected)
		table.insert(lines, t_lines[1])
		table.insert(lines, t_lines[2])
	end

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	for i, task in ipairs(state.tasks) do
		task.extmark_id = vim.api.nvim_buf_set_extmark(buf, M.ns, (i - 1) * 2, 0, {
			id = task.extmark_id,
		})
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

	local lines = M.generate_task_format(task, true)
	vim.api.nvim_buf_set_lines(buf, 0, 0, false, lines)

	task.extmark_id = vim.api.nvim_buf_set_extmark(buf, M.ns, 0, 0, {})

	local win = state.windows.task
	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_set_cursor(win, { 1, 0 })
	end

	M.highlight(1)
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
	local task_index = math.floor(task_line / 2) + 1
	local selected = task_index == state.active_task_index

	local lines = M.generate_task_format(task, selected)
	vim.api.nvim_buf_set_lines(buf, task_line, task_line + 2, false, lines)

	task.extmark_id = vim.api.nvim_buf_set_extmark(buf, M.ns, task_line, 0, {
		id = task.extmark_id,
	})
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
	vim.api.nvim_buf_set_lines(buf, task_line, task_line + 2, false, {})
	vim.api.nvim_buf_del_extmark(buf, M.ns, task.extmark_id)

	for i, t in ipairs(state.tasks) do
		if t == task then
			table.remove(state.tasks, i)
			break
		end
	end

	M.refresh()
end

function M.highlight(line)
	local buf = M.get_buf()
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	local line_count = vim.api.nvim_buf_line_count(buf)
	if line_count == 0 then
		return
	end

	local start_line = math.floor((line - 1) / 2) * 2
	if start_line >= line_count then
		start_line = math.max(0, line_count - 2)
	end

	local end_row = start_line + 2
	if end_row > line_count then
		end_row = line_count
	end

	vim.api.nvim_buf_clear_namespace(buf, state.task_ns, 0, -1)
	vim.api.nvim_buf_set_extmark(buf, state.task_ns, start_line, 0, {
		id = 1,
		end_row = end_row,
		hl_group = "Visual",
		hl_eol = true,
	})
end

function M.on_cursor_moved()
	local window = state.windows.task
	if not window or not vim.api.nvim_win_is_valid(window) then
		return
	end

	local cursor_line = vim.api.nvim_win_get_cursor(window)[1]
	state.cursor_row = cursor_line
	M.highlight(cursor_line)

	local active_task_index = math.floor((cursor_line - 1) / 2) + 1
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
