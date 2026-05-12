local state = require("buildsentry.state")
local M = {}

local prev_hash = ""
local ns = vim.api.nvim_create_namespace("buildsentry_guide")

local buffer_mappings = setmetatable({}, {
	__index = function(t, key)
		t[key] = {}
		return t[key]
	end,
})

---@param bufnr number
local function unmap_buffer_keys(bufnr)
	if not buffer_mappings[bufnr] then
		return
	end

	for _, map in ipairs(buffer_mappings[bufnr]) do
		pcall(vim.keymap.del, map.mode, map.key, { buffer = bufnr })
	end
	buffer_mappings[bufnr] = {}
end

---@param actions table[]
---@param bufnr number
function M.set(actions, bufnr)
	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	unmap_buffer_keys(bufnr)

	local task = state.get_active_task()
	local idx = state.active_task_index
	local active_actions = {}

	for _, action in ipairs(actions) do
		if not action.enabled or action.enabled(task) then
			table.insert(active_actions, action)

			local mode = action.mode or "n"
			vim.keymap.set(mode, action.key, function()
				action.fn(task, idx)
			end, { buffer = bufnr, silent = true, nowait = true })

			table.insert(buffer_mappings[bufnr], { mode = mode, key = action.key })
		end
	end

	M.render(active_actions)
end

function M.generate_guide_format(actions, width)
	local rows = {}
	local row_highlights = {}

	local current_row_text = "  "
	local current_row_hls = {}

	for _, a in ipairs(actions) do
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
	table.insert(rows, current_row_text)
	table.insert(row_highlights, current_row_hls)

	return rows, row_highlights
end

function M.render(actions)
	local labels = {}
	for _, a in ipairs(actions) do
		table.insert(labels, a.label)
	end

	local width = 40
	local window = state.windows.guide
	if window and vim.api.nvim_win_is_valid(window) then
		width = vim.api.nvim_win_get_width(window)
	end

	local current_hash = table.concat(labels, "|") .. "|" .. tostring(width)
	if current_hash == prev_hash then
		return
	end
	prev_hash = current_hash

	local guide_map_lines, guide_map_hl = M.generate_guide_format(actions, width)

	if state.buffers.guide and vim.api.nvim_buf_is_valid(state.buffers.guide) then
		vim.api.nvim_buf_set_lines(state.buffers.guide, 0, -1, false, guide_map_lines)
		vim.api.nvim_buf_clear_namespace(state.buffers.guide, ns, 0, -1)

		for i, hls in ipairs(guide_map_hl) do
			for _, hl in ipairs(hls) do
				vim.api.nvim_buf_add_highlight(state.buffers.guide, ns, hl.group, i - 1, hl.start_col, hl.end_col)
			end
		end
	end
end

function M.cleanup(bufnr)
	if bufnr then
		unmap_buffer_keys(bufnr)
	else
		for b, _ in pairs(buffer_mappings) do
			unmap_buffer_keys(b)
		end
	end
end

return M
