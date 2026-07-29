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
		if self:_STACK_POS(self.recursiveStack) > 20 then
			self:_ERROR(self.plume.error.stackOverflow())
		else
			self:_SAVE_SCALAR()
			self:_STACK_PUSH(self.recursiveStack, self.ip)
			local success, callvmerr, callvmerrip = self.plume._run_dev(self, destip)
			self:_UPDATE_SCALAR()
			if not success then
				self.ip = callvmerrip
				self:_ERROR(callvmerr)
				self:_JUMP_END()
			end
		end
	end

	--! inline
	function vm:_CONCAT_CALL_REC()
		self:_RUN_START(self.plume.sops.CONCAT_CALL)
	end

	--! inline
	function vm:_CONCAT_CALL_SAFE_REC()
		self:_RUN_START(self.plume.sops.CONCAT_CALL_SAFE)
	end
end
