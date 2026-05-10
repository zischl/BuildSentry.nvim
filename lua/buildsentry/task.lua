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
	local channel = vim.api.nvim_open_term(bufnr, {})

	local self = setmetatable({
		name = name,
		cmd = cmd,
		cwd = cwd or vim.fn.getcwd(),
		bufnr = bufnr,
		chan = channel,
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

		vim.api.nvim_chan_send(self.chan, table.concat(data, "\r\n"))

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

	self.job_id = vim.fn.jobstart(self.cmd, {
		cwd = self.cwd,
		pty = true,
		width = 500,
		on_stdout = on_stdout,
		on_stderr = on_stdout,
		on_exit = function(_, code)
			self.status = code == 0 and "SUCCESS" or "FAILED"
			self.exit_code = code

			local summary, item = parse_error(self.output)
			self.output = summary
			self.error = item

			vim.schedule(function()
				local ui_ok, ui = pcall(require, "buildsentry.ui")
				if ui_ok then
					ui.task_list.update(self)
					ui.update_guide()
				end
			end)
		end,
	})

	return self.job_id
end

function Task:stop()
	if self.job_id then
		vim.fn.jobstop(self.job_id)
		self.job_id = nil
		self.status = "TERMINATED"
	end
end

function Task:restart()
	self:stop()
	vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, {})
	self:start()
end

function Task:is_alive()
	return self.job_id ~= nil and self.status == "RUNNING"
end

function M.new(name, cmd, cwd)
	return Task.new(name, cmd, cwd)
end

return M
