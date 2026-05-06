local BuildSentry = {}
BuildSentry.defaults = {
	attach_cmake_tools = false,
}

local state = require("BuildSentry.state")
local ui = require("BuildSentry.ui")
local executor = require("BuildSentry.executor")
local cmake_adapter = require("BuildSentry.adapter.cmake")

BuildSentry.open = ui.open
BuildSentry.exec = executor.exec
BuildSentry.tasks = state.tasks

function BuildSentry.setup(opts)
	BuildSentry.config = vim.tbl_deep_extend("force", BuildSentry.defaults, opts or {})

	if BuildSentry.config.attach_cmake_tools then
		cmake_adapter.attach()

		local ok_const, const = pcall(require, "cmake-tools.const")
		if ok_const then
			const.cmake_executor.name = "buildsentry"
			const.cmake_runner.name = "buildsentry"
		end
	end
end

return BuildSentry
