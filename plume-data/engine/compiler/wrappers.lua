--[[This file is part of Plume  
  
Plume🪶 is free software: you can redistribute it and/or modify  
it under the terms of the GNU General Public License as published by  
the Free Software Foundation, version 3 of the License.  
  
Plume🪶 is distributed in the hope that it will be useful,  
but WITHOUT ANY WARRANTY; without even the implied warranty of  
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  
See the GNU General Public License for more details.  
  
You should have received a copy of the GNU General Public License along with Plume🪶.  
If not, see <https://www.gnu.org/licenses/>.  
]]  
  
return function (plume, context)
    --- Initialize an accumulation table
    --- @return nil
    function context.accTableInit(node)  
        context.registerOP(node, plume.ops.BEGIN_ACC, 0, 0)
    end 

    --- Wrapper for accumulation block. Initialize accumulator and finalize the block.
    --- Accumulation block doesn't have its own scope.
    --- depending of its type.
    --- @param f|nil function Function used to process children. Default to context.childrenHandler 
    --- @return function
    function context.accBlock(f)  
        f = f or context.childrenHandler

        --- @param node node
        --- @param label|nil string Used to jump at block end, but before finalizer.
        --- @return nil
        return function (node, label)  
            if node.type == "TEXT" then
                context.accBlockDeep = context.accBlockDeep + 1
                context.toggleConcatOn()
                context.registerOP(node, plume.ops.BEGIN_ACC, 0, 0)  
                f(node)  
                if label then  
                    context.registerLabel(node, label)  
                end  
                context.registerOP(nil, plume.ops.CONCAT_TEXT, 0, 0)
                context.accBlockDeep = context.accBlockDeep - 1
            else  
                context.toggleConcatOff()
                -- More or less a TEXT block with 1 element.
                -- Don't use ACC_TEXT to prevent conversion to string
                if node.type == "VALUE" then  
                    f(node)  
                    if label then  
                        context.registerLabel(node, label)  
                    end  
                -- Handled by block in most cases  
                elseif node.type == "TABLE" then  
                    context.accTableInit(node)
                    context.accBlockDeep = context.accBlockDeep + 1
                    f(node)  
                    if label then  
                        context.registerLabel(node, label)  
                    end  
                    context.registerOP(nil, plume.ops.CONCAT_TABLE, 0, 0)
                    context.accBlockDeep = context.accBlockDeep - 1
                -- Exactly same behavior as BEGIN_ACC (nothing) ACC_TEXT
                elseif node.type == "EMPTY" then  
                    f(node)  
                    if label then  
                        context.registerLabel(node, label)  
                    end  
                    context.registerOP(nil, plume.ops.LOAD_EMPTY, 0, 0)  
                end  
            end  
            context.toggleConcatPop()
        end          
    end  
    
    --- Enter a new scope, optionally registering local variable declarations.
    --- Generates a unique ID and registers a label for upvalue management.
    --- @param lets number|nil Number of local variables to declare in this scope (0 if nil)
    --- @param isFile boolean It is the file scope? Used to load params
    function context.enterScope(lets, isFile)
        if lets then
            context.registerOP(nil, plume.ops.ENTER_SCOPE, 0, lets)
        else
            -- Each macro open a scope, but it is handled by plume.run
        end

        if isFile then
            context.registerOP(nil, plume.ops.FILE_INIT_PARAMS)
        end

        local uid = context.getUID()
        -- Used to open upvalues
        context.registerLabel(node, "scope_begin_" .. uid)

        table.insert(context.scopes, {})
        table.insert(context.scopesUp, {uid=uid})
    end

    --- Leave the current scope, cleaning up upvalues and optionally registering LEAVE_SCOPE operation.
    --- Removes the top scope from the stack and manages associated upvalues.
    --- @param includeOP boolean|nil If true, registers the LEAVE_SCOPE operation
    function context.leaveScope(includeOP)
        context.manageUpvalues(table.remove(context.scopesUp))
        context.emiVariablesUsageWarning(table.remove(context.scopes))
        
        if includeOP then
            context.registerOP(nil, plume.ops.LEAVE_SCOPE, 0, 0)
        else
            -- For macro, LEAVE_SCOPE is handled by RETURN
        end
        
    end

    --- Wrapper for scope.
    --- Scope isn't created without local variable declaration.
    --- @param f|nil function Function used to process children. Default to context.childrenHandler 
    --- @param internVar|nil number
    --- @return function
    function context.scope(f, internVar)  
        f = f or context.childrenHandler  
        return function (node)  
            local lets = context.countLocals(node) + (internVar or 0)
            if lets>0 then  
                context.enterScope(lets)
                f(node)  
                context.leaveScope(true)
                
            else  
                f(node)  
            end  
        end          
    end  
    
    --- Wrapper for file
    --- @param f|nil function Function used to process children. Default to context.childrenHandler 
    --- @return function
    function context.file(f)  
        f = f or context.childrenHandler
        return function (node)  
            table.insert(context.roots, #context.scopes+1)  
            f(node)  
            table.remove(context.roots)  
        end          
    end  
end