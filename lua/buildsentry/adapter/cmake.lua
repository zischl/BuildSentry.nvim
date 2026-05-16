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

local function scan_compilers()
	local compilers = {}

	if vim.fn.executable("gcc") == 1 then
		local path = vim.fn.exepath("gcc")
		local gxx = vim.fn.exepath("g++")
		if gxx == "" then
			gxx = path
		end
		table.insert(compilers, {
			name = "GCC (Detected)",
			path = path,
			cxx_path = gxx,
			type = "gcc",
		})
	end

	if vim.fn.executable("clang") == 1 then
		local path = vim.fn.exepath("clang")
		local clangxx = vim.fn.exepath("clang++")
		if clangxx == "" then
			clangxx = path
		end
		table.insert(compilers, {
			name = "Clang (Detected)",
			path = path,
			cxx_path = clangxx,
			type = "clang",
		})
	end

	if vim.fn.has("win32") == 1 then
		local vswhere = "C:\\Program Files (x86)\\Microsoft Visual Studio\\Installer\\vswhere.exe"
		if vim.fn.executable(vswhere) == 1 then
			local output = vim.fn.system({ vswhere, "-products", "*", "-property", "installationPath" })
			for install_path in output:gmatch("[^\r\n]+") do
				local msvc_tools_path = install_path .. "\\VC\\Tools\\MSVC\\"
				local versions = vim.fn.glob(msvc_tools_path .. "*", false, true)
				for _, v_path in ipairs(versions) do
					local cl_x64 = v_path .. "\\bin\\Hostx64\\x64\\cl.exe"
					if vim.fn.executable(cl_x64) == 1 then
						local version = vim.fn.fnamemodify(v_path, ":t")
						table.insert(compilers, {
							name = "MSVC " .. version .. " (x64)",
							path = cl_x64,
							cxx_path = cl_x64,
							type = "msvc",
						})
					end

					local cl_x86 = v_path .. "\\bin\\Hostx86\\x86\\cl.exe"
					if vim.fn.executable(cl_x86) == 1 then
						local version = vim.fn.fnamemodify(v_path, ":t")
						table.insert(compilers, {
							name = "MSVC " .. version .. " (x86)",
							path = cl_x86,
							cxx_path = cl_x86,
							type = "msvc",
						})
					end
				end
			end
		end

		if vim.fn.executable("cl.exe") == 1 then
			local path = vim.fn.exepath("cl.exe")
			table.insert(compilers, {
				name = "MSVC (from PATH)",
				path = path,
				cxx_path = path,
				type = "msvc",
			})
		end
	end

	return compilers
end

local function scan_generators()
	local output = vim.fn.system("cmake --help")
	local generators = {}
	local start = false
	for line in output:gmatch("[^\r\n]+") do
		if line:match("^Generators") then
			start = true
		elseif start then
			local gen = line:match("^%*?%s+([^=]+)%s+=")
			if gen then
				gen = gen:gsub("%s+$", "")
				if not line:lower():match("deprecated") then
					table.insert(generators, gen)
				end
			end
		end
	end
	return generators
end

local function get_kit_info()
	local ok, cmake_tools = pcall(require, "cmake-tools")
	if not ok then
		return nil
	end
	local kit = cmake_tools.get_kit()
	if not kit then
		return nil
	end

	local info = {
		generator = kit.generator,
		compiler = "Unknown",
	}

	if kit.compilers then
		if kit.compilers.C then
			info.compiler = vim.fn.fnamemodify(kit.compilers.C, ":t")
		elseif kit.compilers.CXX then
			info.compiler = vim.fn.fnamemodify(kit.compilers.CXX, ":t")
		end
	end

	return info
end

local function get_preset_info()
	local ok, cmake_tools = pcall(require, "cmake-tools")
	if not ok then
		return nil
	end
	local preset = cmake_tools.get_configure_preset()
	if not preset then
		return nil
	end

	return {
		generator = preset.generator,
		compiler = preset.cacheVariables
				and (preset.cacheVariables.CMAKE_C_COMPILER or preset.cacheVariables.CMAKE_CXX_COMPILER)
				and vim.fn.fnamemodify(
					preset.cacheVariables.CMAKE_C_COMPILER or preset.cacheVariables.CMAKE_CXX_COMPILER,
					":t"
				)
			or "Preset Default",
	}
end

local function get_default_generator()
	local output = vim.fn.system("cmake --help")
	for line in output:gmatch("[^\r\n]+") do
		local gen = line:match("^%*%s+([^=]+)%s+=")
		if gen then
			return gen:gsub("%s+$", "")
		end
	end
	return "Ninja"
end

local function get_active_generator()
	local ok, cmake_tools = pcall(require, "cmake-tools")
	if not ok then
		return get_default_generator()
	end

	local config = cmake_tools.get_config()
	if config.use_preset then
		local info = get_preset_info()
		if info and info.generator then
			return info.generator
		end
	else
		local info = get_kit_info()
		if info and info.generator then
			return info.generator
		end
	end

	if config.generator then
		return config.generator
	end

	return get_default_generator()
end

local function get_active_compiler()
	local ok, cmake_tools = pcall(require, "cmake-tools")
	if not ok then
		return "Auto by CMake"
	end

	local config = cmake_tools.get_config()
	if config.use_preset then
		local info = get_preset_info()
		if info and info.compiler then
			return info.compiler
		end
	else
		local info = get_kit_info()
		if info and info.compiler then
			return info.compiler
		end
	end

	return "Auto by CMake"
end

local function generate_preset(compiler)
	local cmake_tools = require("cmake-tools")
	local config = cmake_tools.get_config()
	local preset_file = config.cwd .. "/CMakePresets.json"

	local preset_data = {
		version = 3,
		configurePresets = {},
	}

	if vim.fn.filereadable(preset_file) == 1 then
		local content = table.concat(vim.fn.readfile(preset_file), "\n")
		preset_data = vim.fn.json_decode(content)
	end

	if not preset_data.configurePresets then
		preset_data.configurePresets = {}
	end

	local preset_name = compiler.name:gsub("%s+", "-"):gsub("[^%w%-]", ""):lower()
	local preset_entry = {
		name = preset_name,
		displayName = compiler.name,
		generator = get_active_generator(),
		binaryDir = "${sourceDir}/build/" .. preset_name,
		cacheVariables = {
			CMAKE_C_COMPILER = compiler.path,
			CMAKE_CXX_COMPILER = compiler.cxx_path,
		},
	}

	local found = false
	for i, p in ipairs(preset_data.configurePresets) do
		if p.name == preset_name then
			preset_data.configurePresets[i] = preset_entry
			found = true
			break
		end
	end
	if not found then
		table.insert(preset_data.configurePresets, preset_entry)
	end

	vim.fn.writefile({ vim.fn.json_encode(preset_data) }, preset_file)

	vim.notify("Preset '" .. compiler.name .. "' generated.", vim.log.levels.INFO)
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
					label = "Select Generator",
					icon = "󰦨",
					value = function()
						return get_active_generator()
					end,
					fn = function()
						local generators = scan_generators()
						local items = {}
						for _, g in ipairs(generators) do
							table.insert(items, {
								label = g,
								fn = function()
									if ok then
										local config = cmake_tools.get_config()
										config.generator = g
									end
								end,
							})
						end
						return {
							title = "Select Generator",
							desc = "Choose a CMake generator for presets.",
							items = { items },
						}
					end,
				},
				{
					label = "Select Compiler",
					icon = "󰘦",
					value = function()
						return get_active_compiler()
					end,
					fn = function()
						local compilers = scan_compilers()

						local items = {}
						for _, c in ipairs(compilers) do
							table.insert(items, {
								label = c.name,
								fn = function()
									generate_preset(c)
								end,
							})
						end
						return {
							title = "Select Compiler",
							desc = "Select a compiler to generate a new CMakePreset.",
							items = { items },
						}
					end,
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
