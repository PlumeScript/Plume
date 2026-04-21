return {
	write = {
		command = "-s \"$write(test, content)\"",
		outputFile = {
			name="test",
			content="content"
		}
	},
	writeAppend = {
		command = "-s \"$write(test, wing, ?append)\"",
		inputFile = {
			name="test",
			content="content"
		},
		outputFile = {
			name="test",
			content="contentwing"
		}
	},
	read = {
		command = "-s \"$read(test)\"",
		inputFile = {
			name="test",
			content="content"
		},
		output = "content"
	},
	readError = {
		command = "-s \"$read(test)\"",
		error = true,
		output = [[╭────────────────────────────────────────────────────────────────────────────────╮
│ RUNTIME ERROR:                                                                 │
│ → Cannot read file 'test'.                                                     │
├────────────────────────────────────────────────────────────────────────────────┤
│                                                                                │
│  ↳ <input>                                                                     │
│    1 │$read(test)                                                              │
│      │ ^^^^^^^^^^                                                              │
│                                                                                │
╰────────────────────────────────────────────────────────────────────────────────╯]]
	},
}