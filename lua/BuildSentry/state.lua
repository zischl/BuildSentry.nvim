local M = {}

M.tasks = {}
M.windows = {
	task = nil,
	output = nil,
	guide = nil,
}
M.buffers = {
	task = nil,
	output = nil,
	guide = nil,
}
M.active_task_index = 1
M.cursor_row = 0
M.task_ns = nil

return M
