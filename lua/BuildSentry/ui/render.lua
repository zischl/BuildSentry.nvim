local M = {}

function M.task_list(buf, tasks, active_index)
	local lines = {}
	for i, task in ipairs(tasks) do
		local is_selected = i == active_index
		local selector = is_selected and "" or " "

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

		table.insert(lines, line1)
		table.insert(lines, line2)
	end

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

function M.highlight_active(buf, ns, line)
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

	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	vim.api.nvim_buf_set_extmark(buf, ns, start_line, 0, {
		id = 1,
		end_row = end_row,
		hl_group = "Visual",
		hl_eol = true,
	})
end

return M
