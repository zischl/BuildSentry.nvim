local BuildSentry = {}

local config = require("buildsentry.config")
local state = require("buildsentry.state")
local ui = require("buildsentry.ui")
local executor = require("buildsentry.executor")
local cmake_adapter = require("buildsentry.adapter.cmake")

BuildSentry.open = ui.open
BuildSentry.exec = executor.exec
BuildSentry.tasks = state.tasks

function BuildSentry.setup(opts)
	config.setup(opts)

	if config.options.attach_cmake_tools then
		cmake_adapter.attach()

		local ok_const, const = pcall(require, "cmake-tools.const")
		if ok_const then
			const.cmake_executor.name = "buildsentry"
			const.cmake_runner.name = "buildsentry"
		end
	end

	ui.init()
end

return BuildSentry
