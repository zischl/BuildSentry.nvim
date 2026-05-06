local BuildSentry = {}

local ui = require("BuildSentry.ui")
local executor = require("BuildSentry.executor")
local cmake_adapter = require("BuildSentry.adapter.cmake")

BuildSentry.open = ui.open
BuildSentry.exec = executor.exec
BuildSentry.tasks = executor.tasks

function BuildSentry.setup(opts)
	cmake_adapter.attach(BuildSentry)
end

return BuildSentry
