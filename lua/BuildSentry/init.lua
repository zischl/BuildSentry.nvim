local BuildSentry = {}

local ui = require("BuildSentry.ui")
local executor = require("BuildSentry.executor")
local cmake_adapter = require("BuildSentry.adapter.cmake")

BuildSentry.open = ui.open
BuildSentry.exec = executor.exec
BuildSentry.tasks = executor.tasks

function BuildSentry.setup(opts)
	cmake_adapter.attach()

	local ok_cmake, cmake = pcall(require, "cmake-tools")
	if ok_cmake then
		cmake.setup({
			cmake_executor = { name = "buildsentry" },
			cmake_runner = { name = "buildsentry" },
		})
	end
end

return BuildSentry
