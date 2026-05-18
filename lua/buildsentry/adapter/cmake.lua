local M = {}

local draft_state = {
	build_type = nil,
	config_mode = nil,
	kit = nil,
	configure_preset = nil,
	build_preset = nil,
	build_directory = nil,
	generator = nil,
	compiler = nil,
	initialized = false,
}

function M.clear_draft()
	draft_state.build_type = nil
	draft_state.kit = nil
	draft_state.configure_preset = nil
	draft_state.build_preset = nil
	draft_state.build_directory = nil
	draft_state.generator = nil
	draft_state.compiler = nil
	draft_state.initialized = false
end

function M.init_draft()
	if not draft_state.initialized then
		draft_state.build_type = nil
		draft_state.kit = nil
		draft_state.configure_preset = nil
		draft_state.build_preset = nil
		draft_state.build_directory = nil
		draft_state.generator = nil
		draft_state.compiler = nil
		draft_state.initialized = true
	end
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

local function preset_healthcheck(name, preset_type)
	if not name or name == "" then
		return false
	end
	local ok, cmake_tools = pcall(require, "cmake-tools")
	if not ok then
		return false
	end
	local config = cmake_tools.get_config()
	local preset_file = config.cwd .. "/CMakePresets.json"
	local user_preset_file = config.cwd .. "/CMakeUserPresets.json"

	local check_file = function(file)
		if vim.fn.filereadable(file) == 1 then
			local content = table.concat(vim.fn.readfile(file), "\n")
			local data = nil
			pcall(function()
				data = vim.fn.json_decode(content)
			end)
			if data then
				local list = data[preset_type or "configurePresets"]
				if list then
					for _, p in ipairs(list) do
						if p.name == name then
							return true
						end
					end
				end
			end
		end
		return false
	end

	return check_file(preset_file) or check_file(user_preset_file)
end

local function save_to_preset()
	local ok, cmake_tools = pcall(require, "cmake-tools")
	if not ok then
		vim.notify("cmake-tools.nvim is not loaded.", vim.log.levels.ERROR)
		return
	end

	local config = cmake_tools.get_config()
	local preset_file = config.cwd .. "/CMakePresets.json"

	local preset_data = {
		version = 3,
		configurePresets = {},
	}

	local file_exists = vim.fn.filereadable(preset_file) == 1
	if file_exists then
		local content = table.concat(vim.fn.readfile(preset_file), "\n")
		pcall(function()
			preset_data = vim.fn.json_decode(content)
		end)
	end

	if not preset_data.configurePresets then
		preset_data.configurePresets = {}
	end

	local active_preset = cmake_tools.get_configure_preset()
	local active_preset_name = type(active_preset) == "table" and active_preset.name or active_preset
	if not preset_healthcheck(active_preset_name, "configurePresets") then
		active_preset_name = nil
	end
	local target_preset = nil

	if active_preset_name then
		for _, preset in ipairs(preset_data.configurePresets) do
			if preset.name == active_preset_name then
				target_preset = preset
				break
			end
		end
	end

	if not target_preset then
		if active_preset_name and active_preset_name ~= "" then
			target_preset = {
				name = active_preset_name,
				displayName = active_preset_name .. " (BuildSentry)",
				binaryDir = "${sourceDir}/build/" .. active_preset_name,
			}
			table.insert(preset_data.configurePresets, target_preset)
		elseif #preset_data.configurePresets > 0 then
			target_preset = preset_data.configurePresets[1]
		else
			target_preset = {
				name = "default",
				displayName = "Default (BuildSentry)",
				binaryDir = "${sourceDir}/build/default",
			}
			table.insert(preset_data.configurePresets, target_preset)
		end
	end

	if draft_state.generator then
		target_preset.generator = draft_state.generator
		config.generator = draft_state.generator
	elseif not target_preset.generator then
		target_preset.generator = get_active_generator()
	end

	if draft_state.compiler then
		if not target_preset.cacheVariables then
			target_preset.cacheVariables = {}
		end
		target_preset.cacheVariables.CMAKE_C_COMPILER = draft_state.compiler.path
		target_preset.cacheVariables.CMAKE_CXX_COMPILER = draft_state.compiler.cxx_path
	end

	if draft_state.build_type then
		if not target_preset.cacheVariables then
			target_preset.cacheVariables = {}
		end
		target_preset.cacheVariables.CMAKE_BUILD_TYPE = draft_state.build_type
		config.build_type = draft_state.build_type
		pcall(vim.cmd, "CMakeSelectBuildType " .. draft_state.build_type)
	end

	if draft_state.build_directory then
		target_preset.binaryDir = draft_state.build_directory
		config.build_directory = draft_state.build_directory
	end

	if active_preset and type(active_preset) == "table" then
		if draft_state.generator then
			active_preset.generator = draft_state.generator
		end
		if draft_state.compiler then
			active_preset.cacheVariables = active_preset.cacheVariables or {}
			active_preset.cacheVariables.CMAKE_C_COMPILER = draft_state.compiler.path
			active_preset.cacheVariables.CMAKE_CXX_COMPILER = draft_state.compiler.cxx_path
		end
		if draft_state.build_type then
			active_preset.cacheVariables = active_preset.cacheVariables or {}
			active_preset.cacheVariables.CMAKE_BUILD_TYPE = draft_state.build_type
		end
		if draft_state.build_directory then
			active_preset.binaryDir = draft_state.build_directory
		end
	end

	config.use_preset = true

	local json_ok, json_str = pcall(vim.fn.json_encode, preset_data)
	if json_ok then
		vim.fn.writefile({ json_str }, preset_file)
		if file_exists then
			vim.notify("Successfully updated Preset in CMakePresets.json!", vim.log.levels.INFO)
		else
			vim.notify("Successfully generated CMakePresets.json!", vim.log.levels.INFO)
		end
		M.clear_draft()
	else
		vim.notify("Failed to encode CMakePresets.json", vim.log.levels.ERROR)
	end
end

local function save_to_kit()
	local ok, cmake_tools = pcall(require, "cmake-tools")
	if not ok then
		vim.notify("cmake-tools.nvim is not loaded.", vim.log.levels.ERROR)
		return
	end

	local config = cmake_tools.get_config()
	local kit_file = config.cwd .. "/CMakeKits.json"
	if vim.fn.filereadable(config.cwd .. "/cmake-kits.json") == 1 then
		kit_file = config.cwd .. "/cmake-kits.json"
	end

	local kits_data = {}
	local file_exists = vim.fn.filereadable(kit_file) == 1
	if file_exists then
		local content = table.concat(vim.fn.readfile(kit_file), "\n")
		pcall(function()
			kits_data = vim.fn.json_decode(content)
		end)
	end

	if type(kits_data) ~= "table" then
		kits_data = {}
	end

	local active_kit = cmake_tools.get_kit()
	local target_kit = nil

	if active_kit then
		for _, kit in ipairs(kits_data) do
			if kit.name == active_kit.name then
				target_kit = kit
				break
			end
		end
	end

	if not target_kit then
		local active_kit_name = active_kit and active_kit.name
		if active_kit_name and active_kit_name ~= "" then
			target_kit = {
				name = active_kit_name,
			}
			table.insert(kits_data, target_kit)
		elseif #kits_data > 0 then
			target_kit = kits_data[1]
		else
			target_kit = {
				name = "BuildSentry Kit",
			}
			table.insert(kits_data, target_kit)
		end
	end

	if draft_state.generator then
		target_kit.generator = draft_state.generator
		config.generator = draft_state.generator
	elseif not target_kit.generator then
		target_kit.generator = get_active_generator()
	end

	if draft_state.compiler then
		if not target_kit.compilers then
			target_kit.compilers = {}
		end
		target_kit.compilers.C = draft_state.compiler.path
		target_kit.compilers.CXX = draft_state.compiler.cxx_path
		target_kit.name = draft_state.compiler.name
	end

	if draft_state.build_type then
		config.build_type = draft_state.build_type
		pcall(vim.cmd, "CMakeSelectBuildType " .. draft_state.build_type)
	end

	if draft_state.build_directory then
		config.build_directory = draft_state.build_directory
	end

	if active_kit and type(active_kit) == "table" then
		if draft_state.generator then
			active_kit.generator = draft_state.generator
		end
		if draft_state.compiler then
			active_kit.name = draft_state.compiler.name
			active_kit.compilers = active_kit.compilers or {}
			active_kit.compilers.C = draft_state.compiler.path
			active_kit.compilers.CXX = draft_state.compiler.cxx_path
		end
	end

	config.use_preset = false

	local json_ok, json_str = pcall(vim.fn.json_encode, kits_data)
	if json_ok then
		vim.fn.writefile({ json_str }, kit_file)
		if file_exists then
			vim.notify("Successfully updated Kit in " .. vim.fn.fnamemodify(kit_file, ":t") .. "!", vim.log.levels.INFO)
		else
			vim.notify("Successfully generated CMakeKits.json!", vim.log.levels.INFO)
		end
		M.clear_draft()
	else
		vim.notify("Failed to encode kits data", vim.log.levels.ERROR)
	end
end

function M.get_config()
	M.init_draft()
	local ok, cmake_tools = pcall(require, "cmake-tools")

	local fetch = function(key)
		if not ok then
			return "None"
		end
		if key == "configure_preset" then
			local preset = cmake_tools.get_configure_preset()
			local name = type(preset) == "table" and preset.name or preset
			if preset_healthcheck(name, "configurePresets") then
				return name
			end
			return "None"
		elseif key == "build_preset" then
			local preset = cmake_tools.get_build_preset()
			local name = type(preset) == "table" and preset.name or preset
			if preset_healthcheck(name, "buildPresets") then
				return name
			end
			return "None"
		elseif key == "kit" then
			local kit = cmake_tools.get_kit()
			return type(kit) == "table" and kit.name or kit or "None"
		elseif key == "build_type" then
			local config = cmake_tools.get_config()
			return config.build_type or "None"
		elseif key == "build_directory" then
			local config = cmake_tools.get_config()
			return config.build_directory or "None"
		end
		return "None"
	end

	local preset_status = false
	local kit_status = false

	if ok then
		local config = cmake_tools.get_config()
		local preset_file = config.cwd .. "/CMakePresets.json"
		preset_status = vim.fn.filereadable(preset_file) == 1
		local kit_file = config.cwd .. "/CMakeKits.json"
		if vim.fn.filereadable(config.cwd .. "/cmake-kits.json") == 1 then
			kit_file = config.cwd .. "/cmake-kits.json"
		end
		kit_status = vim.fn.filereadable(kit_file) == 1
	end

	draft_state.config_mode = draft_state.config_mode
		or preset_status and "Preset Mode"
		or kit_status and "Kit Mode"
		or "None"

	return {
		title = "CMake Configuration",
		desc = "Manage your CMake build settings and presets.",
		items = {
			{
				{
					label = "Build Type",
					icon = "󰙨",
					value = function()
						if draft_state.build_type then
							return draft_state.build_type .. " *"
						end
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
										fn = function()
											draft_state.build_type = "Debug"
										end,
									},
									{
										label = "Release",
										fn = function()
											draft_state.build_type = "Release"
										end,
									},
									{
										label = "RelWithDebInfo",
										fn = function()
											draft_state.build_type = "RelWithDebInfo"
										end,
									},
									{
										label = "MinSizeRel",
										fn = function()
											draft_state.build_type = "MinSizeRel"
										end,
									},
								},
							},
						}
					end,
				},
				{
					label = "Configuration",
					icon = "󰘦",
					value = function()
						return draft_state.config_mode
							or preset_status and "Preset Mode"
							or kit_status and "Kit Mode"
							or "None"
					end,
					fn = function()
						return {
							title = "Select Configuration Mode",
							desc = "Choose a CMake configuration mode.",
							items = {
								{
									{
										label = "Preset Mode",
										fn = function()
											draft_state.config_mode = "Preset Mode"
										end,
									},
									{
										label = "Kit Mode",
										fn = function()
											draft_state.config_mode = "Kit Mode"
										end,
									},
									{
										label = "None",
										fn = function()
											draft_state.config_mode = "None"
										end,
									},
								},
							},
						}
					end,
				},

				draft_state.config_mode == "Preset Mode" and {
					label = "Config Preset",
					icon = "󰒓",
					value = function()
						return draft_state.configure_preset or fetch("configure_preset") or "None"
					end,
					fn = function()
						vim.cmd("CMakeSelectConfigurePreset")
					end,
				},

				draft_state.config_mode == "Preset Mode" and {
					label = "Build Preset",
					icon = "󰒓",
					value = function()
						return draft_state.build_preset or fetch("build_preset") or "None"
					end,
					fn = function()
						vim.cmd("CMakeSelectBuildPreset")
					end,
				},

				draft_state.config_mode == "Kit Mode" and {
					label = "Select Kit",
					icon = "󰒓",
					value = function()
						return draft_state.kit or fetch("kit") or "None"
					end,
					fn = function()
						vim.cmd("CMakeSelectKit")
					end,
				},

				{
					label = "Build Directory",
					icon = "󰉖",
					value = function()
						return draft_state.build_directory or fetch("build_directory")
					end,
					fn = function()
						vim.cmd("CMakeSelectBuildDir")
					end,
				},
				{
					label = "Select Generator",
					icon = "󰦨",
					value = function()
						if draft_state.generator then
							return draft_state.generator .. " *"
						end
						return get_active_generator()
					end,
					fn = function()
						local generators = scan_generators()
						local items = {}
						for _, g in ipairs(generators) do
							table.insert(items, {
								label = g,
								fn = function()
									draft_state.generator = g
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
						if draft_state.compiler then
							return draft_state.compiler.name .. " *"
						end
						return get_active_compiler()
					end,
					fn = function()
						local compilers = scan_compilers()

						local items = {}
						for _, c in ipairs(compilers) do
							table.insert(items, {
								label = c.name,
								fn = function()
									draft_state.compiler = c
								end,
							})
						end
						return {
							title = "Select Compiler",
							desc = "Select a compiler for your configuration.",
							items = { items },
						}
					end,
				},
			},
		},
		keymaps = {
			(draft_state.config_mode == "Preset Mode" or draft_state.config_mode == "None") and {
				key = "p",
				label = preset_status and "Save to Preset" or "Generate Preset",
				fn = function(item, index, lv)
					save_to_preset()
					if lv and lv.data_fn then
						vim.schedule(function()
							lv:update(lv.data_fn(), true)
						end)
					else
						vim.schedule(function()
							pcall(vim.api.nvim_win_close, 0, true)
							require("buildsentry.ui").configure()
						end)
					end
				end,
			},
			(draft_state.config_mode == "Kit Mode" or draft_state.config_mode == "None") and {
				key = "k",
				label = kit_status and "Save to Kit" or "Generate Kit",
				fn = function(item, index, lv)
					save_to_kit()
					if lv and lv.data_fn then
						vim.schedule(function()
							lv:update(lv.data_fn(), true)
						end)
					else
						vim.schedule(function()
							pcall(vim.api.nvim_win_close, 0, true)
							require("buildsentry.ui").configure()
						end)
					end
				end,
			},
		},
		on_close = function()
			M.clear_draft()
		end,
	}
end

return M
