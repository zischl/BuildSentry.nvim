local M = {}
local state = require("buildsentry.state")
local window = require("buildsentry.ui.window")
local render = require("buildsentry.ui.render")
local guide = require("buildsentry.ui.guide")
local actions = require("buildsentry.ui.actions")

local group = vim.api.nvim_create_augroup("BuildSentryUI", { clear = true })

function M.init()
	state.task_ns = vim.api.nvim_create_namespace("task")
	vim.api.nvim_set_hl(0, "BuildSentrySuccess", { fg = "#b8bb26", bold = true })
	vim.api.nvim_set_hl(0, "BuildSentryFailed", { fg = "#fb4934", bold = true })
	vim.api.nvim_set_hl(0, "BuildSentryRunning", { fg = "#fabd2f", bold = true })
	vim.api.nvim_set_hl(0, "BuildSentryTerminated", { fg = "#928374", bold = true })
end

function M.highlight_active_task(line)
	if not state.buffers.task or not vim.api.nvim_buf_is_valid(state.buffers.task) then
		return
	end
	render.highlight_active(state.buffers.task, state.task_ns, line)
end

function M.close()
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
end

function M.update_guide()
	local active_task = state.get_active_task()
	local active_actions = {}

	local sets = { actions.global, actions.task_list }
	for _, set in ipairs(sets) do
		for _, action in ipairs(set) do
			if not action.enabled or action.enabled(active_task) then
				table.insert(active_actions, action)
			end
		end
	end

	guide.reset()
	guide.add(active_actions)
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

		M.update_guide()
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
end

function M.refresh()
	if not state.buffers.task or not vim.api.nvim_buf_is_valid(state.buffers.task) then
		return
	end
	render.task_list(state.buffers.task, state.tasks, state.active_task_index)
	M.update_guide()
end

return M
