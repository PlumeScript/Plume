--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function(plume)
	function plume.obj.vm(runtime)
		local vm = {
			--- to remove? ----
			plume      = plume,
			-------------------
			ip         = 0,
			tic        = 0,
			jump       = 0,
			fileParams = nil,

			runtime    = runtime,
			bytecode   = runtime.bytecode,
			constants  = runtime.constants,
			upvalueMap = table.new(2^10, 0),

			flag = {
				ITER_TABLE  = 0,
				ITER_SEQ    = 1,
				ITER_ITEMS  = 2,
				ITER_ENUMS  = 3,
				ITER_CUSTOM = 4
			}
		}

		-- Stacks
		vm.mainStack                = table.new(2^14, 0)
		vm.mainStack.frames         = table.new(2^8, 0)
		vm.mainStack.pointer        = 0
		vm.mainStack.frames.pointer = 0

		vm.variableStack                = table.new(2^10, 0)
		vm.variableStack.frames         = table.new(2^8, 0)
		vm.variableStack.pointer        = 0
		vm.variableStack.frames.pointer = 0
			
		vm.closureStack                 = table.new(2^8, 0)
		vm.closureStack.pointer         = 0

		vm.fileStack         = table.new(2^8, 0)
		vm.fileStack.pointer = 1

		vm.macroStack         = table.new(2^8, 0)
		vm.macroStack.pointer = 0

		vm.injectionStack         = table.new(64, 0)
		vm.injectionStack.pointer = 0

		vm.tagStack = table.new(2^14, 0)

		-- Context
		vm.runtime.localStack         = table.new(2^8, 0)
		vm.runtime.localStack.pointer = 0
		vm.contextStackCache          = table.new(2^8, 0)
		vm.contextStackCache.pointer  = 0

		return vm
	end
end