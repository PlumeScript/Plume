return {
	write = {
		command = "-s \"$write(test, content)\"",
		outputFile = {
			name="test",
			content="content"
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