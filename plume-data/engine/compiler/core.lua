--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function(plume)
	--- Compile a sourcefile into an executable bytecode
	--- @param code string The sourcecode
	--- @param filename string Unique name associated with the source code
	--- @param chunk chunk The table to store all sourcecode informations
	--- (bytecode, parameters names and number...)
	--- @return nil (instructions are writted directly into the chunk)
	function plume.compileFile(code, filename, chunk, runtime, isMain)
		if runtime.cache.chunks[filename] then
			plume.copyMacrosInfos(runtime.cache.chunks[filename], chunk)
			return true
		end

		local context = plume.newCompilationContext(chunk, runtime, isMain)

		-- A compilation is already running. Save the partial result
		if #runtime.instructions > 0 then
			context.savedInstructions = runtime.instructions
			runtime.instructions = {}
		end

		-- Make the ast from source code
		local ast = plume.parse(code, filename) 
		-- Call, for each ast node, a function to emit bytecode
		context.nodeHandler(ast) 

		-- Close context
		context.safeClose(nil, {contextToClose=context.contextVariableToClose})

		-- Save file offset
		chunk.offset = (runtime.bytecode and #runtime.bytecode or 0) + 1
		-- Encode OP, compute goto offsets
		plume.finalize(runtime, chunk)

		-- Restore instructions
		if context.savedInstructions then
			runtime.instructions = context.savedInstructions
			context.savedInstructions = nil
		end

		runtime.cache.chunks[filename] = chunk

		return true
	end

	--- @param chunk chunk
	--- @return nil
	function plume.newCompilationContext(chunk, runtime, isMain)
		local context = {}

		runtime.contextCount = runtime.contextCount + 1

		context.chunk = chunk
		context.runtime = runtime
		context.isMain = isMain

		context.constants = runtime.constants
		
		context.scopes      = {}
		context.stacks       = {}
		context.scopesUp    = {}
		context.roots       = {}

		context.importedVariables = {}

		context.accBlockDeep = 0

		context.contextVariableToClose = 0

		require 'plume-data/engine/compiler/labels'    (plume, context)
		require 'plume-data/engine/compiler/wrappers'  (plume, context)
		require 'plume-data/engine/compiler/utils'     (plume, context)
		require 'plume-data/engine/compiler/variables' (plume, context)
		require 'plume-data/engine/compiler/warnings'  (plume, context, context.nodeHandlerTable)

		context.nodeHandlerTable = {}
		require 'plume-data/engine/compiler/handlers/core'       (plume, context, context.nodeHandlerTable)

		require 'plume-data/engine/compiler/handlers/alu'        (plume, context, context.nodeHandlerTable)
		require 'plume-data/engine/compiler/handlers/branch'     (plume, context, context.nodeHandlerTable)
		require 'plume-data/engine/compiler/handlers/directives' (plume, context, context.nodeHandlerTable)
		require 'plume-data/engine/compiler/handlers/literals'   (plume, context, context.nodeHandlerTable)
		require 'plume-data/engine/compiler/handlers/loops'      (plume, context, context.nodeHandlerTable)
		require 'plume-data/engine/compiler/handlers/macro'      (plume, context, context.nodeHandlerTable)
		require 'plume-data/engine/compiler/handlers/scopes'     (plume, context, context.nodeHandlerTable)
		require 'plume-data/engine/compiler/handlers/table'      (plume, context, context.nodeHandlerTable)
		require 'plume-data/engine/compiler/handlers/variables'  (plume, context, context.nodeHandlerTable)


		return context
	end
end