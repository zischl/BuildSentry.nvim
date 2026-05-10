local M = {}

local prev_hash = ""
M.key_maps = {}

function M.reset()
	M.key_maps = {}
	M.refresh()
end

---@param input table
function M.add(input)
	if input[1] and type(input[1]) == "table" then
		for _, set in ipairs(input) do
			table.insert(M.key_maps, set)
		end
	else
		table.insert(M.key_maps, input)
	end
	M.refresh()
end

---@param input table
function M.remove(input)
	local function remove_one(target)
		for i, set in ipairs(M.key_maps) do
			if set == target then
				table.remove(M.key_maps, i)
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
	local labels = {}
	for _, a in ipairs(M.key_maps) do
		table.insert(labels, a.label)
	end
	local current_hash = table.concat(labels, "|")

	if current_hash == prev_hash then
		return
	end
	prev_hash = current_hash

	local state = require("buildsentry.state")

	local text = "  " .. table.concat(labels, "   ") .. "  "
	if state.buffers.guide and vim.api.nvim_buf_is_valid(state.buffers.guide) then
		vim.api.nvim_buf_set_lines(state.buffers.guide, 0, -1, false, { text })
	end

	if state.buffers.task and vim.api.nvim_buf_is_valid(state.buffers.task) then
		for _, a in ipairs(M.key_maps) do
			vim.keymap.set("n", a.key, function()
				local task = state.get_active_task()
				local idx = state.active_task_index
				a.fn(task, idx)
			end, { buffer = state.buffers.task, silent = true, nowait = true })
		end
	end
end

return M
