local M = {}

M.defaults = {
	attach_cmake_tools = false,
}

M.options = {}

function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
