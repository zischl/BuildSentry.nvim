local M = {}

---@class Task
---@field name string
---@field cmd string
---@field cwd string
---@field bufnr number
---@field chan number
---@field job_id number|nil
---@field status string
---@field exit_code number|nil
---@field output string
---@field error table|nil
---@field extmark_id number|nil
local Task = {}
Task.__index = Task

local function parse_error(line)
	local qf_result = vim.fn.getqflist({ lines = { line } })
	local item = qf_result.items and qf_result.items[1]

	if item and item.valid == 1 then
		local type_label = (item.type == "W" and "Warning" or "Error")
		local location = ""
		if item.lnum > 0 then
			location = string.format("[%d:%d] ", item.lnum, item.col)
		end
		return string.format("%s: %s%s", type_label, location, item.text), item
	end

	return line:sub(1, 70), nil
end

function Task.new(name, cmd, cwd)
	local bufnr = vim.api.nvim_create_buf(false, true)

	local self = setmetatable({
		name = name,
		cmd = cmd,
		cwd = cwd or vim.fn.getcwd(),
		bufnr = bufnr,
		status = "IDLE",
		exit_code = nil,
		job_id = nil,
		output = "",
		error = nil,
		extmark_id = nil,
	}, Task)

	return self
end

function Task:start()
	if self.job_id then
		self:stop()
	end

	self.status = "RUNNING"
	self.exit_code = nil
	self.error = nil

	local function on_stdout(_, data)
		if not data or (#data == 1 and data[1] == "") then
			return
		end

		for i = #data, 1, -1 do
			local line = data[i]:gsub("\27%[[0-9;?]*[a-zA-Z]", ""):gsub("\r", ""):gsub("%s+$", "")
			if line ~= "" then
				self.output = line
				break
			end
		end

		vim.schedule(function()
			local ui_ok, ui = pcall(require, "buildsentry.ui")
			if ui_ok then
				ui.task_list.update(self)
			end
		end)
	end

	local function on_exit(_, code)
		if self._exited then
			return
		end
		self._exited = true

		local terminated_codes = { [130] = true, [131] = true, [143] = true, [-1073741510] = true }

		local summary, item = parse_error(self.output)
		self.output = summary
		self.error = item

		if self.status ~= "TERMINATED" then
			local terminated = terminated_codes[code] or (self.output and self.output:match("%^C"))

			if terminated then
				self.status = "TERMINATED"
			else
				self.status = code == 0 and "SUCCESS" or "FAILED"
			end
		end
		self.exit_code = code
		self.job_id = nil

		vim.schedule(function()
			local active_buf = vim.api.nvim_get_current_buf()
			if active_buf == self.bufnr and vim.api.nvim_get_mode().mode == "t" then
				vim.cmd("stopinsert")
			end

			local ui_ok, ui = pcall(require, "buildsentry.ui")
			if ui_ok then
				ui.task_list.update(self)
				ui.update_guide()
			end
		end)
	end

	vim.api.nvim_buf_call(self.bufnr, function()
		self.job_id = vim.fn.termopen(self.cmd, {
			cwd = self.cwd,
			on_stdout = on_stdout,
			on_stderr = on_stdout,
			on_exit = on_exit,
		})
	end)

	vim.api.nvim_create_autocmd("TermClose", {
		buffer = self.bufnr,
		once = true,
		callback = function()
			on_exit(nil, vim.v.event.status)
		end,
	})

	return self.job_id
end

function Task:stop()
	if self.job_id then
		self.status = "TERMINATED"
		vim.fn.jobstop(self.job_id)
		self.job_id = nil
	end
end

function Task:restart()
	self:stop()

	local old_buf = self.bufnr
	local new_buf = vim.api.nvim_create_buf(false, true)
	self.bufnr = new_buf
	self._exited = false

	local state = require("buildsentry.state")
	local win = state.windows.output
	if win and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == old_buf then
		vim.api.nvim_win_set_buf(win, new_buf)
	end

	if old_buf and vim.api.nvim_buf_is_valid(old_buf) then
		vim.api.nvim_buf_delete(old_buf, { force = true })
	end

	self:start()
end

function Task:is_alive()
	return self.job_id ~= nil and self.status == "RUNNING"
end

function M.new(name, cmd, cwd)
	return Task.new(name, cmd, cwd)
end

return M
