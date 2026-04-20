return {
	version = {
		command = "-v",
		output  = "Plume🪶b44 (Sparrow Edition)"
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
	}
}