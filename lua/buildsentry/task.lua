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
---@field diagnostics table
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
		diagnostics = {
			items = {},
			errors = 0,
			warnings = 0,
		},
		extmark_id = nil,
	}, Task)

	return self
end

function Task:start()
	if self.job_id then
		self:stop()
	end

	self.status = "RUN"
	self.exit_code = nil
	self.error = nil

	local function on_stdout(_, data)
		if not data or (#data == 1 and data[1] == "") then
			return
		end

		for _, raw_line in ipairs(data) do
			local line = raw_line:gsub("\27%[[0-9;?]*[a-zA-Z]", ""):gsub("\r", ""):gsub("%s+$", "")
			if line ~= "" then
				if line:match(":") then
					local _, item = parse_error(line)
					if item and item.valid == 1 then
						table.insert(self.diagnostics.items, item)
						if item.type == "W" then
							self.diagnostics.warnings = self.diagnostics.warnings + 1
						else
							self.diagnostics.errors = self.diagnostics.errors + 1
						end
						self.error = item
					end
				end
				self.output = line
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
		local stream_output = self.output

		vim.schedule(function()
			local fallback_line = stream_output
			local buffer_error_item = nil

			if self.bufnr and vim.api.nvim_buf_is_valid(self.bufnr) then
				local line_count = vim.api.nvim_buf_line_count(self.bufnr)
				local start_line = math.max(0, line_count - 100)
				local lines = vim.api.nvim_buf_get_lines(self.bufnr, start_line, line_count, false)

				local qf = vim.fn.getqflist({ lines = lines })
				if qf.items and #qf.items > 0 then
					for i = #qf.items, 1, -1 do
						local item = qf.items[i]
						if item.valid == 1 and item.lnum > 0 then
							buffer_error_item = item
							break
						end
					end
				end
			end

			local summary, item
			if buffer_error_item then
				local type_label = (buffer_error_item.type == "W" and "Warning" or "Error")
				local location = ""
				if buffer_error_item.lnum > 0 then
					location = string.format("[%d:%d] ", buffer_error_item.lnum, buffer_error_item.col)
				end
				summary = string.format("%s: %s%s", type_label, location, buffer_error_item.text)
				item = buffer_error_item
			else
				summary, item = parse_error(fallback_line)
			end

			self.output = summary ~= "" and summary or self.output

			self.error = item or self.diagnostics.items[#self.diagnostics.items]

			if self.status ~= "TRM" then
				local terminated = terminated_codes[code] or (self.output and self.output:match("%^C"))

				if terminated then
					self.status = "TRM"
				else
					self.status = code == 0 and "OK" or "FAIL"
				end
			end
			self.exit_code = code
			self.job_id = nil

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
		self.status = "TRM"
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
	return self.job_id ~= nil and self.status == "RUN"
end

function M.new(name, cmd, cwd)
	return Task.new(name, cmd, cwd)
end

return M
