local window_util = require("buildsentry.ui.window")

local function setup_buf_name(buf, name)
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	local existing_buf = vim.fn.bufnr(name)
	if existing_buf ~= -1 and existing_buf ~= buf and vim.api.nvim_buf_is_valid(existing_buf) then
		pcall(vim.api.nvim_buf_delete, existing_buf, { force = true })
	end
	pcall(vim.api.nvim_buf_set_name, buf, name)
end

local ListView = {}
ListView.__index = ListView

---@param data table
function ListView:new(data)
	local obj = setmetatable({
		title = data.title or "",
		desc = data.desc or "",
		sections = data.items or {},
		keymaps = data.keymaps or {},
		on_close = data.on_close,
		current_index = 1,
		ns = vim.api.nvim_create_namespace("buildsentry_listview"),
		buf = nil,
		win = nil,
		history = {},
	}, self)

	obj.flat_items = {}
	for _, section in ipairs(obj.sections) do
		for _, item in ipairs(section) do
			vim.print(item)
			if item then
				table.insert(obj.flat_items, item)
			end
		end
	end

	return obj
end

function ListView:render()
	if not self.buf or not vim.api.nvim_buf_is_valid(self.buf) then
		self.buf = vim.api.nvim_create_buf(false, true)
		vim.bo[self.buf].bufhidden = "wipe"
		setup_buf_name(self.buf, self.title)
	end

	local stats = vim.api.nvim_list_uis()[1]
	local width = 70
	local height = 18
	local row = math.floor((stats.height - height) / 2)
	local col = math.floor((stats.width - width) / 2)

	if not self.win or not vim.api.nvim_win_is_valid(self.win) then
		self.win = window_util.create_float(self.buf, {
			row = row,
			col = col,
			width = width,
			height = height,
			focus = true,
			border = "single",
		})
	end

	vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, {})
	vim.api.nvim_buf_clear_namespace(self.buf, self.ns, 0, -1)

	local lines = {}
	local header_title = " " .. self.title:upper()
	table.insert(lines, header_title)

	table.insert(lines, string.rep("─", width))

	table.insert(lines, "")

	if self.desc ~= "" then
		table.insert(lines, "  " .. self.desc)
	else
		table.insert(lines, "")
	end

	table.insert(lines, "")

	table.insert(lines, "  SETTINGS:")
	self.start_row = #lines

	for _ = 1, #self.flat_items do
		table.insert(lines, "")
	end

	local current_height = #lines
	local footer_row = height - 2
	for _ = current_height + 1, footer_row - 1 do
		table.insert(lines, "")
	end

	table.insert(lines, " " .. string.rep("─", width - 2))

	local footer_items = {}
	if #self.history > 0 then
		table.insert(footer_items, "[BS/h] Back")
	end
	for _, km in ipairs(self.keymaps) do
		if km.desc or km.label then
			table.insert(footer_items, string.format("[%s] %s", km.key, km.desc or km.label))
		end
	end
	table.insert(lines, "  " .. table.concat(footer_items, "       "))

	vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, lines)

	vim.api.nvim_buf_add_highlight(self.buf, self.ns, "Title", 0, 0, -1)
	vim.api.nvim_buf_add_highlight(self.buf, self.ns, "Comment", 1, 0, -1)
	vim.api.nvim_buf_add_highlight(self.buf, self.ns, "DiagnosticInfo", 3, 0, -1)
	vim.api.nvim_buf_add_highlight(self.buf, self.ns, "Bold", 5, 0, -1)
	vim.api.nvim_buf_add_highlight(self.buf, self.ns, "Comment", footer_row, 0, -1)
	vim.api.nvim_buf_add_highlight(self.buf, self.ns, "DiagnosticWarn", footer_row + 1, 0, -1)

	if not self.focus_guard_au then
		self.focus_guard_au = vim.api.nvim_create_autocmd("WinLeave", {
			buffer = self.buf,
			callback = function()
				if not self.picker_active then
					self:close()
				end
			end,
		})
	end

	if not self.exit_au then
		self.exit_au = vim.api.nvim_create_autocmd({ "BufWinLeave", "WinClosed" }, {
			buffer = self.buf,
			once = true,
			callback = function()
				io.write("\27[?25h")
				self.exit_au = nil
			end,
		})
	end

	io.write("\27[?25l")
	self:refresh()
	vim.api.nvim_win_set_cursor(self.win, { self.start_row + self.current_index, 0 })
	self:setup_keymaps(self.buf)
end

function ListView:refresh()
	if not self.buf or not vim.api.nvim_buf_is_valid(self.buf) then
		return
	end

	for i, item in ipairs(self.flat_items) do
		local row = self.start_row + i - 1
		local selected = i == self.current_index
		local label = item.label or "Item"
		local value = ""
		if type(item.value) == "function" then
			value = item.value()
		else
			value = item.value or ""
		end

		local cursor = selected and "> " or "  "
		local virt_text = {
			{ "    ", "" },
			{ cursor, selected and "DiagnosticOk" or "Normal" },
			{ label .. "", selected and "Bold" or "Normal" },
		}

		if value ~= "" then
			local val_str = tostring(value)
			local label_w = 4 + 2 + vim.fn.strdisplaywidth(label) + 1
			local padding = string.rep(" ", math.max(2, 20 - vim.fn.strdisplaywidth(label)))
			table.insert(virt_text, { padding, "" })
			table.insert(virt_text, { val_str, "Comment" })
		end

		vim.api.nvim_buf_set_extmark(self.buf, self.ns, row, 0, {
			id = i,
			virt_text = virt_text,
			virt_text_pos = "overlay",
			line_hl_group = selected and "Visual" or nil,
			hl_mode = "combine",
		})
	end
end

function ListView:setup_keymaps(buf)
	local map_opts = { buffer = buf, noremap = true, silent = true }

	vim.keymap.set("n", "j", function()
		self:next()
	end, map_opts)
	vim.keymap.set("n", "k", function()
		self:prev()
	end, map_opts)
	vim.keymap.set("n", "<Down>", function()
		self:next()
	end, map_opts)
	vim.keymap.set("n", "<Up>", function()
		self:prev()
	end, map_opts)
	vim.keymap.set("n", "<CR>", function()
		self:confirm()
	end, map_opts)
	vim.keymap.set("n", "q", function()
		self:close()
	end, map_opts)
	vim.keymap.set("n", "<Esc>", function()
		self:close()
	end, map_opts)
	vim.keymap.set("n", "<BS>", function()
		self:back()
	end, map_opts)
	vim.keymap.set("n", "h", function()
		self:back()
	end, map_opts)

	for _, km in ipairs(self.keymaps) do
		vim.keymap.set(km.mode or "n", km.key, function()
			local current_item = self.flat_items[self.current_index]
			if not km.enabled or km.enabled(current_item) then
				km.fn(current_item, self.current_index, self)
			end
		end, map_opts)
	end
end

function ListView:next()
	if self.current_index < #self.flat_items then
		self.current_index = self.current_index + 1
		self:refresh()
	end
end

function ListView:prev()
	if self.current_index > 1 then
		self.current_index = self.current_index - 1
		self:refresh()
	end
end

function ListView:confirm()
	local item = self.flat_items[self.current_index]
	if item and item.fn then
		self.picker_active = true
		local result = item.fn()

		if type(result) == "table" and (result.items or result.sections) then
			self:update(result)
		else
			vim.defer_fn(function()
				self.picker_active = false
			end, 200)

			vim.schedule(function()
				self:refresh()
				self.back(self)
			end)
		end
	end
end

function ListView:update(data, stateless)
	if not stateless then
		table.insert(self.history, {
			title = self.title,
			desc = self.desc,
			sections = self.sections,
			keymaps = self.keymaps,
			current_index = self.current_index,
		})
	end

	self.title = data.title or self.title
	self.desc = data.desc or ""
	self.sections = data.items or data.sections or {}
	self.keymaps = data.keymaps or {}

	if self.buf and vim.api.nvim_buf_is_valid(self.buf) then
		setup_buf_name(self.buf, self.title)
	end

	self.flat_items = {}
	for _, section in ipairs(self.sections) do
		for _, item in ipairs(section) do
			if item then
				table.insert(self.flat_items, item)
			end
		end
	end

	if stateless then
		self.current_index = data.current_index or 1
	else
		self.current_index = 1
	end

	if self.current_index > #self.flat_items then
		self.current_index = math.max(1, #self.flat_items)
	end

	self:render()
end

function ListView:back()
	if #self.history > 0 then
		local prev = table.remove(self.history)
		if #self.history == 0 and self.data_fn then
			local fresh_data = self.data_fn()
			if fresh_data then
				fresh_data.current_index = prev.current_index
				self:update(fresh_data, true)
			else
				self:update(prev, true)
			end
		else
			self:update(prev, true)
		end
	else
		self:close()
	end
end

function ListView:close()
	if self.win and vim.api.nvim_win_is_valid(self.win) then
		vim.api.nvim_win_close(self.win, true)
	end

	if self.buf and vim.api.nvim_buf_is_valid(self.buf) then
		pcall(vim.api.nvim_buf_delete, self.buf, { force = true })
	end
	self.buf = nil
	self.win = nil

	if self.focus_guard_au then
		pcall(vim.api.nvim_del_autocmd, self.focus_guard_au)
		self.focus_guard_au = nil
	end

	io.write("\27[?25h")
	if self.on_close then
		self.on_close()
	end
end

local M = {}

---@param options table|table[]|function
---@param title? string
---@param on_close? function
function M.open(options, title, on_close)
	local data = {}
	local data_fn = nil
	if type(options) == "function" then
		data_fn = options
		data = options()
	elseif type(options) == "table" and options.items then
		data = options
	else
		data = {
			title = title or "List",
			items = { options },
			on_close = on_close,
		}
	end
	local lv = ListView:new(data)
	if data_fn then
		lv.data_fn = data_fn
	end
	lv:render()
	return lv
end

return M
