return {
	version = {
		command = "-v",
		output  = "Plume🪶b46 (Sparrow Edition)"
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