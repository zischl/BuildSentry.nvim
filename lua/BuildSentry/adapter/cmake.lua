local M = {}

function M.get_adapter(BuildSentry)
	return {
		run = function(cmd, env_script, env, args, cwd, opts, on_exit, on_output)
			local name = opts.title or (args and args[1]) or "CMake Task"
			local full_cmd = cmd .. " " .. table.concat(args, " ")

			BuildSentry.exec(name, full_cmd, cwd)
			BuildSentry.open()

			if on_exit then
				on_exit(0)
			end
		end,

		show = function(opts)
			BuildSentry.open()
		end,
		close = function(opts) end,
		stop = function(opts) end,
		has_active_job = function(opts)
			return false
		end,
		is_installed = function()
			return true
		end,
	}
end

function M.attach(BuildSentry)
	local ok_exec, executors = pcall(require, "cmake-tools.executors")
	local ok_run, runners = pcall(require, "cmake-tools.runners")

	local adapter = M.get_adapter(BuildSentry)

	if ok_exec then
		executors.buildsentry = adapter
	end
	if ok_run then
		runners.buildsentry = adapter
	end
end

return M
