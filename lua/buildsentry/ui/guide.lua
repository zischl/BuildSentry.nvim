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
	local lines = {}
	local col_width = math.floor(width / 2)

	for i = 1, #actions, 2 do
		local line_virt = {}
		local a1 = actions[i]
		local a2 = actions[i + 1]

		local function add_col(a)
			local icon = a.icon or "󰄬"
			local desc = a.desc or a.key
			local key = "[" .. a.key .. "]"

			local icon_part = icon .. "  "
			table.insert(line_virt, { "  ", "" })
			table.insert(line_virt, { icon_part, "DiagnosticInfo" })
			table.insert(line_virt, { desc, "Normal" })

			local used = 2 + vim.fn.strdisplaywidth(icon_part) + vim.fn.strdisplaywidth(desc)
			local padding = col_width - used - vim.fn.strdisplaywidth(key) - 2
			if padding > 0 then
				table.insert(line_virt, { string.rep(" ", padding), "" })
			end
			table.insert(line_virt, { key, "DiagnosticWarn" })
			table.insert(line_virt, { "  ", "" })
		end

		add_col(a1)
		if a2 then
			add_col(a2)
		end
		table.insert(lines, line_virt)
	end

	return lines
end

function M.render(actions)
	local labels = {}
	for _, a in ipairs(actions) do
		table.insert(labels, a.key .. (a.desc or ""))
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

	local guide_virt_lines = M.generate_guide_format(actions, width)

	if state.buffers.guide and vim.api.nvim_buf_is_valid(state.buffers.guide) then
		local empty_lines = {}
		for _ = 1, #guide_virt_lines do
			table.insert(empty_lines, "")
		end

		vim.api.nvim_buf_set_lines(state.buffers.guide, 0, -1, false, empty_lines)
		vim.api.nvim_buf_clear_namespace(state.buffers.guide, ns, 0, -1)

		for i, virt_text in ipairs(guide_virt_lines) do
			vim.api.nvim_buf_set_extmark(state.buffers.guide, ns, i - 1, 0, {
				virt_text = virt_text,
				virt_text_pos = "overlay",
			})
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
