--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function(plume)
	function plume.error.throwCompilationError(node, message)
		message = plume.error.makeCompilationError(node, message)
		error(message, -1)
	end

	function plume.error.throwSyntaxError(node, message)
		message = plume.error.makeSyntaxError(node, message)
		error(message, -1)
	end

	function plume.error.strictWarningError (node, message)
		message = plume.error.makeStrictWarningError(node, message)
		error(message, -1)
	end

	require 'plume-data/engine/error/messages/import'    (plume)
	require 'plume-data/engine/error/messages/macros'    (plume)
	require 'plume-data/engine/error/messages/others'    (plume)
	require 'plume-data/engine/error/messages/syntax'    (plume)
	require 'plume-data/engine/error/messages/types'     (plume)
	require 'plume-data/engine/error/messages/variables' (plume)
	require 'plume-data/engine/error/messages/std'       (plume)
	require 'plume-data/engine/error/messages/finalizer' (plume)
end