--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

--! inline
function _RUN_END(vm)
	if _STACK_POS(vm, vm.recursiveStack) > 0 then
		vm.ip = _STACK_POP(vm, vm.recursiveStack)
		_RESET_JUMP(vm)
		_SAVE_SCALAR(vm)
	end
end

--! inline
function _RUN_START(vm, destip)
	if _STACK_POS(vm, vm.recursiveStack) > 20 then
		_ERROR (vm, vm.plume.error.stackOverflow())
	else
		_SAVE_SCALAR(vm)
		_STACK_PUSH(vm, vm.recursiveStack, vm.ip)
		local success, callvmerr, callvmerrip = vm.plume._run_dev(vm, destip)
		_UPDATE_SCALAR(vm)
		if not success then
			vm.ip = callvmerrip
			_ERROR(vm, callvmerr)
			_JUMP_END(vm)
		end
	end
end

--! inline
function _CONCAT_CALL_REC(vm)
	_RUN_START(vm, vm.plume.sops.CONCAT_CALL)
end

--! inline
function _CONCAT_CALL_SAFE_REC(vm)
	_RUN_START(vm, vm.plume.sops.CONCAT_CALL_SAFE)
end