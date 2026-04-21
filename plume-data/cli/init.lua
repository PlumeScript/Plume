--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

local help = [[
NAME
    Plume🪶 - a textual programming language for complex content generation

SYNOPSIS
    plume [OPTIONS]

DESCRIPTION
    Plume is a textual programming language designed to fuse templating
    with imperative logic through a paradigm of contextual accumulation.
    It allows for the creation of expressive Domain-Specific Languages (DSLs) 
    where code and content are structured as a single unit.

    The plume CLI tool executes Plume scripts, processing input files and
    generating formatted text output based on the logic defined within
    the script.

OPTIONS
    -i, --input <FILE>
        Specify the source file containing the Plume code to be processed.

    -s, --string <SCRIPT>
    	Execute the given string as a plume script.

    -o, --output <FILE>
        The destination file where the generated content will be saved.
        If this option is omitted, the output is printed directly to stdout.

    --error-style <fancy|auto|plain>
        Sets the visual style of compilation errors. 'fancy' uses Unicode 
        borders and symbols, 'plain' uses ASCII only for compatibility, 
        and 'auto' detects terminal capabilities.
        Default: auto

    --color <always|auto|never>
        Controls color output in the terminal. 'always' forces colors, 
        'never' disables them, and 'auto' detects if stdout is a TTY.
        Default: auto

    -h, --help
        Display this help message and terminate immediately.

    -v, --version
        Display the current Plume version using the Edition-Build scheme.

ENVIRONMENT VARIABLES
    PLUME_ERROR_STYLE
        Sets the error style (fancy|auto|plain). Used when no CLI flag is provided.
    PLUME_COLOR
        Sets color output (always|auto|never). Used when no CLI flag is provided.

VERSION
    !VERSION!

LICENSE
    Plume is licensed under the GNU General Public License v3 (GPLv3).
]]

local shortcut = {
	["-i"]="--input",
	["-o"]="--output",
	["-h"]="--help",
	["-v"]="--version",
	["-s"]="--string"
}

local function winCheckTerminalCapabilities()
    local ffi = require("ffi")

    ffi.cdef[[
        typedef void* HANDLE;
        int GetConsoleMode(HANDLE hConsoleOutput, unsigned int * lpMode);
        int SetConsoleMode(HANDLE hConsoleOutput, unsigned int dwMode);
        HANDLE GetStdHandle(int nStdHandle);
        unsigned int GetConsoleOutputCP();
    ]]

    local STD_OUTPUT_HANDLE = -11
    local ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004
    local CP_UTF8 = 65001

    local stdout = ffi.C.GetStdHandle(STD_OUTPUT_HANDLE)
    if stdout == nil or stdout == ffi.cast("HANDLE", -1) then
        return false, false
    end

    local mode = ffi.new("unsigned int[1]")
    local ansi_supported = false
    
    if ffi.C.GetConsoleMode(stdout, mode) ~= 0 then
        local new_mode = mode[0] or ENABLE_VIRTUAL_TERMINAL_PROCESSING
        if ffi.C.SetConsoleMode(stdout, new_mode) ~= 0 then
            ansi_supported = true
        end
    end

    local current_cp = ffi.C.GetConsoleOutputCP()
    local unicode_supported = (current_cp == CP_UTF8)

    return ansi_supported, unicode_supported
end

local function getErrorStyle()
	return os.getenv("PLUME_ERROR_STYLE") or "auto"
end

local function getColor()
	return os.getenv("PLUME_COLOR") or "auto"
end

local function parseArgs()
	local args = {}
	local pos = 2

	local function getNext()
		pos = pos + 1
		if not arg[pos] then
			print("Missing an argument for option " .. arg[pos-1] .. ".")
			return
		end
		return arg[pos]
	end

	-- Show help if no option
	if pos > #arg then
		args.showHelp = true
	end

	while pos <= #arg do
		local content = arg[pos]
		content = shortcut[content] or content

		if content == "--input" then
			args.inputFilename = getNext()
			if not args.inputFilename then
				return
			end
		elseif content == "--string" then
			args.inputString = getNext()
			if not args.inputString then
				return
			end
		elseif content == "--output" then
			args.outputFilename = getNext()
			if not args.outputFilename then
				return
			end
		elseif content == "--version" then
			args.showVersion = true
		elseif content == "--help" then
			args.showHelp = true
		elseif content == "--error-style" then
			args.errorStyle = getNext()
			if not args.errorStyle then
				return
			end
		elseif content == "--color" then
			args.color = getNext()
			if not args.color then
				return
			end
		else
			print("Unknown option '" .. content .. "'. Use plume -h to get help.")
			return
		end

		pos = pos + 1
	end

	args.errorStyle = args.errorStyle or getErrorStyle()
	args.color      = args.color      or getColor()

	if args.errorStyle == "auto" or args.color == "auto" then
		local ansi, unicode = winCheckTerminalCapabilities()

		if args.errorStyle == "auto" then
			if unicode then
				args.errorStyle = "fancy"
			else
				args.errorStyle = "plain"
			end
		end
		if args.color == "auto" then
			if ansi then
				args.color = "always"
			else
				args.color = "never"
			end
		end
	end

	return args
end

local function main()
	local args = parseArgs()
	if not args then
		return
	end

	package.path = arg[1].."/?.lua;" .. package.path
	local plume = require "plume-data/engine/init"
	if args.showHelp then
		print((help:gsub('!VERSION!', plume._VERSION)))
	elseif args.showVersion then
		print("Plume🪶" .. plume._VERSION)
	elseif args.inputFilename or args.inputString then
		local success, result

		if args.inputFilename then
			success, result = plume.executeFile(args.inputFilename, nil, nil, args)
		else
			success, result = plume.executeString(args.inputString, "<input>",nil, nil, args)
		end

		if success then
			result = plume.repr(result)
			if args.outputFilename then
				local file = io.open(args.outputFilename, "w")
					if not file then
						io.stderr:write("Cannot open output file\n")
						return
					end
					file:write(result)
				file:close()
			else
				print(result)
			end
		else
			io.stderr:write(result .. "\n")
		end
	end
end

main()