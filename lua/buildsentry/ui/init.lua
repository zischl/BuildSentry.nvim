local M = {}
local state = require("buildsentry.state")
local window = require("buildsentry.ui.window")
local guide = require("buildsentry.ui.guide")
local actions = require("buildsentry.ui.actions")

M.task_list = require("buildsentry.ui.task_list")

local group = vim.api.nvim_create_augroup("BuildSentryUI", { clear = true })

function M.init()
	state.task_ns = vim.api.nvim_create_namespace("task")
end

function M.close()
	guide.cleanup()
	vim.api.nvim_clear_autocmds({ group = group })
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
	vim.cmd("redraw")
end

function M.home()
	local task_list = require("buildsentry.ui.task_list")
	local buf_out = state.buffers.output
	local win_out = state.windows.output

	if not buf_out or not win_out or not vim.api.nvim_win_is_valid(win_out) then
		return
	end

	local w_out = vim.api.nvim_win_get_width(win_out)
	local h_out = vim.api.nvim_win_get_height(win_out)

	local logo = {
		"        ██████╗ ██╗   ██╗██╗██╗     ██████╗          ",
		"        ██╔══██╗██║   ██║██║██║     ██╔══██╗         ",
		"        ██████╔╝██║   ██║██║██║     ██║  ██║         ",
		"        ██╔══██╗██║   ██║██║██║     ██║  ██║         ",
		"        ██████╔╝╚██████╔╝██║███████╗██████╔╝         ",
		"         ╚═════╝  ╚═════╝ ╚═╝╚══════╝╚═════╝          ",
		"                                                      ",
		" ███████╗███████╗███╗   ██╗████████╗██████╗ ██╗   ██╗",
		" ██╔════╝██╔════╝████╗  ██║╚══██╔══╝██╔══██╗╚██╗ ██╔╝",
		" ███████╗█████╗  ██╔██╗ ██║   ██║   ██████╔╝ ╚████╔╝ ",
		" ╚════██║██╔══╝  ██║╚██╗██║   ██║   ██╔══██╗  ╚██╔╝  ",
		" ███████║███████╗██║ ╚████║   ██║   ██║  ██║   ██║   ",
		" ╚══════╝╚══════╝╚═╝  ╚═══╝   ╚═╝   ╚═╝  ╚═╝   ╚═╝   ",
	}

	local dashboard_items = {
		{ icon = "󰘳", desc = "Actions", key = "a" },
		{ icon = "󰗼", desc = "Quit", key = "q" },
	}

	vim.api.nvim_buf_set_lines(buf_out, 0, -1, false, {})
	vim.api.nvim_buf_clear_namespace(buf_out, task_list.ns, 0, -1)

	local total_ui_height = #logo + #dashboard_items + 1
	local start_row = math.max(0, math.floor((h_out - total_ui_height) / 2))

	local logo_width = vim.fn.strdisplaywidth(logo[1])
	local left_padding = math.max(0, math.floor((w_out - logo_width) / 2))
	local padding_str = string.rep(" ", left_padding)

	local final_out_lines = {}
	for _ = 1, start_row do
		table.insert(final_out_lines, "")
	end
	for _, line in ipairs(logo) do
		table.insert(final_out_lines, padding_str .. line)
	end
	for _ = 1, #dashboard_items + 1 do
		table.insert(final_out_lines, "")
	end

	vim.api.nvim_buf_set_lines(buf_out, 0, -1, false, final_out_lines)

	for i = 0, #logo - 1 do
		vim.api.nvim_buf_add_highlight(buf_out, task_list.ns, "Title", start_row + i, 0, -1)
	end

	local item_start_row = start_row + #logo + 1
	for i, item in ipairs(dashboard_items) do
		local row = item_start_row + i - 1

		vim.api.nvim_buf_set_extmark(buf_out, task_list.ns, row, 0, {
			virt_text = {
				{ string.rep(" ", left_padding + 4), "" },
				{ item.icon .. "  ", "DiagnosticInfo" },
				{ item.desc, "" },
				{ string.rep(" ", logo_width - #item.desc - 12), "" },
				{ "[" .. item.key .. "]", "DiagnosticWarn" },
			},
			virt_text_pos = "overlay",
		})
	end

	vim.api.nvim_win_set_buf(win_out, buf_out)
	M.update_guide()
end

function M.reset()
	local task_list = require("buildsentry.ui.task_list")
	local buf_task = state.buffers.task
	local win_task = state.windows.task

	if not buf_task or not win_task or not vim.api.nvim_win_is_valid(win_task) then
		return
	end

	local w_task = vim.api.nvim_win_get_width(win_task)
	local h_task = vim.api.nvim_win_get_height(win_task)

	local task_msg = "No tasks available"
	local mid_point = math.floor(h_task / 2)
	local task_lines = {}
	for _ = 1, mid_point do
		table.insert(task_lines, "")
	end

	local task_padding = math.max(0, math.floor((w_task - vim.fn.strdisplaywidth(task_msg)) / 2))
	table.insert(task_lines, string.rep(" ", task_padding) .. task_msg)

	vim.api.nvim_buf_set_lines(buf_task, 0, -1, false, task_lines)
	vim.api.nvim_buf_clear_namespace(buf_task, task_list.ns, 0, -1)
	vim.api.nvim_buf_add_highlight(buf_task, task_list.ns, "Comment", mid_point, 0, -1)

	M.home()
end

function M.update_guide()
	local win = vim.api.nvim_get_current_win()
	local buf = vim.api.nvim_win_get_buf(win)
	local action_sets = {}

	if win == state.windows.task then
		action_sets = { actions.global, actions.task_list }
	elseif win == state.windows.output then
		action_sets = { actions.global, actions.output }
	else
		return
	end

	local all_actions = {}
	for _, set in ipairs(action_sets) do
		for _, action in ipairs(set) do
			table.insert(all_actions, action)
		end
	end

	guide.set(all_actions, buf)
end

function M.focus_output()
	if state.windows.output and vim.api.nvim_win_is_valid(state.windows.output) then
		vim.api.nvim_set_current_win(state.windows.output)
		local buf = vim.api.nvim_win_get_buf(state.windows.output)
		if vim.bo[buf].buftype == "terminal" then
			local task = state.get_active_task()
			if task and task.bufnr == buf and task:is_alive() then
				vim.cmd("startinsert")
			end
		end
		M.update_guide()
	end
end

function M.focus_tasks()
	if state.windows.task and vim.api.nvim_win_is_valid(state.windows.task) then
		vim.api.nvim_set_current_win(state.windows.task)
		M.update_guide()
	end
end

function M.open()
	M.close()

	if not state.buffers.task or not vim.api.nvim_buf_is_valid(state.buffers.task) then
		state.buffers.task = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_name(state.buffers.task, "BuildSentry Tasks")
	end

	if not state.buffers.output or not vim.api.nvim_buf_is_valid(state.buffers.output) then
		state.buffers.output = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_name(state.buffers.output, "BuildSentry Output")
	end

	if state.windows.output and vim.api.nvim_win_is_valid(state.windows.output) then
		vim.api.nvim_win_close(state.windows.output, true)
	end

	local layout = window.compute_layout()

	state.windows.task = window.create_float(state.buffers.task, {
		focus = true,
		row = layout.row,
		col = layout.col,
		width = layout.task_width,
		height = layout.task_height,
		title = " Tasks ",
	})

	if not state.buffers.guide or not vim.api.nvim_buf_is_valid(state.buffers.guide) then
		state.buffers.guide = vim.api.nvim_create_buf(false, true)
	end

	state.windows.guide = window.create_float(state.buffers.guide, {
		row = layout.row + layout.task_height + 2,
		col = layout.col,
		width = layout.task_width,
		height = layout.guide_height,
	})

	local current_output_buf = state.buffers.output
	local active_task = state.get_active_task()
	if active_task and active_task.bufnr and vim.api.nvim_buf_is_valid(active_task.bufnr) then
		current_output_buf = active_task.bufnr
	end

	state.windows.output = window.create_float(current_output_buf, {
		row = layout.row,
		col = layout.col + layout.task_width + 2,
		width = layout.output_width,
		height = layout.win_height,
		title = " Output ",
	})

	M.refresh()

	vim.api.nvim_create_autocmd("WinEnter", {
		group = group,
		callback = function()
			local cur_win = vim.api.nvim_get_current_win()
			if cur_win == state.windows.task or cur_win == state.windows.output then
				M.update_guide()
			end
		end,
	})

	vim.api.nvim_create_autocmd("CursorMoved", {
		group = group,
		buffer = state.buffers.task,
		callback = function()
			M.task_list.on_cursor_moved()
		end,
	})

	vim.api.nvim_create_autocmd("TermEnter", {
		group = group,
		callback = function()
			if vim.api.nvim_get_current_win() == state.windows.output then
				local task = state.get_active_task()
				if task and not task:is_alive() then
					vim.cmd("stopinsert")
				end
			end
		end,
	})

	for _, win in pairs({ state.windows.task, state.windows.output }) do
		if win and vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_create_autocmd("WinClosed", {
				pattern = tostring(win),
				callback = function()
					M.close()
				end,
				once = true,
			})
		end
	end
end

function M.refresh()
	if #state.tasks == 0 then
		M.reset()
	else
		M.task_list.refresh()
		M.update_guide()
	end
end

return M
