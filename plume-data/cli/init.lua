--[[This file is part of Plume

Plume🪶 is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3 of the License.

Plume🪶 is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with Plume🪶.
If not, see <https://www.gnu.org/licenses/>.
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

    -o, --output <FILE>
        The destination file where the generated content will be saved.
        If this option is omitted, the output is printed directly to
        standard output (stdout).

    -h, --help
        Display this help message and terminate immediately.

    -v, --version
        Display the current Plume version using the Edition-Build scheme

VERSION
    !VERSION!

LICENSE
    Plume is licensed under the GNU General Public License v3 (GPLv3).

]]

local shortcut = {
	["-i"]="--input",
	["-o"]="--output",
	["-h"]="--help",
	["-v"]="--version"
}

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
		elseif content == "--output" then
			args.outputFilename = getNext()
			if not args.outputFilename then
				return
			end
		elseif content == "--version" then
			args.showVersion = true
		elseif content == "--help" then
			args.showHelp = true
		else
			print("Unknown option '" .. content .. "'. Use plume -h to get help.")
		end

		pos = pos + 1
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
	elseif args.inputFilename then
		local success, result = plume.executeFile(args.inputFilename)

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