return {
	version = {
		command = "-v",
		output  = "Plume🪶b56 (Owl Edition)"
	},
	io = {
		command   = "-i in.plume -o out.plume",
		inputFile = {
			name="in.plume",
			content="$(1+1)"
		},
		outputFile = {
			name="out.plume",
			content="2"
		}
	},
	param = {
		command   = "-i in.plume --params x:50",
		inputFile = {
			name="in.plume",
			content="let param x = 5\n$x"
		},
		output = "50"
	},
	["Param parse error"] = {
		command   = "-i in.plume --params x50",
		inputFile = {
			name="in.plume",
			content="let param x = 5\n$x"
		},
		output = "Cannot parse parameter 'x50'. Use only `key:value` or `?flag` syntax."
	},
	["Wrong input"] = {
		command   = "-i in.plume -o out.plume",
		error     = true,
		output    = "Error: the file 'in.plume' don't exist or isn't readable."
	},
	s = {
		command = "-s \"$(1+1)\"",
		output  = "2"
	},

	s_error = {
		command = "-s \"$(1+)\"",
		error=true,
		output  = [[╭────────────────────────────────────────────────────────────────────────────────╮
│ SYNTAX ERROR:                                                                  │
│ → Missing ')' to close evaluation.                                             │
├────────────────────────────────────────────────────────────────────────────────┤
│                                                                                │
│  ↳ <input>                                                                     │
│    1 │$(1+)                                                                    │
│      │   ^^^                                                                   │
│                                                                                │
╰────────────────────────────────────────────────────────────────────────────────╯]]	},
}