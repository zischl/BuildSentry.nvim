local M = {}

function M.generate_task_name(cmd, args, opts)
	if opts.title and opts.title ~= "" then
		return opts.title
	end

	if args then
		local target = nil
		local build = false
		for i, arg in ipairs(args) do
			if arg == "--target" and args[i + 1] then
				target = args[i + 1]
			elseif arg == "--build" then
				build = true
			end
		end

		if target then
			return "CMake Build: " .. target
		elseif build then
			return "CMake Build"
		end
	end

	if cmd:match("cmake$") or cmd:match("cmake.exe$") then
		return "CMake Configure"
	end

	local exe_name = vim.fn.fnamemodify(cmd, ":t")
	return "Run: " .. exe_name
end

function M.get_adapter()
	return {
		name = "buildsentry",
		run = function(cmd, env_script, env, args, cwd, opts, on_exit, on_output)
			local BuildSentry = require("buildsentry")

			local name = M.generate_task_name(cmd, args, opts)
			local full_cmd = cmd .. " " .. table.concat(args, " ")

			BuildSentry.exec(name, full_cmd, cwd)
			BuildSentry.open()

			if on_exit then
				on_exit(0)
			end
		end,

		show = function(opts)
			require("buildsentry").open()
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

function M.get_actions()
	return {
		{
			name = "Build",
			icon = "󰑐",
			fn = function()
				vim.cmd("CMakeBuild")
			end,
		},
		{
			name = "Run",
			icon = "󰆊",
			fn = function()
				vim.cmd("CMakeRun")
			end,
		},
		{
			name = "Debug",
			icon = "󰅟",
			fn = function()
				vim.cmd("CMakeDebug")
			end,
		},
		{
			name = "Generate",
			icon = "󰦨",
			fn = function()
				vim.cmd("CMakeGenerate")
			end,
		},
		{
			name = "Clean",
			icon = "󰃢",
			fn = function()
				vim.cmd("CMakeClean")
			end,
		},
		{
			name = "Select Target",
			icon = "󰗀",
			fn = function()
				vim.cmd("CMakeSelectBuildTarget")
			end,
		},
		{
			name = "Select Build Preset",
			icon = "󰒓",
			fn = function()
				vim.cmd("CMakeSelectBuildPreset")
			end,
		},
		{
			name = "Select Config Preset",
			icon = "󰒓",
			fn = function()
				vim.cmd("CMakeSelectConfigurePreset")
			end,
		},
		{
			name = "Select Build Type",
			icon = "󰙨",
			fn = function()
				vim.cmd("CMakeSelectBuildType")
			end,
		},
		{
			name = "Edit Build Directory",
			icon = "󰉖",
			fn = function()
				vim.cmd("CMakeSelectBuildDir")
			end,
		},
		{
			name = "Select Kit",
			icon = "󰘦",
			fn = function()
				vim.cmd("CMakeSelectKit")
			end,
		},
	}
end

function M.attach()
	local ok_exec, executors = pcall(require, "cmake-tools.executors")
	local ok_run, runners = pcall(require, "cmake-tools.runners")

	if not (ok_exec and ok_run) then
		return
	end

	local adapter = M.get_adapter()
	executors.buildsentry = adapter
	runners.buildsentry = adapter

	local ok_const, const = pcall(require, "cmake-tools.const")
	if ok_const then
		if const.cmake_executor and const.cmake_executor.default_opts then
			const.cmake_executor.default_opts.buildsentry = {}
		end
		if const.cmake_runner and const.cmake_runner.default_opts then
			const.cmake_runner.default_opts.buildsentry = {}
		end
	end
end

function M.get_config()
	local ok, cmake_tools = pcall(require, "cmake-tools")
	local fetch = function(key)
		if not ok then
			return "Unknown"
		end
		local config = cmake_tools.get_config()
		return config[key] or "None"
	end

	local function set_build_type(t)
		vim.cmd("CMakeSelectBuildType " .. t)
		return M.get_config()
	end

	return {
		title = "CMake Configuration",
		desc = "Manage your CMake build settings and presets.",
		items = {
			{
				{
					label = "Build Type",
					icon = "󰙨",
					value = function()
						return fetch("build_type")
					end,
					fn = function()
						return {
							title = "Select Build Type",
							desc = "Choose a CMake build configuration.",
							items = {
								{
									{
										label = "Debug",
										fn = function() end,
									},
									{
										label = "Release",
										fn = function() end,
									},
									{
										label = "RelWithDebInfo",
										fn = function() end,
									},
									{
										label = "MinSizeRel",
										fn = function() end,
									},
								},
							},
						}
					end,
				},
				{
					label = "Select Kit",
					icon = "󰘦",
					value = function()
						return fetch("kit")
					end,
					fn = function() end,
				},
				{
					label = "Config Preset",
					icon = "󰒓",
					value = function()
						return fetch("configure_preset")
					end,
					fn = function() end,
				},
				{
					label = "Build Preset",
					icon = "󰒓",
					value = function()
						return fetch("build_preset")
					end,
					fn = function() end,
				},
				{
					label = "Build Directory",
					icon = "󰉖",
					value = function()
						return fetch("build_directory")
					end,
					fn = function()
						vim.cmd("CMakeSelectBuildDir")
					end,
				},
				{
					label = "Select Compiler",
					icon = "󰘦",
					value = "None",
					fn = function() end,
				},
			},
		},
		keymaps = {
			{
				key = "s",
				label = "Save",
				fn = function() end,
			},
		},
	}
end

return M
