--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function(vm)
	--! inline
	function vm:_RUN_END()
		if self:_STACK_POS(self.recursiveStack) > 0 then
			self.ip = self:_STACK_POP(self.recursiveStack)
			self:_RESET_JUMP()
			self:_SAVE_SCALAR()
		end
	end

	--! inline
	function vm:_RUN_START(destip)
		local success, result, callvmerrip
		if self:_STACK_POS(self.recursiveStack) > 20 then
			success = false
			result  = self.plume.error.stackOverflow()
			self:_ERROR(result)
		else
			self:_SAVE_SCALAR()
			self:_STACK_PUSH(self.recursiveStack, self.ip)
			success, result, callvmerrip = vm:_RUN(destip)
			self:_UPDATE_SCALAR()
			if not success then
				self.ip = callvmerrip
				self:_ERROR(result)
				self:_JUMP_END()
			end
		end
		return success, result, callvmerrip
	end

	--! inline
	function vm:_CONCAT_CALL_REC()
		return self:_RUN_START(self.plume.sops.CONCAT_CALL)
	end

	--! inline
	function vm:_CONCAT_CALL_SAFE_REC()
		return self:_RUN_START(self.plume.sops.CONCAT_CALL_SAFE)
	end
end
