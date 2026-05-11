local M = {}

local prev_hash = ""
M.key_maps = {}
local ns = vim.api.nvim_create_namespace("buildsentry_guide")

function M.reset()
	M.key_maps = {}
	M.refresh()
end

---@param input table
function M.add(input)
	if input[1] and type(input[1]) == "table" then
		for _, set in ipairs(input) do
			set.enabled = true
			table.insert(M.key_maps, set)
		end
	else
		input.enabled = true
		table.insert(M.key_maps, input)
	end
	M.refresh()
end

function M.set(input)
	M.key_maps = {}
	M.add(input)
end

---@param input table
function M.remove(input)
	local function remove_one(target)
		for _, set in ipairs(M.key_maps) do
			if set == target then
				set.enabled = false
				return true
			end
		end
		return false
	end

	if input[1] and type(input[1]) == "table" then
		for _, set in ipairs(input) do
			remove_one(set)
		end
	else
		remove_one(input)
	end
	M.refresh()
end

function M.refresh()
	local state = require("buildsentry.state")
	local labels = {}
	for _, a in ipairs(M.key_maps) do
		if a.enabled ~= false then
			table.insert(labels, a.label)
		end
	end

	local window = state.windows.guide
	local width = 40
	if window and vim.api.nvim_win_is_valid(window) then
		width = vim.api.nvim_win_get_width(window)
	end

	local current_hash = table.concat(labels, "|") .. "|" .. tostring(width)
	if current_hash == prev_hash then
		return
	end
	prev_hash = current_hash

	local rows = {}
	local row_highlights = {}

	local current_row_text = "  "
	local current_row_hls = {}

	for _, a in ipairs(M.key_maps) do
		if a.enabled ~= false then
			local label = a.label
			local key_part = label:match("^(.-):") or a.key

			if #current_row_text + #label + 3 > width and current_row_text ~= "  " then
				table.insert(rows, current_row_text)
				table.insert(row_highlights, current_row_hls)
				current_row_text = "  "
				current_row_hls = {}
			end

			local start_col = #current_row_text
			local key_end_col = start_col + #key_part

			table.insert(current_row_hls, { start_col = start_col, end_col = key_end_col, group = "DiagnosticInfo" })

			current_row_text = current_row_text .. label .. "   "
		end
	end
	table.insert(rows, current_row_text)
	table.insert(row_highlights, current_row_hls)

	if state.buffers.guide and vim.api.nvim_buf_is_valid(state.buffers.guide) then
		vim.api.nvim_buf_set_lines(state.buffers.guide, 0, -1, false, rows)
		vim.api.nvim_buf_clear_namespace(state.buffers.guide, ns, 0, -1)

		for i, hls in ipairs(row_highlights) do
			for _, hl in ipairs(hls) do
				vim.api.nvim_buf_add_highlight(state.buffers.guide, ns, hl.group, i - 1, hl.start_col, hl.end_col)
			end
		end
	end

	if state.buffers.task and vim.api.nvim_buf_is_valid(state.buffers.task) then
		for _, a in ipairs(M.key_maps) do
			if a.enabled == false then
				pcall(vim.keymap.del, "n", a.key, { buffer = state.buffers.task })
			else
				vim.keymap.set("n", a.key, function()
					local task = state.get_active_task()
					local idx = state.active_task_index
					a.fn(task, idx)
				end, { buffer = state.buffers.task, silent = true, nowait = true })
			end
		end
	end
end

return M
