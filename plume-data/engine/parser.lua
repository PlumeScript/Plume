--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]
-- Pure-Lua parser for Plume : no external parser library, no FFI.
--
-- Hand-written recursive-descent parser for the Plume grammar :
-- first matching alternative wins, with backtracking, byte-identical nodes
-- (name, bpos, epos, content, children, warning/fields). It runs identically
-- on LuaJIT 5.1 (native) and Lua 5.4 (wasm) — deterministic everywhere,
-- no external parser dependency.
--
-- Contract :
--   - plume.parse(code, filename) is the public entry point
--   - the AST goes through the post-passes (plume.parsePostProcess)
--
-- Every rule below implements the grammar, in order.
-- A rule returns a list of capture values (nodes — in this grammar every
-- capture is transformed into a node table, there are no raw scalar values)
-- on success and leaves the cursor at the end of the match, or nil on
-- failure (the cursor is restored by the `try` helper).

return function (plume)

	local escapeList = plume.escapeList

	-- ---------------------------------------------------------------------
	-- Node builders
	-- ---------------------------------------------------------------------
	local function nodeC(name, bpos, content)
		return { name = name, bpos = bpos, epos = bpos + #content - 1, content = content }
	end
	local function nodeCt(name, bpos, epos, children)
		return { name = name, bpos = bpos, epos = epos, children = children }
	end
	local function nodeE(handler, bpos, epos, content)
		local node = { name = "Error", bpos = bpos, epos = epos, content = content }
		node.error = handler
		return node
	end
	local function nodeEt(handler, bpos, epos)
		local node = { name = "Error", bpos = bpos, epos = epos }
		node.error = handler
		return node
	end

	local WARN_UNNEC_EVAL = "Unnecessary `$` prefix inside eval mode `$(...)`."
	local HINT_UNNEC_EVAL = "Everything inside is already evaluated. Extra `$` is allowed for convenience, though not required."

	-- ---------------------------------------------------------------------
	-- The parser proper
	-- ---------------------------------------------------------------------
	local function parseAST(code)
		local n = #code
		local pos = 1
		local pcode = code .. "\0\0\0"

		-- ----- low-level helpers -----
		local function at(s, p)
			return code:find(s, p or pos, true) == (p or pos)
		end
		local function at2(s, p)
			return code:find(s, p, true) == p
		end
		-- byte read that degrades to 0 (a non-matching sentinel) past EOF,
		-- so comparison-based rules fail cleanly.
		-- `pcode` is padded with NULs so the read never returns nil.
		local function cb(p)
			return pcode:byte(p)
		end
		local function isIdentStart(b)
			return (b >= 97 and b <= 122) or (b >= 65 and b <= 90) or b == 95
		end
		-- byte-identity checks for the 2/3-char markers (hot path)
		local function atSL(p) -- "//"
			return cb(p) == 47 and cb(p + 1) == 47
		end
		local function atBL(p) -- "/*"
			return cb(p) == 47 and cb(p + 1) == 42
		end
		local function atDots(p) -- "..."
			return cb(p) == 46 and cb(p + 1) == 46 and cb(p + 2) == 46
		end
		local function isIdentChar(b)
			return isIdentStart(b) or (b >= 48 and b <= 57)
		end
		-- _idns : [a-zA-Z_][a-zA-Z0-9_]* — returns the word and the position
		-- of the FIRST character after it (the next cursor).
		local function scanIdent(p)
			local b = cb(p)
			if not isIdentStart(b) then return nil, p end
			local i = p + 1
			while i <= n and isIdentChar(cb(i)) do i = i + 1 end
			return code:sub(p, i - 1), i
		end
		-- K(x) : keyword — the word, then a char that is not [a-zA-Z_]
		local function kw(w, p)
			local p0 = p or pos
			if cb(p0) ~= w:byte(1) then return false end
			if not at(w, p0) then return false end
			local b = cb(p0 + #w)
			return b == nil or not isIdentStart(b)
		end
		local function skipOS(p)
			local noarg = p == nil
			if noarg then p = pos end
			local i = p
			while i <= n do
				local b = cb(i)
				if b == 32 or b == 9 then i = i + 1 else break end
			end
			if noarg then pos = i end
			return i
		end
		local function skipOS1()
			local i = skipOS(pos)
			if i == pos then return false end
			pos = i
			return true
		end

		local function try(f)
			local save = pos
			local v = f()
			if v == nil then pos = save end
			return v
		end

		-- (NOT(S"\n")^0) : the default pattern of the E() helpers — the rest
		-- of the line (newline not included).
		local function restOfLine()
			local i = pos
			while i <= n and cb(i) ~= 10 do i = i + 1 end
			return code:sub(pos, i - 1), i - 1, i
		end

		-- commentNL (no capture) : `//` to end of line, `/*` to `*/`
		local function skipCommentNL(p)
			if atSL(p) then
				local i = p + 2
				while i <= n and cb(i) ~= 10 do i = i + 1 end
				return i
			elseif atBL(p) then
				local i = code:find("*/", p + 2, true)
				if not i then return nil end
				return i + 2
			end
			return nil
		end

		-- ----- atoms (common) -----
		-- lt : (os * S"\n")^1 * os — LINESTART node
		local function r_lt()
			local bpos = pos
			local i = pos
			local count = 0
			while i <= n do
				local j = skipOS(i)
				if cb(j) == 10 then
					i = j + 1
					count = count + 1
				else
					break
				end
			end
			if count == 0 then return nil end
			i = skipOS(i)
			pos = i
			return { nodeC("LINESTART", bpos, code:sub(bpos, i - 1)) }
		end

		local function r_num()
			local b = cb(pos)
			if not (b >= 48 and b <= 57) then return nil end
			local bpos = pos
			local i = bpos
			while i <= n do
				local c = cb(i)
				if c >= 48 and c <= 57 then i = i + 1 else break end
			end
			if cb(i) == 46 and cb(i + 1) and cb(i + 1) >= 48 and cb(i + 1) <= 57 then
				i = i + 1
				while i <= n and cb(i) >= 48 and cb(i) <= 57 do i = i + 1 end
			end
			pos = i
			return { nodeC("NUMBER", bpos, code:sub(bpos, i - 1)) }
		end

		local function r_name()
			local t, e = scanIdent(pos)
			if not t then return nil end
			pos = e
			return { nodeC("NAME", pos - #t, t) }
		end

		local function r_idns()
			local t, e = scanIdent(pos)
			if not t then return nil end
			pos = e
			return { nodeC("IDENTIFIER", pos - #t, t) }
		end

		-- idn : TRUE / FALSE / EMPTY / IDENTIFIER (K + anti-identifier)
		local function r_idn()
			local bpos = pos
			if kw("true", bpos) then pos = bpos + 4 return { nodeC("TRUE", bpos, "true") } end
			if kw("false", bpos) then pos = bpos + 5 return { nodeC("FALSE", bpos, "false") } end
			if kw("empty", bpos) then pos = bpos + 5 return { nodeC("EMPTY", bpos, "empty") } end
			return r_idns()
		end

		local function unknownEscape(node)
			local s = node.content:sub(2, 2)
			plume.error.unknownEscapeSequence(node, s)
		end

		-- escaped : the escapeList in order, then `\` + any char (Error node)
		local function r_escaped()
			local b = cb(pos)
			if b ~= 92 then return nil end
			local bpos = pos
			for i = 1, #escapeList do
				local src = escapeList[i][1]
				if at(src, bpos) then
					pos = bpos + #src
					return { nodeC("SPECIAL_TEXT", bpos, src) }
				end
			end
			if not code:byte(bpos + 1) then return nil end
			pos = bpos + 2
			return { nodeE(unknownEscape, bpos, bpos + 1, code:sub(bpos, bpos + 1)) }
		end

		-- quote : `"`…`"` or `'`…`'` — QUOTE node of TEXT/ESCAPED children
		local function r_quote()
			local q = cb(pos)
			if q ~= 34 and q ~= 39 then return nil end
			local bpos = pos
			local i = pos + 1
			local children = {}
			while true do
				local b = code:byte(i)
				if b == q then
					i = i + 1
					break
				end
				if not b then return nil end
				if b == 92 then
					if not code:byte(i + 1) then return nil end
					children[#children + 1] = nodeC("ESCAPED", i + 1, code:sub(i + 1, i + 1))
					i = i + 2
				else
					local j = i
					while j <= n do
						local c = cb(j)
						if c == q or c == 92 then break end
						j = j + 1
					end
					children[#children + 1] = nodeC("TEXT", i, code:sub(i, j - 1))
					i = j
				end
			end
			pos = i
			return { nodeCt("QUOTE", bpos + 1, i - 2, children) }
		end

		-- ----- forward declarations (mutual recursion) -----
		local r_expr, r_exprNL, r_eval, r_evalBase, r_lineeval
		local r_mainIndex, r_mainDirectIndex, r_mainEvalop, r_call, r_mainArg
		local r_mainInlinetable, r_mainExpandArg, r_namedArg, r_textic
		local r_blockName, r_blockTarget, r_blockStart, r_blockCallEOL
		local r_inlineBlockStart, r_texticb, r_texticbContent, r_rawtexticb
		local r_comment, r_text, r_textns, r_textnc, r_textnp
		local r_condition, r_body, r_end, r_if, r_while, r_for
		local r_macro, r_nMacroStart, r_aMacroStart, r_param, r_paramlist
		local r_paramDefaultValue, r_texticbGuard
		local r_let, r_set, r_letsetvar, r_setvar, r_letsetdefaut
		local r_letvarlist, r_setvarlist, r_compound, r_lbody, r_lbodynlb
		local r_firstStatement, r_firstStatementNLB, r_statement
		local r_command, r_commandStd, r_commandLB
		local r_listitem, r_hashitem, r_expand, r_do, r_use, r_raw, r_with
		local r_leave, r_return, r_break, r_continue
		local r_foreignKeyword, r_fakeAffectation, r_ref
		local r_blockNameRaw, r_forInd, r_iterator

		-- -----------------------------------------------------------------
		-- ALU : precedence climbing
		-- `skipWS` selects the accepted whitespace (spaces/tabs for plain
		-- expressions, plus newlines and comments for `$(...)`).
		-- -----------------------------------------------------------------
		local function makeALU(skipWS)
			local r_layer1, r_layer2, r_layer3, r_layer4, r_layer5, r_layer6, r_layer7, r_layer8

			local function foldBin(items)
				local ast = items[1]
				for i = 2, #items, 2 do
					local operator = items[i]
					local right = items[i + 1]
					ast = {
						name = operator.name,
						bpos = ast.bpos,
						epos = right.epos,
						children = { ast, right }
					}
				end
				return ast
			end

			local function foldUn(ops, operand)
				local ast = operand
				for i = #ops, 1, -1 do
					local operator = ops[i]
					ast = {
						name = operator.name,
						bpos = operator.bpos,
						epos = ast.epos,
						children = { ast }
					}
				end
				return ast
			end

			local function r_safeidn()
				if cb(pos) == 36 then
					local save = pos
					pos = pos + 1 -- W(P"$") consumed, idn starts after it
					local v = r_idn()
					if v == nil then pos = save return nil end
					v[1].warning = WARN_UNNEC_EVAL
					v[1].warningHint = HINT_UNNEC_EVAL
					v[1].issues = { 547 }
					v[1].bpos = save
					return v
				end
				return r_idn()
			end

			local function r_optnarg()
				local bpos = pos
				local key
				if cb(pos) == 36 then
					local kpos = pos
					local v = try(r_layer1)
					if v == nil then return nil end
					key = { nodeCt("DYNAMIC_KEY", kpos, pos - 1, { nodeCt("EVAL", kpos, pos - 1, v) }) }
				else
					local v = r_name()
					if v == nil then return nil end
					key = v
				end
				skipWS()
				if cb(pos) ~= 58 then return nil end
				pos = pos + 1
				skipWS()
				local bbody = pos
				local v = try(r_layer1)
				local epos = pos - 1
				local children = {}
				for i = 1, #key do children[#children + 1] = key[i] end
				children[#children + 1] = nodeCt("BODY", bbody, epos, v or {})
				return { nodeCt("HASH_ITEM", bpos, epos, children) }
			end

			local function r_posarg()
				local bpos = pos
				local v = r_layer1()
				if v == nil then return nil end
				return { nodeCt("LIST_ITEM", bpos, pos - 1, v) }
			end

			local function r_flagCall()
				skipWS()
				local bpos = pos
				if cb(pos) ~= 63 then return nil end
				pos = pos + 1
				local v = r_name()
				if v == nil then return nil end
				local epos = pos - 1
				local node = nodeCt("FLAG", bpos, epos, v)
				node.name = "HASH_ITEM"
				node.isFlag = true
				node.children[#node.children + 1] = nodeCt("BODY", bpos, epos, {
					nodeCt("EVAL", bpos, epos, { { name = "TRUE", bpos = bpos, epos = epos } })
				})
				return { node }
			end

			local function r_expandArg()
				if not atDots(pos) then return nil end
				local bpos = pos
				pos = pos + 3
				local epos0 = pos
				local v = r_layer1()
				if v == nil then return nil end
				return { nodeCt("EXPAND", bpos, pos - 1, { nodeCt("EVAL", epos0, pos - 1, v) }) }
			end

			local function r_arg()
				local v = try(r_optnarg)
				if v then return v end
				v = try(r_posarg)
				if v then return v end
				v = try(r_flagCall)
				if v then return v end
				v = try(r_expandArg)
				if v then return v end
				local bpos = pos
				return { nodeCt("LIST_ITEM", bpos, bpos - 1, { nodeC("EMPTY", bpos, "") }) }
			end

			local function r_arglist()
				local bpos = pos
				if cb(pos) ~= 40 then return nil end
				local i = pos + 1
				if cb(i) == 41 then
					pos = i + 1
					return { nodeCt("CALL", bpos, i, {}) }
				end
				pos = pos + 1 -- P"(" is consumed before `arg`
				local v = r_arg()
				if v == nil then return nil end
				local children = {}
				for i = 1, #v do children[#children + 1] = v[i] end
				while true do
					local save = pos
					skipWS()
					if cb(pos) == 44 then
						pos = pos + 1
						skipWS()
						local v2 = r_arg()
						if v2 == nil then return nil end
						for i = 1, #v2 do children[#children + 1] = v2[i] end
					else
						pos = save
						break
					end
				end
				if cb(pos) ~= 41 then return nil end
				pos = pos + 1
				return { nodeCt("CALL", bpos, pos - 1, children) }
			end

			local function r_index()
				local bpos = pos
				if cb(pos) ~= 91 then return nil end
				pos = pos + 1
				local v = r_layer1()
				if v == nil then return nil end
				if cb(pos) ~= 93 then return nil end
				pos = pos + 1
				if cb(pos) == 63 then
					pos = pos + 1
					return { nodeCt("SAFE_INDEX", bpos, pos - 1, v) }
				end
				return { nodeCt("INDEX", bpos, pos - 1, v) }
			end

			local function r_directindex()
				local bpos = pos
				if cb(pos) ~= 46 then return nil end
				pos = pos + 1
				local v = r_idn()
				if v == nil then return nil end
				if cb(pos) == 63 then
					pos = pos + 1
					return { nodeCt("SAFE_DIRECT_INDEX", bpos, pos - 1, v) }
				end
				return { nodeCt("DIRECT_INDEX", bpos, pos - 1, v) }
			end

			local function r_inlinetable()
				local bpos = pos
				if cb(pos) ~= 40 then return nil end
				pos = pos + 1
				local save = pos
				local v = r_arg()
				if v then
					local kids = {}
					for i = 1, #v do kids[#kids + 1] = v[i] end
					local ncomp = 0
					while true do
						local s = pos
						skipWS()
						if cb(pos) == 44 then
							pos = pos + 1
							skipWS()
							local v2 = r_arg()
							if v2 == nil then ncomp = -1 break end
							for i = 1, #v2 do kids[#kids + 1] = v2[i] end
							ncomp = ncomp + 1
						else
							pos = s
							break
						end
					end
					if ncomp >= 1 and cb(pos) == 41 then
						pos = pos + 1
						return { nodeCt("INLINE_TABLE", bpos, pos - 1, kids) }
					end
					pos = save
				end
				v = try(r_optnarg)
				if v and cb(pos) == 41 then
					pos = pos + 1
					return { nodeCt("INLINE_TABLE", bpos, pos - 1, v) }
				end
				v = try(r_expandArg)
				if v and cb(pos) == 41 then
					pos = pos + 1
					return { nodeCt("INLINE_TABLE", bpos, pos - 1, v) }
				end
				return nil
			end

			local function r_evalop()
				local v = try(r_arglist)
				if v then return v end
				v = try(r_index)
				if v then return v end
				return r_directindex()
			end

			local function r_primary()
				local v = try(r_num)
				if v then return v end
				v = try(r_safeidn)
				if v then return v end
				v = try(r_quote)
				if v then return v end
				v = try(r_inlinetable)
				if v then return v end
				if cb(pos) == 40 then
					local save = pos
					pos = pos + 1
					local v2 = r_layer1()
					if v2 == nil then return nil end
					if cb(pos) ~= 41 then return nil end
					pos = pos + 1
					return v2
				end
				return nil
			end

			local function r_access()
				local bpos = pos
				local v = r_primary()
				if v == nil then return nil end
				local children = {}
				for i = 1, #v do children[#children + 1] = v[i] end
				local count = 0
				while true do
					local save = pos
					local v2 = r_evalop()
					if v2 == nil then pos = save break end
					for i = 1, #v2 do children[#children + 1] = v2[i] end
					count = count + 1
				end
				if count == 0 then return nil end
				return { nodeCt("EVAL", bpos, pos - 1, children) }
			end

			local function matchCmp(p)
				local b = cb(p)
				if b == 61 then
					if cb(p + 1) == 61 then return { "EQ", "==" } end
				elseif b == 33 then
					if cb(p + 1) == 61 then return { "NEQ", "!=" } end
				elseif b == 60 then
					if cb(p + 1) == 61 then return { "LTE", "<=" } end
					return { "LT", "<" }
				elseif b == 62 then
					if cb(p + 1) == 61 then return { "GTE", ">=" } end
					return { "GT", ">" }
				end
				return nil
			end
			local function matchAddSub(p)
				local b = cb(p)
				if b == 43 then return { "ADD", "+" }
				elseif b == 45 then return { "SUB", "-" }
				elseif b == 46 and cb(p + 1) == 46 then return { "CONCAT", ".." }
				end
				return nil
			end
			local function matchMulDiv(p)
				local b = cb(p)
				if b == 42 then return { "MUL", "*" }
				elseif b == 47 then return { "DIV", "/" }
				elseif b == 37 then return { "MOD", "%" }
				end
				return nil
			end

			-- binary layer helper : Ct(V(next) * (ws rule ws V(next))^0) / fold_bin
			-- `nextLayer` is a getter (the layers are mutually recursive and are
			-- forward-declared: the getter resolves the local at call time).
			local function binLayer(matcher, nextLayer)
				local function r()
					local save = pos
					local v = nextLayer()()
					if v == nil then return nil end
					local items = { v[1] }
					while true do
						local s = pos
						skipWS()
						local op = matcher(pos)
						if op then
							local opb = pos
							pos = pos + #op[2]
							skipWS()
							local v2 = nextLayer()()
							if v2 == nil then pos = s break end
							items[#items + 1] = nodeC(op[1], opb, op[2])
							items[#items + 1] = v2[1]
						else
							pos = s
							break
						end
					end
					return { foldBin(items) }
				end
				return r
			end

			-- unary layer helper : Ct(ws * (rule * ws)^0 * V(next)) / fold_un
			local function unLayer(isOp, opNode, nextLayer)
				local function r()
					local save = pos
					skipWS()
					local ops = {}
					while true do
						if isOp() then
							table.insert(ops, opNode())
							skipWS()
						else
							break
						end
					end
					local v = nextLayer()()
					if v == nil then pos = save return nil end
					return { foldUn(ops, v[1]) }
				end
				return r
			end

			r_layer1 = binLayer(function(p)
				if kw("or", p) then return { "OR", "or" } end
				return nil
			end, function() return r_layer2 end)

			r_layer2 = binLayer(function(p)
				if kw("and", p) then return { "AND", "and" } end
				return nil
			end, function() return r_layer3 end)

			r_layer3 = unLayer(function() return kw("not", pos) end,
				function()
					local opb = pos
					pos = pos + 3
					return nodeC("NOT", opb, "not")
				end, function() return r_layer4 end)

			r_layer4 = binLayer(matchCmp, function() return r_layer5 end)
			r_layer5 = binLayer(matchAddSub, function() return r_layer6 end)
			r_layer6 = binLayer(matchMulDiv, function() return r_layer7 end)

			r_layer7 = unLayer(function() return cb(pos) == 45 end,
				function()
					local opb = pos
					pos = pos + 1
					return nodeC("NEG", opb, "-")
				end, function() return r_layer8 end)

			-- Bottom level (`^`) : the base is an access/primary (NOT the unary
			-- level — `-5^2` is `-(5^2)`, issue #1299), the exponent keeps the
			-- unary level (`2^-3` is `2^(-3)`).
			r_layer8 = function()
				local save = pos
				skipWS()
				-- operand = ws * (access + primary) * ws : the choice backtracks to
				-- the position before `access` (a primary without evalop is not an
				-- `access`, `primary` is restarted from the same position).
				local base = try(r_access)
				if not base then base = try(r_primary) end
				if base == nil then pos = save return nil end
				skipWS()
				local items = { base[1] }
				while true do
					local s = pos
					skipWS()
					local w = pos
					if cb(w) == 94 then
						local opb = pos
						pos = pos + 1
						skipWS()
						local exp = r_layer7()
						if exp == nil then pos = s break end
						items[#items + 1] = nodeC("POW", opb, "^")
						items[#items + 1] = exp[1]
					else
						pos = s
						break
					end
				end
				return { foldBin(items) }
			end

			-- expr / exprNL : Ct("EXPR", V"_layer1")
			local function r_expr()
				local bpos = pos
				local v = r_layer1()
				if v == nil then return nil end
				return { nodeCt("EXPR", bpos, pos - 1, v) }
			end

			return r_expr
		end

		-- `ws` for plain expressions : spaces/tabs only
		local function skipWSPlain() return skipOS() end
		-- `ws` for `$(...)` : spaces/tabs/newlines, with comments between tokens
		-- (comments are consumed, never captured — issue #1283)
		local function skipWSNL()
			while true do
				skipOS()
				local i = pos
				while i <= n do
					local b = cb(i)
					if b == 32 or b == 9 or b == 10 then i = i + 1 else break end
				end
				pos = i
				local e = skipCommentNL(pos)
				if not e then return pos end
				pos = e
			end
		end

		r_expr = makeALU(skipWSPlain)
		r_exprNL = makeALU(skipWSNL)

		-- -----------------------------------------------------------------
		-- eval & index (main section)
		-- -----------------------------------------------------------------
		-- evalBase : Ct("EVAL", (P"(" * (exprNL + E(emptyExpr)) *
		--            (P")" + E(missingClosingBracket)) + idn + num)
		--            * V"evalOpperator"^0
		r_evalBase = function()
			local bpos = pos
			local children = {}
			local ok = false
			if cb(pos) == 40 then
				pos = pos + 1
				local v = r_exprNL()
				if v then
					children[#children + 1] = v[1]
				else
					local content, epos, i = restOfLine()
					children[#children + 1] = nodeE(plume.error.emptyExpr, bpos + 1, epos, content)
					pos = i
				end
				if cb(pos) == 41 then
					pos = pos + 1
				else
					local content, epos, i = restOfLine()
					children[#children + 1] = nodeE(plume.error.missingClosingBracket, pos, epos, content)
					pos = i
				end
				ok = true
			else
				local v = r_idn()
				if not v then v = r_num() end
				if v then
					children[#children + 1] = v[1]
					ok = true
				end
			end
			if not ok then return nil end
			while true do
				local save = pos
				local v = r_mainEvalop()
				if v == nil then pos = save break end
				for i = 1, #v do children[#children + 1] = v[i] end
			end
			return { nodeCt("EVAL", bpos, pos - 1, children) }
		end

		r_eval = function()
			if cb(pos) ~= 36 then return nil end
			pos = pos + 1
			return r_evalBase()
		end

		r_lineeval = function()
			if not (cb(pos) == 36 and cb(pos + 1) == 32) then return nil end
			pos = pos + 2
			local bpos = pos
			local v = r_expr()
			if v == nil then return nil end
			return { nodeCt("EVAL", bpos, pos - 1, v) }
		end

		r_mainIndex = function()
			local bpos = pos
			if cb(pos) ~= 91 then return nil end
			pos = pos + 1
			local v = r_expr()
			if v == nil then return nil end
			if cb(pos) ~= 93 then return nil end
			pos = pos + 1
			if cb(pos) == 63 then
				pos = pos + 1
				return { nodeCt("SAFE_INDEX", bpos, pos - 1, v) }
			end
			return { nodeCt("INDEX", bpos, pos - 1, v) }
		end

		r_mainDirectIndex = function()
			local bpos = pos
			if cb(pos) ~= 46 then return nil end
			pos = pos + 1
			local v = r_idn()
			if v == nil then return nil end
			if cb(pos) == 63 then
				pos = pos + 1
				return { nodeCt("SAFE_DIRECT_INDEX", bpos, pos - 1, v) }
			end
			return { nodeCt("DIRECT_INDEX", bpos, pos - 1, v) }
		end

		-- -----------------------------------------------------------------
		-- calls & args (main section)
		-- -----------------------------------------------------------------
		r_call = function()
			local bpos = pos
			if cb(pos) ~= 40 then return nil end
			local i = pos + 1
			if cb(i) == 41 then
				pos = i + 1
				return { nodeCt("CALL", bpos, i, {}) }
			end
			pos = pos + 1
			skipOS()
			local v = r_mainArg()
			if v == nil then return nil end
			local children = {}
			for i = 1, #v do children[#children + 1] = v[i] end
			while true do
				local save = pos
				skipOS()
				if cb(pos) == 44 then
					pos = pos + 1
					skipOS()
					local v2 = r_mainArg()
					if v2 == nil then return nil end
					for i = 1, #v2 do children[#children + 1] = v2[i] end
				else
					pos = save
					break
				end
			end
			-- closingPar = os * (P")" + E(missingClosingBracketArgList))
			skipOS()
			if cb(pos) == 41 then
				pos = pos + 1
			else
				local content, epos, i = restOfLine()
				children[#children + 1] = nodeE(plume.error.missingClosingBracketArgList, pos, epos, content)
				pos = i
			end
			return { nodeCt("CALL", bpos, pos - 1, children) }
		end

		-- Trim the whitespace-only boundary TEXT nodes of an argument textic:
		-- around an argument value, surrounding whitespace is syntax (after
		-- `(` / `,`, before `,` / `)`), not content (#1303). Without it, a
		-- trailing space after a bare eval (`$f($t , b)`) turns the argument
		-- into a text block and CHECK_IS_TEXT crashes on non-text values.
		-- Inner whitespace (between children) is content and stays.
		local function trimArgTextic(kids)
			if not kids or #kids == 0 then return kids end
			local function trimStart(node)
				local t = node.content:gsub("^%s+", "")
				if t == "" then return false end
				node.content = t
				node.epos = node.bpos + #t - 1
				return true
			end
			local function trimEnd(node)
				local t = node.content:gsub("%s+$", "")
				if t == "" then return false end
				node.content = t
				node.epos = node.bpos + #t - 1
				return true
			end
			if #kids == 1 then
				local node = kids[1]
				if node.name == "TEXT" and (not trimStart(node) or not trimEnd(node)) then
					kids[1] = nil
				end
			else
				local first = kids[1]
				if first.name == "TEXT" and not trimStart(first) then
					table.remove(kids, 1)
				end
				local last = kids[#kids]
				if last.name == "TEXT" and not trimEnd(last) then
					table.remove(kids, #kids)
				end
			end
			return kids
		end

		r_namedArg = function()
			local save = pos
			local bpos = pos
			local kids = {}
			-- (E(cannotUseRef, K"ref") * s)^-1
			if kw("ref") then
				local eb = pos
				pos = pos + 3
				kids[#kids + 1] = nodeE(plume.error.cannotUseRef, eb, eb + 2, "ref")
				if not skipOS1() then pos = save return nil end
			end
			-- Ct("HASH_ITEM", os * (name + Ct("DYNAMIC_KEY", eval)) * os * P":"
			--    * os * Ct("BODY", (V"inlinetable" + V"textic")^-1))
			skipOS()
			local key
			if cb(pos) == 36 then
				local kpos = pos
				local v = r_eval()
				if v == nil then return nil end
				key = { nodeCt("DYNAMIC_KEY", kpos, pos - 1, { v[1] }) }
			else
				local v = r_name()
				if v == nil then return nil end
				key = v
			end
			skipOS()
			if cb(pos) ~= 58 then return nil end
			pos = pos + 1
			skipOS()
			local bbody = pos
			local v = try(r_mainInlinetable)
			if not v then v = trimArgTextic(r_textic()) end
			local epos = pos - 1
			for i = 1, #key do kids[#kids + 1] = key[i] end
			kids[#kids + 1] = nodeCt("BODY", bbody, epos, v or {})
			return { nodeCt("HASH_ITEM", bpos, epos, kids) }
		end

		r_mainArg = function()
			local v = try(r_namedArg)
			if v then return v end
			-- digit fast path : only the textic LIST_ITEM branch can match
			-- (no name, no `ref`, no `?`, no `...`, no `(`)
			local b0 = cb(pos)
			if b0 >= 48 and b0 <= 57 then
				local bpos = pos
				local v2 = r_textic()
				if v2 then return { nodeCt("LIST_ITEM", bpos, pos - 1, trimArgTextic(v2)) } end
			end
			-- E(cannotUseRef, K"ref") * s * name
			if kw("ref") then
				local bpos = pos
				pos = pos + 3
				local kids = { nodeE(plume.error.cannotUseRef, bpos, bpos + 2, "ref") }
				if not skipOS1() then return nil end
				local v2 = r_name()
				if v2 == nil then return nil end
				kids[#kids + 1] = v2[1]
				return kids
			end
			-- sugarFlagCall(Ct("FLAG", os *"?"*name))
			local save = pos
			skipOS()
			if cb(pos) == 63 then
				local bpos = pos
				pos = pos + 1
				local v = r_name()
				if v == nil then pos = save return nil end
				local epos = pos - 1
				local node = nodeCt("FLAG", bpos, epos, v)
				node.name = "HASH_ITEM"
				node.isFlag = true
				node.children[#node.children + 1] = nodeCt("BODY", bpos, epos, {
					nodeCt("EVAL", bpos, epos, { { name = "TRUE", bpos = bpos, epos = epos } })
				})
				return { node }
			end
			pos = save
			v = try(r_mainExpandArg)
			if v then return v end
			-- Ct("LIST_ITEM", V"inlinetable")
			local bpos = pos
			v = try(r_mainInlinetable)
			if v then return { nodeCt("LIST_ITEM", bpos, pos - 1, v) } end
			-- Ct("LIST_ITEM", V"textic")
			bpos = pos
			v = r_textic()
			if v then return { nodeCt("LIST_ITEM", bpos, pos - 1, trimArgTextic(v)) } end
			-- Ct("LIST_ITEM", Ct("EMPTY", os))
			bpos = pos
			skipOS()
			return { nodeCt("LIST_ITEM", bpos, pos - 1, { nodeC("EMPTY", bpos, code:sub(bpos, pos - 1)) }) }
		end

		r_mainEvalop = function()
			local v = try(r_call)
			if v then return v end
			v = try(r_mainIndex)
			if v then return v end
			return r_mainDirectIndex()
		end

		-- inlinetable (main) : Ct("INLINE_TABLE", os * P"(" *
		--   (arg * (P"," * os * arg)^1 + namedArg + expandArg) * P")")
		r_mainInlinetable = function()
			local save = pos
			skipOS()
			if cb(pos) ~= 40 then return nil end
			local bpos = save
			pos = pos + 1
			-- alternative 1 : arg * (P"," * os * arg)^1
			local s1 = pos
			local v = r_mainArg()
			if v then
				local kids = {}
				for i = 1, #v do kids[#kids + 1] = v[i] end
				local ncomp = 0
				while true do
					local s = pos
					if cb(pos) == 44 then
						pos = pos + 1
						skipOS()
						local v2 = r_mainArg()
						if v2 == nil then ncomp = -1 break end
						for i = 1, #v2 do kids[#kids + 1] = v2[i] end
						ncomp = ncomp + 1
					else
						pos = s
						break
					end
				end
				if ncomp >= 1 and cb(pos) == 41 then
					pos = pos + 1
					return { nodeCt("INLINE_TABLE", bpos, pos - 1, kids) }
				end
				pos = s1
			end
			-- alternative 2 : namedArg
			v = try(r_namedArg)
			if v and cb(pos) == 41 then
				pos = pos + 1
				return { nodeCt("INLINE_TABLE", bpos, pos - 1, v) }
			end
			-- alternative 3 : expandArg
			v = try(r_mainExpandArg)
			if v and cb(pos) == 41 then
				pos = pos + 1
				return { nodeCt("INLINE_TABLE", bpos, pos - 1, v) }
			end
			return nil
		end

		r_mainExpandArg = function()
			if not atDots(pos) then return nil end
			local bpos = pos
			pos = pos + 3
			local v = r_evalBase()
			if v == nil then return nil end
			return { nodeCt("EXPAND", bpos, pos - 1, v) }
		end

		-- -----------------------------------------------------------------
		-- blocks
		-- -----------------------------------------------------------------
		-- blockName : idn * (index + directindex)^0
		r_blockName = function()
			local v = r_idn()
			if v == nil then return nil end
			local children = { v[1] }
			while true do
				local save = pos
				local v2 = try(r_mainIndex)
				if not v2 then v2 = r_mainDirectIndex() end
				if v2 == nil then pos = save break end
				for i = 1, #v2 do children[#children + 1] = v2[i] end
			end
			return children
		end

		-- blockNameRaw : capture-free mirror of blockName (lookahead only)
		r_blockNameRaw = function()
			local t, e = scanIdent(pos)
			if not t then return nil end
			pos = e
			while true do
				local save = pos
				if cb(pos) == 91 then
					pos = pos + 1
					local v = r_expr()
					if v and cb(pos) == 93 then
						pos = pos + 1
					else
						pos = save
						break
					end
				elseif cb(pos) == 46 then
					local t2, e2 = scanIdent(pos + 1)
					if t2 then
						pos = e2
					else
						pos = save
						break
					end
				else
					break
				end
			end
			return pos
		end

		-- blockTarget : blockName + P"(" * (exprNL + E(emptyExpr)) *
		--               (P")" + E(missingClosingBracket))
		r_blockTarget = function()
			local v = r_blockName()
			if v then return v end
			if cb(pos) == 40 then
				pos = pos + 1
				local kids = {}
				local v2 = r_exprNL()
				if v2 then
					kids[#kids + 1] = v2[1]
				else
					local content, epos, i = restOfLine()
					kids[#kids + 1] = nodeE(plume.error.emptyExpr, pos, epos, content)
					pos = i
				end
				if cb(pos) == 41 then
					pos = pos + 1
				else
					local content, epos, i = restOfLine()
					kids[#kids + 1] = nodeE(plume.error.missingClosingBracket, pos, epos, content)
					pos = i
				end
				return kids
			end
			return nil
		end

		-- blockStart : Ct("EVAL", P"@" * blockTarget * os *
		--   Ct("BLOCK_CALL", call^-1 * os * (Ct("BODY", V"blockStart") + body)))
		r_blockStart = function()
			if cb(pos) ~= 64 then return nil end
			local bpos = pos
			pos = pos + 1
			local target = r_blockTarget()
			if target == nil then return nil end
			local kids = {}
			for i = 1, #target do kids[#kids + 1] = target[i] end
			skipOS()
			local bcall = pos
			local bcallKids = {}
			local v = try(r_call)
			if v then
				for i = 1, #v do bcallKids[#bcallKids + 1] = v[i] end
			end
			skipOS()
			local bodyKids
			local save = pos
			local v2 = try(r_blockStart)
			if v2 then
				bodyKids = { nodeCt("BODY", save, pos - 1, v2) }
			else
				pos = save
				bodyKids = r_body()
			end
			local epos = pos - 1
			for i = 1, #bodyKids do bcallKids[#bcallKids + 1] = bodyKids[i] end
			kids[#kids + 1] = nodeCt("BLOCK_CALL", bcall, epos, bcallKids)
			return { nodeCt("EVAL", bpos, epos, kids) }
		end

		-- _end : lt * K"end" + E(missingEnd) — if the keyword is missing the
		-- whole first alternative backtracks (the LINESTART is not consumed)
		-- and the E node sits at the choice position.
r_end = function()
			local save = pos
			local v = r_lt()
			if v and kw("end") then
				pos = pos + 3
				return v
			end
			pos = save
			local content, epos, i = restOfLine()
			return { nodeE(plume.error.missingEnd, pos, epos, content) }
		end

		-- block : blockStart * Ct("NULL", _end)
		local function r_block()
			local v = r_blockStart()
			if v == nil then return nil end
			local kids = { v[1] }
			local bnull = pos
			local e = r_end()
			kids[#kids + 1] = nodeCt("NULL", bnull, pos - 1, e)
			return kids
		end

		-- inlineBlockStart : Ct("EVAL", P"@" * blockName * os *
		--   Ct("BLOCK_CALL", call^-1 * os * Ct("BODY", V"texticb")))
		r_inlineBlockStart = function()
			if cb(pos) ~= 64 then return nil end
			local bpos = pos
			pos = pos + 1
			local target = r_blockName()
			if target == nil then return nil end
			local kids = {}
			for i = 1, #target do kids[#kids + 1] = target[i] end
			skipOS()
			local bcall = pos
			local bcallKids = {}
			local v = try(r_call)
			if v then
				for i = 1, #v do bcallKids[#bcallKids + 1] = v[i] end
			end
			skipOS()
			local bbody = pos
			local v2 = r_texticb()
			if v2 == nil then return nil end
			local epos = pos - 1
			bcallKids[#bcallKids + 1] = nodeCt("BODY", bbody, epos, v2)
			kids[#kids + 1] = nodeCt("BLOCK_CALL", bcall, epos, bcallKids)
			return { nodeCt("EVAL", bpos, epos, kids) }
		end

		-- blockCallEOL : Ct("EVAL", P"@" * blockName * os *
		--   Ct("BLOCK_CALL", call^-1 * os * guard * (Ct("BODY", V"blockStart") + body))
		--   * Ct("NULL", _end))
		-- guard = #(S"\n") + -P(1) + #(os * (P"//" + P"/*")) (zero-width)
		r_blockCallEOL = function()
			if cb(pos) ~= 64 then return nil end
			local bpos = pos
			pos = pos + 1
			local target = r_blockName()
			if target == nil then return nil end
			local kids = {}
			for i = 1, #target do kids[#kids + 1] = target[i] end
			skipOS()
			local bcall = pos
			local bcallKids = {}
			local v = try(r_call)
			if v then
				for i = 1, #v do bcallKids[#bcallKids + 1] = v[i] end
			end
			skipOS()
			local g = cb(pos)
			local guardok = false
			if g == 10 then
				guardok = true
			elseif g == nil then
				guardok = true
			else
				local i = skipOS(pos)
				if atSL(i) or atBL(i) then
					guardok = true
				end
			end
			if not guardok then return nil end
			local bodyKids
			local save = pos
			local v2 = try(r_blockStart)
			if v2 then
				bodyKids = { nodeCt("BODY", save, pos - 1, v2) }
			else
				pos = save
				bodyKids = r_body()
			end
			local epos = pos - 1
			for i = 1, #bodyKids do bcallKids[#bcallKids + 1] = bodyKids[i] end
			kids[#kids + 1] = nodeCt("BLOCK_CALL", bcall, epos, bcallKids)
			local v3 = r_end()
			kids[#kids + 1] = nodeCt("NULL", epos + 1, pos - 1, v3)
			return { nodeCt("EVAL", bpos, pos - 1, kids) }
		end

		-- -----------------------------------------------------------------
		-- text
		-- -----------------------------------------------------------------
		-- comment : os * ( P"//" * os * C("COMMENT", NOT(S"\n")^0)
		--           + (P"/*" * os * Cp() * C((P(1)-P"*/")^0) * P"*/" * Cp()) )
		-- One COMMENT node for `/* ... */` covering the delimiters (issue #1289).
		r_comment = function()
			local save = pos
			skipOS()
			if atSL(pos) then
				pos = pos + 2
				skipOS()
				local bpos = pos
				local i = pos
				while i <= n and cb(i) ~= 10 do i = i + 1 end
				pos = i
				return { nodeC("COMMENT", bpos, code:sub(bpos, i - 1)) }
			elseif atBL(pos) then
				local i = skipOS(pos + 2)
				local bpos = i
				local j = code:find("*/", bpos, true)
				if not j then pos = save return nil end
				pos = j + 2
				return { { name = "COMMENT", bpos = bpos, epos = j + 1, content = code:sub(bpos, j - 1) } }
			end
			pos = save
			return nil
		end

		-- rawtext : C("TEXT", NOT(os * S"\n" + S"$\\" + P"@" + os * (P"//" + P"/*"))^1)
		local function r_rawtext()
			local bpos = pos
			local i = pos
			while i <= n do
				local b = cb(i)
				if b == 36 or b == 92 or b == 64 then break end
				if b == 10 then break end -- os (zero-width) * S"\n"
				if b == 32 or b == 9 then
					local j = skipOS(i)
					if cb(j) == 10 or atSL(j) or atBL(j) then break end
				elseif b == 47 then
					local j = skipOS(i)
					if atSL(j) or atBL(j) then break end
				end
				i = i + 1
			end
			if i == bpos then return nil end
			pos = i
			return { nodeC("TEXT", bpos, code:sub(bpos, i - 1)) }
		end

		-- rawtextns : NOT(S"$\n\\" + P"@" + P"//" + P"/*" + s)^1
		local function r_rawtextns()
			local bpos = pos
			local i = pos
			while i <= n do
				local b = cb(i)
				if b == 36 or b == 92 or b == 10 or b == 64 or b == 32 or b == 9 then break end
				if b == 47 and (cb(i + 1) == 47 or cb(i + 1) == 42) then break end
				i = i + 1
			end
			if i == bpos then return nil end
			pos = i
			return { nodeC("TEXT", bpos, code:sub(bpos, i - 1)) }
		end

		-- rawtextnc : NOT(S"$\n,\\" + P"@" + P"//" + P"/*" + s)^1
		local function r_rawtextnc()
			local bpos = pos
			local i = pos
			while i <= n do
				local b = cb(i)
				if b == 36 or b == 92 or b == 10 or b == 44 or b == 64 or b == 32 or b == 9 then break end
				if b == 47 and (cb(i + 1) == 47 or cb(i + 1) == 42) then break end
				i = i + 1
			end
			if i == bpos then return nil end
			pos = i
			return { nodeC("TEXT", bpos, code:sub(bpos, i - 1)) }
		end

		-- rawtextnp : NOT(S"$\n)\\" + P"@" + P"//" + P"/*")^1
		local function r_rawtextnp()
			local bpos = pos
			local i = pos
			while i <= n do
				local b = cb(i)
				if b == 36 or b == 92 or b == 10 or b == 41 or b == 64 then break end
				if b == 47 and (cb(i + 1) == 47 or cb(i + 1) == 42) then break end
				i = i + 1
			end
			if i == bpos then return nil end
			pos = i
			return { nodeC("TEXT", bpos, code:sub(bpos, i - 1)) }
		end

		-- rawtextic : NOT(S"$\n,()\\" + P"@" + P"//" + P"/*")^1
		local function r_rawtextic()
			local bpos = pos
			local i = pos
			while i <= n do
				local b = cb(i)
				if b == 36 or b == 92 or b == 10 or b == 44 or b == 40 or b == 41 or b == 64 then break end
				if b == 47 and (cb(i + 1) == 47 or cb(i + 1) == 42) then break end
				i = i + 1
			end
			if i == bpos then return nil end
			pos = i
			return { nodeC("TEXT", bpos, code:sub(bpos, i - 1)) }
		end

		-- rawtexticb : NOT(os * S"\n" + S"$\\" + os * (P"//" + P"/*")
		--   + P"@" * blockNameRaw * (os * S"\n" + -P(1) + s + P"("))^1
		r_rawtexticb = function()
			local bpos = pos
			local i = pos
			while i <= n do
				local b = cb(i)
				if b == 36 or b == 92 then break end
				if b == 10 then break end -- os (zero-width) * S"\n"
				if b == 32 or b == 9 then
					local j = skipOS(i)
					if cb(j) == 10 or atSL(j) or atBL(j) then break end
				elseif b == 47 then
					local j = skipOS(i)
					if atSL(j) or atBL(j) then break end
				elseif b == 64 then
					-- @blockNameRaw followed by (os*newline | end of input | s | "(")
					local save = pos
					local e = r_blockNameRaw()
					if e then
						local ok2 = false
						local j = skipOS(pos)
						if cb(j) == 10 then
							ok2 = true
						elseif j > n then
							ok2 = true
						elseif cb(pos) == 32 or cb(pos) == 9 then
							ok2 = true
						elseif cb(pos) == 40 then
							ok2 = true
						end
						if ok2 then
							pos = save
							break
						end
					end
					pos = save
				end
				i = i + 1
			end
			if i == bpos then return nil end
			pos = i
			return { nodeC("TEXT", bpos, code:sub(bpos, i - 1)) }
		end

		-- texteval : eval + inlineBlockStart + blockCallEOL
		--           + E(nonEscapedEvalMark, P"$") + E(nonEscapedBlockMark, P"@")
		local function r_texteval()
			local v = try(r_eval)
			if v then return v end
			v = try(r_inlineBlockStart)
			if v then return v end
			v = try(r_blockCallEOL)
			if v then return v end
			if cb(pos) == 36 then
				local b = pos
				pos = pos + 1
				return { nodeE(plume.error.nonEscapedEvalMark, b, b, "$") }
			end
			if cb(pos) == 64 then
				local b = pos
				pos = pos + 1
				return { nodeE(plume.error.nonEscapedBlockMark, b, b, "@") }
			end
			return nil
		end

		-- text : (escaped + lineeval + texteval + comment + rawtext)^1
		local function rep1(choice)
			local bpos = pos
			local kids = {}
			while true do
				local save = pos
				local v = choice()
				if v == nil then
					pos = save
					break
				end
				for i = 1, #v do kids[#kids + 1] = v[i] end
			end
			if #kids == 0 then return nil end
			return kids
		end

		r_text = function()
			return rep1(function()
				-- first-byte gate : a plain char can only be rawtext (no escaped,
				-- no lineeval, no texteval, no comment can start with it)
				local b = cb(pos)
				if b == 32 or b == 9 then
					-- ws may start a comment (comment = os * (// + /*)) : comment
					-- precedes rawtext in the choice order
					local j = skipOS(pos)
					if atSL(j) or atBL(j) then
						return r_comment()
					end
					return r_rawtext()
				end
				if b ~= 10 and b ~= 36 and b ~= 92 and b ~= 64
					and not (b == 47 and (cb(pos + 1) == 47 or cb(pos + 1) == 42)) then
					return r_rawtext()
				end
				local v = try(r_escaped)
				if not v then v = try(r_lineeval) end
				if not v then v = r_texteval() end
				if not v then v = r_comment() end
				if not v then v = r_rawtext() end
				return v
			end)
		end

		-- textns : (escaped + texteval + comment + rawtextns)^1
		r_textns = function()
			return rep1(function()
				local b = cb(pos)
				if b ~= 32 and b ~= 9 and b ~= 10 and b ~= 36 and b ~= 92 and b ~= 64
					and not (b == 47 and (cb(pos + 1) == 47 or cb(pos + 1) == 42)) then
					return r_rawtextns()
				end
				local v = try(r_escaped)
				if not v then v = r_texteval() end
				if not v then v = r_comment() end
				if not v then v = r_rawtextns() end
				return v
			end)
		end

		-- textnc : (escaped + texteval + comment + rawtextnc)^1
		r_textnc = function()
			return rep1(function()
				local b = cb(pos)
				if b ~= 32 and b ~= 9 and b ~= 10 and b ~= 36 and b ~= 92 and b ~= 64 and b ~= 44
					and not (b == 47 and (cb(pos + 1) == 47 or cb(pos + 1) == 42)) then
					return r_rawtextnc()
				end
				local v = try(r_escaped)
				if not v then v = r_texteval() end
				if not v then v = r_comment() end
				if not v then v = r_rawtextnc() end
				return v
			end)
		end

		-- textnp : (escaped + texteval + comment + rawtextnp)^1
		r_textnp = function()
			return rep1(function()
				local b = cb(pos)
				if b == 32 or b == 9 then
					-- ws may start a comment (comment = os * (// + /*)) : comment
					-- precedes rawtextnp in the choice order
					local j = skipOS(pos)
					if atSL(j) or atBL(j) then
						return r_comment()
					end
					return r_rawtextnp()
				end
				if b ~= 10 and b ~= 36 and b ~= 92 and b ~= 64 and b ~= 41
					and not (b == 47 and (cb(pos + 1) == 47 or cb(pos + 1) == 42)) then
					return r_rawtextnp()
				end
				local v = try(r_escaped)
				if not v then v = r_texteval() end
				if not v then v = r_comment() end
				if not v then v = r_rawtextnp() end
				return v
			end)
		end

		-- (used by textic / asMacroic / paramDefaultValue / namedArg)
		-- asMacroic & aMacroStart are defined below (macro section) — forward
		-- references are resolved at call time.
		local r_asMacroic

		-- textic : asMacroic + (escaped + texteval + comment
		--   + C("TEXT", P"(") * V"textic"^-1 * C("TEXT", P")") + rawtextic)^1
		r_textic = function()
			local v = try(r_asMacroic)
			if v then return v end
			local kids = {}
			while true do
				local save = pos
				local b = cb(pos)
				local w
				if b == 32 or b == 9 then
					-- ws may start a comment (comment = os * (// + /*)) : comment
					-- precedes rawtextic in the choice order
					local j = skipOS(pos)
					if atSL(j) or atBL(j) then
						w = r_comment()
					else
						w = r_rawtextic()
					end
				elseif b ~= 10 and b ~= 36 and b ~= 92 and b ~= 64
					and b ~= 40 and b ~= 41 and b ~= 44
					and not (b == 47 and (cb(pos + 1) == 47 or cb(pos + 1) == 42)) then
					w = r_rawtextic()
				else
					w = try(r_escaped)
					if not w then w = r_texteval() end
					if not w then w = r_comment() end
					if w == nil and b == 40 then
					-- C("TEXT", P"(") * V"textic"^-1 * C("TEXT", P")")
					-- : BOTH parentheses are required (a lone `)` is NOT consumed)
					local b = pos
					pos = b + 1
					local inner = r_textic()
					if cb(pos) == 41 then
						local kids2 = { nodeC("TEXT", b, "(") }
						if inner then
							for i = 1, #inner do kids2[#kids2 + 1] = inner[i] end
						end
						kids2[#kids2 + 1] = nodeC("TEXT", pos, ")")
						pos = pos + 1
						w = kids2
					else
						pos = save
					end
				end
				end
				if w == nil then
					pos = save
					break
				end
				for i = 1, #w do kids[#kids + 1] = w[i] end
			end
			if #kids == 0 then return nil end
			return kids
		end

		-- texticb : (V"comment")^0 * texticbContent * ((V"comment")^0 * texticbContent)^0
		--           * (V"comment")^0
		r_texticb = function()
			local kids = {}
			local function grabComments(dst)
				local got = false
				while true do
					local save = pos
					local v = r_comment()
					if v == nil then
						pos = save
						break
					end
					for i = 1, #v do dst[#dst + 1] = v[i] end
					got = true
				end
				return got
			end
			local tmp = {}
			grabComments(tmp)
			for i = 1, #tmp do kids[#kids + 1] = tmp[i] end
			local v = r_texticbContent()
			if v == nil then return nil end
			for i = 1, #v do kids[#kids + 1] = v[i] end
			while true do
				local save = pos
				tmp = {}
				grabComments(tmp)
				local v2 = r_texticbContent()
				if v2 == nil then
					pos = save
					break
				end
				for i = 1, #tmp do kids[#kids + 1] = tmp[i] end
				for i = 1, #v2 do kids[#kids + 1] = v2[i] end
			end
			tmp = {}
			grabComments(tmp)
			for i = 1, #tmp do kids[#kids + 1] = tmp[i] end
			return kids
		end

		-- texticbContent : inlineBlockStart + escaped + eval
		--   + E(nonEscapedEvalMark, P"$") + blockCallEOL + V"rawtexticb"
		r_texticbContent = function()
			local b0 = cb(pos)
			if b0 ~= 10 and b0 ~= 36 and b0 ~= 64 and b0 ~= 92 then
				return r_rawtexticb()
			end
			local v = try(r_inlineBlockStart)
			if v then return v end
			v = try(r_escaped)
			if v then return v end
			v = try(r_eval)
			if v then return v end
			if cb(pos) == 36 then
				local b = pos
				pos = pos + 1
				return { nodeE(plume.error.nonEscapedEvalMark, b, b, "$") }
			end
			v = try(r_blockCallEOL)
			if v then return v end
			return r_rawtexticb()
		end

		-- -----------------------------------------------------------------
		-- statements
		-- -----------------------------------------------------------------
		-- condition : s * Ct("CONDITION", expr) + E(missingCondition)
		r_condition = function()
			local save = pos
			if skipOS1() then
				local bpos = pos
				local v = r_expr()
				if v then
					return { nodeCt("CONDITION", bpos, pos - 1, v) }
				end
			end
			pos = save
			local content, epos, i = restOfLine()
			return { nodeE(plume.error.missingCondition, pos, epos, content) }
		end

		-- body : (os * V"comment")^-1 * Ct("BODY", V"statement"^0)
r_body = function()
			local save = pos
			local v = try(r_comment)
			if v then
				-- the leading comment is consumed, its value discarded
			end
			local bbody = pos
			local kids = {}
			while true do
				local st = r_statement()
				if st == nil then break end
				for i = 1, #st do kids[#kids + 1] = st[i] end
			end
			return { nodeCt("BODY", bbody, pos - 1, kids) }
		end

		-- if / elseif / else
		local function r_elseif()
			local v = r_lt()
			if v == nil then return nil end
			if not kw("elseif") then return nil end
			local bpos = pos - #v[1].content
			pos = pos + 6
			local kids = { v[1] }
			local c = r_condition()
			kids[#kids + 1] = c[1]
			local b = r_body()
			kids[#kids + 1] = b[1]
			return { nodeCt("ELSEIF", bpos, pos - 1, kids) }
		end

		local function r_else()
			local v = r_lt()
			if v == nil then return nil end
			if not kw("else") then return nil end
			local bpos = pos - #v[1].content
			pos = pos + 4
			local kids = { v[1] }
			local b = r_body()
			kids[#kids + 1] = b[1]
			return { nodeCt("ELSE", bpos, pos - 1, kids) }
		end

r_if = function()
			if not kw("if") then return nil end
			local bpos = pos
			pos = pos + 2
			local kids = {}
			local c = r_condition()
			kids[#kids + 1] = c[1]
			local b = r_body()
			kids[#kids + 1] = b[1]
			while true do
				local v = try(r_elseif)
				if v == nil then break end
				kids[#kids + 1] = v[1]
			end
			local v = try(r_else)
			if v then kids[#kids + 1] = v[1] end
			local e = r_end()
			kids[#kids + 1] = e[1]
			return { nodeCt("IF", bpos, pos - 1, kids) }
		end

		-- macro & calls
		r_paramDefaultValue = function()
			local save = pos
			skipOS()
			if cb(pos) ~= 58 then return nil end
			pos = pos + 1
			skipOS()
			local bbody = pos
			local v = try(r_mainInlinetable)
			if not v then v = trimArgTextic(r_textic()) end
			local kids = v or {}
			local epos = pos - 1
			if #kids == 0 then
				-- V"textic"^-1 with zero content is still a BODY node
			end
			return { nodeCt("BODY", bbody, epos, kids) }
		end

		r_param = function()
			local bpos = pos
			-- sugarFlagParam(Ct("FLAG", "?"*name * Et(cannotSetFlagDefaultValue, paramDefaultValue)^-1))
			if cb(pos) == 63 then
				local fb = pos
				pos = pos + 1
				local v = r_name()
				if v == nil then return nil end
				local kids = v
				local save = pos
				local d = try(r_paramDefaultValue)
				if d then
					kids[#kids + 1] = nodeEt(plume.error.cannotSetFlagDefaultValue, save, pos - 1)
				else
					pos = save
				end
				local epos = pos - 1
				local node = nodeCt("FLAG", fb, epos, kids)
				node.name = "PARAM"
				node.isFlag = true
				node.children[#node.children + 1] = nodeCt("BODY", fb, epos, {
					nodeCt("EVAL", fb, epos, { { name = "FALSE", bpos = fb, epos = epos } })
				})
				return { node }
			end
			local kids = {}
			-- (C("VALIDATOR", _idns) * s)^-1
			local t, e = scanIdent(pos)
			if t then
				local b = cb(e)
				if b == 32 or b == 9 then
					kids[#kids + 1] = nodeC("VALIDATOR", pos, t)
					pos = skipOS(e)
				end
			end
			-- name * paramDefaultValue^-1  +  Ct("VARIADIC", P"..." * idn * Et(...)^-1)
			if atDots(pos) then
				local vb = pos
				pos = pos + 3
				local v = r_idns()
				if v == nil then return nil end
				local vkids = { v[1] }
				local save = pos
				local d = try(r_paramDefaultValue)
				if d then
					vkids[#vkids + 1] = nodeEt(plume.error.cannotSetVariadicDefaultValue, save, pos - 1)
				else
					pos = save
				end
				kids[#kids + 1] = nodeCt("VARIADIC", vb, pos - 1, vkids)
				return { nodeCt("PARAM", bpos, pos - 1, kids) }
			end
			local v = r_name()
			if v == nil then return nil end
			kids[#kids + 1] = v[1]
			local d = try(r_paramDefaultValue)
			if d then kids[#kids + 1] = d[1] end
			return { nodeCt("PARAM", bpos, pos - 1, kids) }
		end

		-- paramlist : Ct("PARAMLIST", P"(" * os * param^-1 *
		--   (os * P"," * (os * param + E(missingParam, os-param)))^0 * os * P")")
		r_paramlist = function()
			local bpos = pos
			if cb(pos) ~= 40 then return nil end
			pos = pos + 1
			skipOS()
			local kids = {}
			local v = try(r_param)
			if v then
				for i = 1, #v do kids[#kids + 1] = v[i] end
			end
			while true do
				local save = pos
				skipOS()
				if cb(pos) == 44 then
					pos = pos + 1
					local s2 = pos
					skipOS()
					local p = try(r_param)
					if p then
						for i = 1, #p do kids[#kids + 1] = p[i] end
					else
						-- E(missingParam, os * (-param))
						local eb = s2
						local ws = code:sub(s2, pos - 1)
						local s3 = pos
						local pp = r_param()
						if pp ~= nil then
							-- param matched : the whole choice fails
							return nil
						end
						pos = s3
						kids[#kids + 1] = nodeE(plume.error.missingParam, eb, pos - 1, ws)
					end
				else
					pos = save
					break
				end
			end
			skipOS()
			if cb(pos) ~= 41 then return nil end
			pos = pos + 1
			return { nodeCt("PARAMLIST", bpos, pos - 1, kids) }
		end

		-- nMacroStart : K"macro" * s * name * os * paramlist^-1 * os
		r_nMacroStart = function()
			if not kw("macro") then return nil end
			pos = pos + 5
			if not skipOS1() then return nil end
			local kids = {}
			local v = r_name()
			if v == nil then return nil end
			kids[#kids + 1] = v[1]
			skipOS()
			local v2 = try(r_paramlist)
			if v2 then
				for i = 1, #v2 do kids[#kids + 1] = v2[i] end
			end
			skipOS()
			return kids
		end

		-- aMacroStart : K"macro" * os * paramlist^-1 * os
		r_aMacroStart = function()
			if not kw("macro") then return nil end
			pos = pos + 5
			local kids = {}
			skipOS()
			local v = try(r_paramlist)
			if v then
				for i = 1, #v do kids[#kids + 1] = v[i] end
			end
			skipOS()
			return kids
		end

		-- lMacroBody = body * _end ; sMacroBody = Ct("BODY", V"firstStatement")
		-- sMacroBodyic = Ct("BODY", V"textic")
		local function r_lMacroBody()
			local b = r_body()
			local e = r_end()
			return { b[1], e[1] }
		end
		local function r_sMacroBody()
			local bbody = pos
			local st = r_firstStatement()
			if st == nil then return nil end
			return { nodeCt("BODY", bbody, pos - 1, st) }
		end
		local function r_sMacroBodyic()
			local bbody = pos
			local v = r_textic()
			if v == nil then return nil end
			return { nodeCt("BODY", bbody, pos - 1, v) }
		end

		-- macro : nsMacro + nlMacro + asMacro + alMacro
		r_macro = function()
			local save = pos
			-- nsMacro : nMacroStart * sMacroBody
			local kids = r_nMacroStart()
			if kids then
				local bbody = pos
				local sb = r_sMacroBody()
				if sb then
					local kids2 = {}
					for i = 1, #kids do kids2[#kids2 + 1] = kids[i] end
					kids2[#kids2 + 1] = sb[1]
					return { nodeCt("MACRO", save, pos - 1, kids2) }
				end
			end
			-- nlMacro : nMacroStart * lMacroBody
			pos = save
			kids = r_nMacroStart()
			if kids then
				local kids2 = {}
				for i = 1, #kids do kids2[#kids2 + 1] = kids[i] end
				local lb = r_lMacroBody()
				kids2[#kids2 + 1] = lb[1]
				kids2[#kids2 + 1] = lb[2]
				return { nodeCt("MACRO", save, pos - 1, kids2) }
			end
			-- asMacro : aMacroStart * sMacroBody
			pos = save
			kids = r_aMacroStart()
			if kids then
				local sb = r_sMacroBody()
				if sb then
					local kids2 = {}
					for i = 1, #kids do kids2[#kids2 + 1] = kids[i] end
					kids2[#kids2 + 1] = sb[1]
					return { nodeCt("ANONYMOUS_MACRO", save, pos - 1, kids2) }
				end
			end
			-- alMacro : aMacroStart * lMacroBody
			pos = save
			kids = r_aMacroStart()
			if kids then
				local kids2 = {}
				for i = 1, #kids do kids2[#kids2 + 1] = kids[i] end
				local lb = r_lMacroBody()
				kids2[#kids2 + 1] = lb[1]
				kids2[#kids2 + 1] = lb[2]
				return { nodeCt("ANONYMOUS_MACRO", save, pos - 1, kids2) }
			end
			pos = save
			return nil
		end

		r_asMacroic = function()
			local save = pos
			local kids = r_aMacroStart()
			if kids == nil then return nil end
			local sb = r_sMacroBodyic()
			if sb == nil then
				pos = save
				return nil
			end
			local kids2 = {}
			for i = 1, #kids do kids2[#kids2 + 1] = kids[i] end
			kids2[#kids2 + 1] = sb[1]
			return { nodeCt("ANONYMOUS_MACRO", save, pos - 1, kids2) }
		end

		-- affectations
r_lbody = function()
			local bbody = pos
			local st = r_firstStatement()
			if st == nil then return nil end
			return { nodeCt("BODY", bbody, pos - 1, st) }
		end
r_lbodynlb = function()
			local bbody = pos
			local st = r_firstStatementNLB()
			if st == nil then return nil end
			return { nodeCt("BODY", bbody, pos - 1, st) }
		end

		-- compound : Ct("COMPOUND", C("ADD","+") + C("SUB","-") + C("MUL","*")
		--            + C("DIV","/") + C("CONCAT",".."))
		r_compound = function()
			local b = cb(pos)
			local name, text
			if b == 43 then
				name, text = "ADD", "+"
			elseif b == 45 then
				name, text = "SUB", "-"
			elseif b == 42 then
				name, text = "MUL", "*"
			elseif b == 47 then
				name, text = "DIV", "/"
			elseif b == 46 and cb(pos + 1) == 46 then
				name, text = "CONCAT", ".."
			end
			if not name then return nil end
			local bpos = pos
			pos = pos + #text
			return { nodeCt("COMPOUND", bpos, pos - 1, { nodeC(name, bpos, text) }) }
		end

		-- _letsetdefaut : P":" * os * Ct("VALUE", (P"(" * V"textnp" * ")" + V"textns")^-1)
		r_letsetdefaut = function()
			if cb(pos) ~= 58 then return nil end
			pos = pos + 1
			skipOS()
			local bbody = pos
			local kids = {}
			local save = pos
			local got = false
			if cb(pos) == 40 then
				pos = pos + 1
				local v = r_textnp()
				if v and cb(pos) == 41 then
					for i = 1, #v do kids[#kids + 1] = v[i] end
					pos = pos + 1
					got = true
				end
			else
				local v = r_textns()
				if v then
					for i = 1, #v do kids[#kids + 1] = v[i] end
					got = true
				end
			end
			if not got then pos = save end
			return { nodeCt("VALUE", bbody, pos - 1, kids) }
		end

		-- letsetvar : ALIAS_DEFAULT + ALIAS + DEFAULT + name + VARIADIC
		r_letsetvar = function()
			local save = pos
			-- ALIAS_DEFAULT : name os K"as" os name os _letsetdefaut
			local v = r_name()
			if v then
				local kids = { v[1] }
				skipOS()
				if kw("as") then
					pos = pos + 2
					skipOS()
					local v2 = r_name()
					if v2 then
						kids[#kids + 1] = v2[1]
						skipOS()
						local d = r_letsetdefaut()
						if d then
							kids[#kids + 1] = d[1]
							return { nodeCt("ALIAS_DEFAULT", save, pos - 1, kids) }
						end
					end
				end
			end
			-- ALIAS : name os K"as" os name
			pos = save
			v = r_name()
			if v and skipOS() and kw("as") then
				pos = pos + 2
				skipOS()
				local v2 = r_name()
				if v2 then
					return { nodeCt("ALIAS", save, pos - 1, { v[1], v2[1] }) }
				end
			end
			-- DEFAULT : name os _letsetdefaut
			pos = save
			v = r_name()
			if v then
				local kids = { v[1] }
				skipOS()
				local d = r_letsetdefaut()
				if d then
					kids[#kids + 1] = d[1]
					return { nodeCt("DEFAULT", save, pos - 1, kids) }
				end
			end
			-- name
			pos = save
			v = r_name()
			if v then return v end
			-- VARIADIC : P"..." * name * (os * K"as" * os * Ct("ALIAS", name))^-1
			if atDots(pos) then
				local vb = pos
				pos = pos + 3
				local v2 = r_name()
				if v2 then
					local vkids = { v2[1] }
					local s2 = pos
					skipOS()
					if kw("as") then
						pos = pos + 2
						skipOS()
						local bal = pos
						local v3 = r_name()
						if v3 then
							vkids[#vkids + 1] = nodeCt("ALIAS", bal, pos - 1, v3)
						end
					end
					return { nodeCt("VARIADIC", vb, pos - 1, vkids) }
				end
			end
			pos = save
			return nil
		end

		-- setvar : Ct("SETINDEX", (name * V"evalOpperator"^1)) + letsetvar
		r_setvar = function()
			local save = pos
			local v = r_name()
			if v then
				local kids = { v[1] }
				local count = 0
				while true do
					local s = pos
					local v2 = r_mainEvalop()
					if v2 == nil then pos = s break end
					for i = 1, #v2 do kids[#kids + 1] = v2[i] end
					count = count + 1
				end
				if count > 0 then
					return { nodeCt("SETINDEX", save, pos - 1, kids) }
				end
			end
			pos = save
			return r_letsetvar()
		end

		-- letvarlist / setvarlist : Ct("VARLIST", var * (os * P"," * os * var
		--   + E(missingValue, P","))^0)
		local function varlist(varRule, name)
			return function()
				local bpos = pos
				local v = varRule()
				if v == nil then return nil end
				local kids = {}
				for i = 1, #v do kids[#kids + 1] = v[i] end
				while true do
					local save = pos
					local s = pos
					skipOS()
					if cb(pos) == 44 then
						pos = pos + 1
						skipOS()
						local v2 = varRule()
						if v2 then
							for i = 1, #v2 do kids[#kids + 1] = v2[i] end
						else
							-- E(missingValue, P",") at the iteration start
							pos = s
							local eb = pos
							if cb(pos) == 44 then
								pos = pos + 1
								kids[#kids + 1] = nodeE(plume.error.missingValue, eb, eb, ",")
							else
								break
							end
						end
					else
						pos = save
						break
					end
				end
				return { nodeCt("VARLIST", bpos, pos - 1, kids) }
			end
		end
		r_letvarlist = varlist(r_letsetvar)
		r_setvarlist = varlist(r_setvar)

		-- let : Ct("LET", K"let" * (statconst * s * letvarlist *
		--   (os * E(letCompound, P"+"+"-"+"/"+"*")^-1 * P"=" * lbody
		--    + s * C("FROM", K"from") * s * lbody)^-1 + E(emptyLet)))
		local function statconstPart(kids)
			local s2 = pos
			if skipOS1() and kw("const") then
				local cp = pos
				pos = pos + 5
				kids[#kids + 1] = nodeC("CONST", cp, "const")
			else
				pos = s2
			end
			s2 = pos
			if skipOS1() and kw("param") then
				local cp = pos
				pos = pos + 5
				kids[#kids + 1] = nodeC("PARAM", cp, "param")
			else
				pos = s2
			end
		end

		local function emptyLet()
			local content, epos, i = restOfLine()
			return { nodeE(plume.error.emptyLet, pos, epos, content) }
		end

r_let = function()
			if not kw("let") then return nil end
			local bpos = pos
			pos = pos + 3
			local save = pos
			local kids = {}
			statconstPart(kids)
			if not skipOS1() then
				pos = save
				local el = emptyLet()
				return { nodeCt("LET", bpos, pos - 1, el) }
			end
			local vl = r_letvarlist()
			if vl == nil then
				pos = save
				local el = emptyLet()
				return { nodeCt("LET", bpos, pos - 1, el) }
			end
			kids[#kids + 1] = vl[1]
			-- (A + B)^-1 : optional value part
			local valKids = {}
			local sA = pos
			-- A : os * E(letCompound, P"+"+"-"+"/"+"*")^-1 * P"=" * lbody
			skipOS()
			local c = cb(pos)
			if c == 43 or c == 45 or c == 47 or c == 42 then
				valKids[#valKids + 1] = nodeE(plume.error.letCompound, pos, pos, code:sub(pos, pos))
				pos = pos + 1
				c = cb(pos)
			end
			local got = false
			if c == 61 then
				local sp = pos
				pos = sp + 1
				local lb = r_lbody()
				if lb then
					valKids[#valKids + 1] = lb[1]
					got = true
				else
					pos = sp
				end
			end
			if not got then
				pos = sA
				valKids = {}
				-- B : s * C("FROM", K"from") * s * lbody
				local sB = pos
				if skipOS1() and kw("from") then
					local fb = pos
					pos = pos + 4
					valKids[#valKids + 1] = nodeC("FROM", fb, "from")
					if skipOS1() then
						local lb = r_lbody()
						if lb then
							valKids[#valKids + 1] = lb[1]
							got = true
						end
					end
				end
				if not got then pos = sB end
			end
			for i = 1, #valKids do kids[#kids + 1] = valKids[i] end
			return { nodeCt("LET", bpos, pos - 1, kids) }
		end

		-- set : Ct("SET", K"set" * s * setvarlist *
		--   (os * compound^-1 * P"=" * lbody + s * C("FROM", K"from") * s * lbody))
		r_set = function()
			if not kw("set") then return nil end
			local bpos = pos
			pos = pos + 3
			if not skipOS1() then return nil end
			local kids = {}
			local vl = r_setvarlist()
			if vl == nil then return nil end
			kids[#kids + 1] = vl[1]
			local valKids = {}
			local sA = pos
			-- A : os * compound^-1 * P"=" * lbody
			skipOS()
			local comp = r_compound()
			if comp then valKids[#valKids + 1] = comp[1] end
			local got = false
			if cb(pos) == 61 then
				local sp = pos
				pos = sp + 1
				local lb = r_lbody()
				if lb then
					valKids[#valKids + 1] = lb[1]
					got = true
				else
					pos = sp
				end
			end
			if not got then
				pos = sA
				valKids = {}
				-- B : s * C("FROM", K"from") * s * lbody
				local sB = pos
				if skipOS1() and kw("from") then
					local fb = pos
					pos = pos + 4
					valKids[#valKids + 1] = nodeC("FROM", fb, "from")
					if skipOS1() then
						local lb = r_lbody()
						if lb then
							valKids[#valKids + 1] = lb[1]
							got = true
						end
					end
				end
				if not got then
					pos = sA
					return nil
				end
			end
			for i = 1, #valKids do kids[#kids + 1] = valKids[i] end
			return { nodeCt("SET", bpos, pos - 1, kids) }
		end

		-- loops
		r_forInd = function()
			local v = r_letvarlist()
			if v then return v end
			-- E(missingLoopIndentifier) : handler is nil (never raised)
			local content, epos, i = restOfLine()
			return { nodeE(nil, pos, epos, content) }
		end

		r_iterator = function()
			local kids = {}
			local save = pos
			local ok = false
			if skipOS1() then
				local v = r_forInd()
				if v then
					for i = 1, #v do kids[#kids + 1] = v[i] end
					if skipOS1() and kw("in") then
						pos = pos + 2
						ok = true
					end
				end
			end
			if not ok then
				pos = save
				-- E(missingIteratorVariable, os * K"in")
				local eb = pos
				skipOS()
				if kw("in") then
					pos = pos + 2
					kids[#kids + 1] = nodeE(plume.error.missingIteratorVariable, eb, pos - 1, code:sub(eb, pos - 1))
				else
					return nil
				end
			end
			-- (s * Ct("ITERATOR", expr) + E(missingIterator))
			local save2 = pos
			local got = false
			if skipOS1() then
				local bpos = pos
				local v = r_expr()
				if v then
					kids[#kids + 1] = nodeCt("ITERATOR", bpos, pos - 1, v)
					got = true
				end
			end
			if not got then
				pos = save2
				local content, epos, i = restOfLine()
				kids[#kids + 1] = nodeE(plume.error.missingIterator, pos, epos, content)
			end
			return kids
		end

r_while = function()
			if not kw("while") then return nil end
			local bpos = pos
			pos = pos + 5
			local kids = {}
			local c = r_condition()
			kids[#kids + 1] = c[1]
			local b = r_body()
			kids[#kids + 1] = b[1]
			local e = r_end()
			kids[#kids + 1] = e[1]
			return { nodeCt("WHILE", bpos, pos - 1, kids) }
		end

r_for = function()
			if not kw("for") then return nil end
			local bpos = pos
			pos = pos + 3
			local kids = {}
			local it = r_iterator()
			if it == nil then return nil end
			for i = 1, #it do kids[#kids + 1] = it[i] end
			local b = r_body()
			kids[#kids + 1] = b[1]
			local e = r_end()
			kids[#kids + 1] = e[1]
			return { nodeCt("FOR", bpos, pos - 1, kids) }
		end

		r_break = function()
			if not kw("break") then return nil end
			local bpos = pos
			pos = pos + 5
			return { nodeC("BREAK", bpos, "break") }
		end

		r_continue = function()
			if not kw("continue") then return nil end
			local bpos = pos
			pos = pos + 8
			return { nodeC("CONTINUE", bpos, "continue") }
		end

		-- table
		-- ref : name * (s * K"as" * s * Ct("ALIAS", name))^-1
		r_ref = function()
			local v = r_name()
			if v == nil then return nil end
			local kids = { v[1] }
			local s = pos
			if skipOS1() and kw("as") then
				pos = pos + 2
				if skipOS1() then
					local bal = pos
					local v2 = r_name()
					if v2 then
						kids[#kids + 1] = nodeCt("ALIAS", bal, pos - 1, v2)
						return kids
					end
				end
			end
			pos = s
			return kids
		end
		-- listitem : Ct("LIST_ITEM", P"- " * os * V"firstStatementNLB" + P"-" * #lt)
		r_listitem = function()
			local bpos = pos
			if cb(pos) == 45 and cb(pos + 1) == 32 then
				pos = pos + 2
				skipOS()
				local st = r_firstStatementNLB()
				if st == nil then return nil end
				return { nodeCt("LIST_ITEM", bpos, pos - 1, st) }
			end
			if cb(pos) == 45 then
				-- #lt : (os * S"\n")^1 * os (zero-width)
				local i = pos + 1
				local count = 0
				while i <= n do
					local j = skipOS(i)
					if cb(j) == 10 then
						i = j + 1
						count = count + 1
					else
						break
					end
				end
				if count > 0 then
					pos = pos + 1
					return { nodeCt("LIST_ITEM", bpos, pos - 1, {}) }
				end
			end
			return nil
		end

		-- hashitem : 3 alternatives
		r_hashitem = function()
			local save = pos
			local bpos = save
			-- alternative 1 : (Ct("META", K"meta"*s)^-1 * (name + Ct("DYNAMIC_KEY", eval))
			--                  * P":" * (os * lbodynlb + #lt))
			do
				local kids = {}
				if kw("meta") then
					local mb = pos
					pos = pos + 4
					local i = skipOS(pos)
					if i > pos then
						kids[#kids + 1] = nodeCt("META", mb, i - 1, {})
						pos = i
					else
						pos = save
					end
				end
				local keyNodes
				if cb(pos) == 36 then
					local kpos = pos
					local v = r_eval()
					if v then
						keyNodes = { nodeCt("DYNAMIC_KEY", kpos, pos - 1, { v[1] }) }
					end
				else
					local v = r_name()
					if v then keyNodes = v end
				end
				if keyNodes and cb(pos) == 58 then
					pos = pos + 1
					for i = 1, #keyNodes do kids[#kids + 1] = keyNodes[i] end
					local s2 = pos
					pos = skipOS(pos) -- os consumed before the BODY capture
					local v = r_lbodynlb()
					if v then
						kids[#kids + 1] = v[1]
						return { nodeCt("HASH_ITEM", bpos, pos - 1, kids) }
					end
					-- #lt (zero-width)
					pos = s2
					local i = skipOS(pos)
					local count = 0
					while i <= n do
						local j = skipOS(i)
						if cb(j) == 10 then
							i = j + 1
							count = count + 1
						else
							break
						end
					end
					if count > 0 then
						return { nodeCt("HASH_ITEM", bpos, pos - 1, kids) }
					end
				end
			end
			-- alternative 2 : Ct("HASH_ITEM", Ct("REF", K"ref"*s) * ref * P":" * os * lbodynlb)
			-- (collects every capture : REF node then the name/alias nodes)
			do
				pos = save
				if kw("ref") then
					local rb = pos
					pos = pos + 3
					local i2 = skipOS(pos)
					if i2 > pos then
						pos = i2
						local refKids = r_ref()
						if refKids and cb(pos) == 58 then
							pos = pos + 1
							pos = skipOS(pos) -- os consumed before the BODY capture
							local v2 = r_lbodynlb()
							if v2 then
								local kids2 = { nodeCt("REF", rb, i2 - 1, {}) }
								for i = 1, #refKids do kids2[#kids2 + 1] = refKids[i] end
								kids2[#kids2 + 1] = v2[1]
								return { nodeCt("HASH_ITEM", save, pos - 1, kids2) }
							end
						end
					end
				end
			end
			-- alternative 3 : Ct("EMPTY_REF", Ct("REF", K"ref"*s) * ref)
			--                  * (os * P"," * os * Ct("EMPTY_REF", ref))^0
			do
				pos = save
				if kw("ref") then
					local rb = pos
					pos = pos + 3
					local i2 = skipOS(pos)
					if i2 > pos then
						pos = i2
						local refKids = r_ref()
						if refKids then
							local kids3 = { nodeCt("REF", rb, i2 - 1, {}) }
							for i = 1, #refKids do kids3[#kids3 + 1] = refKids[i] end
							local all = { nodeCt("EMPTY_REF", rb, pos - 1, kids3) }
							while true do
								local s = pos
								skipOS()
								if cb(pos) == 44 then
									pos = pos + 1
									skipOS()
									local rkStart = pos
									local rk = r_ref()
									if rk == nil then
										pos = s
										break
									end
									all[#all + 1] = nodeCt("EMPTY_REF", rkStart, pos - 1, rk)
								else
									pos = s
									break
								end
							end
							return all
						end
					end
				end
			end
			pos = save
			return nil
		end
		-- expand : Ct("EXPAND", P"..." * (block + evalBase))
		r_expand = function()
			if not atDots(pos) then return nil end
			local bpos = pos
			pos = pos + 3
			local v = r_block()
			if not v then v = r_evalBase() end
			if v == nil then return nil end
			return { nodeCt("EXPAND", bpos, pos - 1, v) }
		end

		-- do
r_do = function()
			local save = pos
			skipOS()
			if not kw("do") then return nil end
			local bpos = save
			pos = pos + 2
			local kids = {}
			local b = r_body()
			kids[#kids + 1] = b[1]
			local e = r_end()
			kids[#kids + 1] = e[1]
			return { nodeCt("DO", bpos, pos - 1, kids) }
		end

		-- use : K"use" * os * uselib * (os * P"," * os * uselib)^0
		local function r_uselibname()
			local bpos = pos
			local i = pos
			if cb(i) == 35 then i = i + 1 end
			while i <= n do
				local b = cb(i)
				if b == 44 or b == 10 or b == 40 or b == 41 or b == 58 then break end
				i = i + 1
			end
			pos = i
			return { nodeC("LIB_NAME", bpos, code:sub(bpos, i - 1)) }
		end

		local function r_uselibcall()
			local bpos = pos
			if cb(pos) ~= 40 then return nil end
			local i = pos + 1
			if cb(i) == 41 then
				pos = i + 1
				return {}
			end
			pos = pos + 1
			skipOS()
			local v = r_mainArg()
			if v == nil then return nil end
			local kids = {}
			for i = 1, #v do kids[#kids + 1] = v[i] end
			while true do
				local save = pos
				skipOS()
				if cb(pos) == 44 then
					pos = pos + 1
					skipOS()
					local v2 = r_mainArg()
					if v2 == nil then return nil end
					for i = 1, #v2 do kids[#kids + 1] = v2[i] end
				else
					pos = save
					break
				end
			end
			skipOS()
			if cb(pos) == 41 then
				pos = pos + 1
			else
				local content, epos, i = restOfLine()
				kids[#kids + 1] = nodeE(plume.error.missingClosingBracketArgList, pos, epos, content)
				pos = i
			end
			return kids
		end

		local function r_uselib()
			local bpos = pos
			local v = r_uselibname()
			if v == nil then return nil end
			local kids = { v[1] }
			local v2 = try(r_uselibcall)
			if v2 then
				for i = 1, #v2 do kids[#kids + 1] = v2[i] end
			end
			return { nodeCt("USE", bpos, pos - 1, kids) }
		end

		r_use = function()
			if not kw("use") then return nil end
			pos = pos + 3
			skipOS()
			local v = r_uselib()
			if v == nil then return nil end
			local kids = { v[1] }
			while true do
				local save = pos
				skipOS()
				if cb(pos) == 44 then
					pos = pos + 1
					skipOS()
					local v2 = r_uselib()
					if v2 == nil then return nil end
					kids[#kids + 1] = v2[1]
				else
					pos = save
					break
				end
			end
			return kids
		end

		-- raw : Ct("RAW", os * Cmt(K"raw" * C(P"["^0), handler))
		-- content = (P"\n" + -1) * (P(1) - closing)^0 ; closing = P"]"^n * P"end"
		r_raw = function()
			local save = pos
			skipOS()
			if not kw("raw") then return nil end
			local bpos = save
			pos = pos + 3
			local nb = 0
			while cb(pos) == 91 do
				nb = nb + 1
				pos = pos + 1
			end
			local cp = pos
			local c = cb(cp)
			local missingEndNode = function()
				return { nodeCt("RAW", bpos, n, { nodeE(plume.error.missingEnd, n + 1, n, "") }) }
			end
			if c ~= 10 then
				if cp > n then
					-- end of input : content = 0 chars, closing not found
					return missingEndNode()
				end
				-- not a newline and not end of input : content fails
				pos = save
				return nil
			end
			local closePos
			local i = cp
			while i <= n do
				if cb(i) == 93
					and nb > 0
					and code:sub(i, i + nb - 1) == string.rep("]", nb)
					and code:sub(i + nb, i + nb + 2) == "end" then
					closePos = i
					break
				elseif nb == 0 and code:sub(i, i + 2) == "end" then
					closePos = i
					break
				end
				i = i + 1
			end
			if not closePos then
				-- content consumed everything, closing not found
				return missingEndNode()
			end
			pos = closePos + nb + 3
			return { nodeCt("RAW", bpos, pos - 1, { nodeC("TEXT", cp, code:sub(cp, closePos - 1)) }) }
		end

		-- with : Ct("WITH", K"with" * (os * (Ct("PARAMLIST", inlinetable + eval))
		--         * body * _end + E(emptyWith)))
		r_with = function()
			if not kw("with") then return nil end
			local bpos = pos
			pos = pos + 4
			local save = pos
			local kids = {}
			local ok = false
			skipOS()
			local bpl = pos
			local v
			if cb(pos) == 40 then
				v = try(r_mainInlinetable)
			end
			if not v then
				v = r_eval()
			end
			if v then
				kids[#kids + 1] = nodeCt("PARAMLIST", bpl, pos - 1, v)
				local b = r_body()
				kids[#kids + 1] = b[1]
				local e = r_end()
				kids[#kids + 1] = e[1]
				ok = true
			end
			if not ok then
				pos = save
				local content, epos, i = restOfLine()
				kids = { nodeE(plume.error.emptyWith, pos, epos, content) }
				pos = i
			end
			return { nodeCt("WITH", bpos, pos - 1, kids) }
		end

		-- leave / return
		r_leave = function()
			if not kw("leave") then return nil end
			local bpos = pos
			pos = pos + 5
			return { nodeC("LEAVE", bpos, "leave") }
		end

		r_return = function()
			if not kw("return") then return nil end
			local bpos = pos
			pos = pos + 6
			local kids = {}
			local save = pos
			if skipOS1() then
				local st = r_firstStatement()
				if st then
					for i = 1, #st do kids[#kids + 1] = st[i] end
				else
					pos = save
				end
			end
			return { nodeCt("RETURN", bpos, pos - 1, kids) }
		end

		-- fakeAffectation : C("TEXT", ident * os * S"+-/*"^-1 * P"=") / handler
		r_fakeAffectation = function()
			local bpos = pos
			local t, e = scanIdent(bpos)
			if not t then return nil end
			local i = e
			while i <= n do
				local b = cb(i)
				if b == 32 or b == 9 then i = i + 1 else break end
			end
			local b = cb(i)
			if b == 43 or b == 45 or b == 42 or b == 47 then i = i + 1 end
			if cb(i) ~= 61 then return nil end
			pos = i + 1
			local content = code:sub(bpos, i)
			local node = { name = "TEXT", bpos = bpos, epos = i, content = content }
			node.warning = "This is plain text, not an assignement."
			if content:match('[%+%-%*%/]') then
				node.warningHint = string.format("Do you mean `set %s ...` ?", content)
			else
				node.warningHint = string.format("Do you mean `let %s ...` or `set %s ...` ?", content, content)
			end
			node.issues = { 381, 26 }
			return { node }
		end

		-- foreign keywords that would be silently treated as text, with their
		-- Plume equivalent (stable sorted order)
		local foreignKeywords = {
			["local"]    = "`let`",
			["function"] = "`macro`",
			["return"]   = "`leave`",
			["def"]      = "`macro`",
			["try"]      = "`attempt`",
			["except"]   = "`attempt`",
			["elif"]     = "`elseif`",
			["class"]    = "a table with metafields",
			["lambda"]   = "an anonymous `macro`",
			["var"]      = "`let`",
			["echo"]     = "`$print`",
			["puts"]     = "`$print`",
		}
		local foreignKeywordList = {}
		for word in pairs(foreignKeywords) do
			foreignKeywordList[#foreignKeywordList + 1] = word
		end
		table.sort(foreignKeywordList)

		r_foreignKeyword = function()
			local bpos = pos
			for i = 1, #foreignKeywordList do
				local word = foreignKeywordList[i]
				if kw(word) then
					pos = pos + #word
					local j = skipOS(pos)
					pos = j
					local content = code:sub(bpos, j - 1)
					local node = { name = "TEXT", bpos = bpos, epos = j - 1, content = content }
					if word == "return" then
						node.warning = "`return` is a future keyword, this line is plain text."
						node.warningHint = "Add `use #future(return)` to enable it."
						node.issues = { 1160 }
					else
						node.warning = string.format("`%s` is not a Plume keyword, this line is plain text.", word)
						node.warningHint = string.format("Do you mean %s ?", foreignKeywords[word])
						node.issues = { 381, 1160 }
					end
					return { node }
				end
			end
			return nil
		end

		-- -----------------------------------------------------------------
		-- statements dispatch
		-- -----------------------------------------------------------------
		-- commandStd : _if + _while + _for + _break + continue + macro
		--   + _do + inlineBlockStart + block + let + set + leave + _return
		--   + inlinetable + expand + use + raw + with
		r_commandStd = function()
			local v = try(r_if)
			if v then return v end
			v = try(r_while)
			if v then return v end
			v = try(r_for)
			if v then return v end
			v = try(r_break)
			if v then return v end
			v = try(r_continue)
			if v then return v end
			v = try(r_macro)
			if v then return v end
			v = try(r_do)
			if v then return v end
			v = try(r_inlineBlockStart)
			if v then return v end
			v = r_block()
			if v then return v end
			v = try(r_let)
			if v then return v end
			v = try(r_set)
			if v then return v end
			v = try(r_leave)
			if v then return v end
			v = try(r_return)
			if v then return v end
			v = try(r_mainInlinetable)
			if v then return v end
			v = try(r_expand)
			if v then return v end
			v = try(r_use)
			if v then return v end
			v = try(r_raw)
			if v then return v end
			return r_with()
		end

		-- commandLB : listitem + hashitem (only at line start)
		r_commandLB = function()
			local v = try(r_listitem)
			if v then return v end
			return r_hashitem()
		end

		-- command : commandStd + commandLB
r_command = function()
			local v = r_commandStd()
			if v then return v end
			return r_commandLB()
		end

		-- statementTerminator : K"elseif" + K"else" + K"end" (zero-width)
		local function isTerminator()
			return kw("elseif") or kw("else") or kw("end")
		end

		-- firstStatement : os * (-V"statementTerminator") * (V"command"
		--   + Ct("RUN", K"run" * (s * V"firstStatement" + E(emptyRun)))
		--   + Ct("RAISE", K"raise" * (s * V"firstStatement" + E(emptyRaise)))
		--   + V"invalid"^-1 * (foreignKeyword * V"text" + foreignKeyword
		--    + fakeAffectation^-1 * V"text" + fakeAffectation))
		local function runRaise(kwText, handler)
			if not kw(kwText) then return nil end
			local bpos = pos
			pos = pos + #kwText
			local save = pos
			local kids
			if skipOS1() then
				local st = r_firstStatement()
				if st then kids = st end
			end
			if kids == nil then
				pos = save
				local content, epos, i = restOfLine()
				kids = { nodeE(handler, pos, epos, content) }
				pos = i
			end
			return { nodeCt(kwText:upper(), bpos, pos - 1, kids) }
		end

r_firstStatement = function()
			skipOS()
			if isTerminator() then return nil end
			-- V"command"
			local v = r_command()
			if v then return v end
			-- RUN
			local v2 = runRaise("run", plume.error.emptyRun)
			if v2 then return v2 end
			-- RAISE
			v2 = runRaise("raise", plume.error.emptyRaise)
			if v2 then return v2 end
			-- V"invalid"^-1 : optional E(emptySet, K"set")
			local save = pos
			local invalidKids
			if kw("set") then
				local eb = pos
				pos = pos + 3
				invalidKids = { nodeE(plume.error.emptySet, eb, eb + 2, "set") }
			end
			local function addInvalid(kids)
				if invalidKids then
					for i = 1, #invalidKids do kids[#kids + 1] = invalidKids[i] end
				end
				return kids
			end
			-- foreignKeyword * V"text"
			local fk = try(r_foreignKeyword)
			if fk then
				local tx = r_text()
				if tx then
					local kids = addInvalid({})
					for i = 1, #fk do kids[#kids + 1] = fk[i] end
					for i = 1, #tx do kids[#kids + 1] = tx[i] end
					return kids
				end
				pos = save
			end
			-- foreignKeyword
			fk = r_foreignKeyword()
			if fk then
				local kids = addInvalid({})
				for i = 1, #fk do kids[#kids + 1] = fk[i] end
				return kids
			end
			-- fakeAffectation^-1 * V"text" — the FA is optional (zero-width),
			-- so a plain line (comment, text…) is a text on its own
			local fa = try(r_fakeAffectation)
			if fa then
				local tx = r_text()
				if tx then
					local kids = addInvalid({})
					kids[#kids + 1] = fa[1]
					for i = 1, #tx do kids[#kids + 1] = tx[i] end
					return kids
				end
				pos = save
				fa = nil
			end
			if not fa then
				local tx = r_text()
				if tx then
					local kids = addInvalid({})
					for i = 1, #tx do kids[#kids + 1] = tx[i] end
					return kids
				end
				pos = save
			end
			-- fakeAffectation
			fa = r_fakeAffectation()
			if fa then
				local kids = addInvalid({})
				kids[#kids + 1] = fa[1]
				return kids
			end
			return nil
		end

		-- firstStatementNLB : os * (-V"statementTerminator") * (V"commandStd"
		--   + Ct("RUN", K"run" * (s * V"firstStatementNLB" + E(emptyRun)))
		--   + Ct("RAISE", K"raise" * (s * V"firstStatementNLB" + E(emptyRaise)))
		--   + V"invalid"^-1 * V"text")
		local function runRaiseNLB(kwText, handler)
			if not kw(kwText) then return nil end
			local bpos = pos
			pos = pos + #kwText
			local save = pos
			local kids
			if skipOS1() then
				local st = r_firstStatementNLB()
				if st then kids = st end
			end
			if kids == nil then
				pos = save
				local content, epos, i = restOfLine()
				kids = { nodeE(handler, pos, epos, content) }
				pos = i
			end
			return { nodeCt(kwText:upper(), bpos, pos - 1, kids) }
		end

r_firstStatementNLB = function()
			skipOS()
			if isTerminator() then return nil end
			local v = r_commandStd()
			if v then return v end
			local v2 = runRaiseNLB("run", plume.error.emptyRun)
			if v2 then return v2 end
			v2 = runRaiseNLB("raise", plume.error.emptyRaise)
			if v2 then return v2 end
			local save = pos
			local invalidKids
			if kw("set") then
				local eb = pos
				pos = pos + 3
				invalidKids = { nodeE(plume.error.emptySet, eb, eb + 2, "set") }
			end
			local tx = r_text()
			if tx == nil then return nil end
			local kids = {}
			if invalidKids then
				for i = 1, #invalidKids do kids[#kids + 1] = invalidKids[i] end
			end
			for i = 1, #tx do kids[#kids + 1] = tx[i] end
			return kids
		end

		-- statement : lt * V"firstStatement" — the whole rule backtracks on
		-- failure (the LINESTART is not consumed), and the LINESTART node is
		-- part of the result (it is a real capture, not a guard).
		r_statement = function()
			local save = pos
			local v = r_lt()
			if v == nil then return nil end
			local st = r_firstStatement()
			if st == nil then pos = save return nil end
			local kids = { v[1] }
			for i = 1, #st do kids[#kids + 1] = st[i] end
			return kids
		end

		-- -----------------------------------------------------------------
		-- entry point : program = V"firstStatement"^-1 * V"statement"^0
		-- -----------------------------------------------------------------
local function r_program()
			local kids = {}
			local v = try(r_firstStatement)
			if v then
				for i = 1, #v do kids[#kids + 1] = v[i] end
			end
			while true do
				local st = r_statement()
				if st == nil then break end
				for i = 1, #st do kids[#kids + 1] = st[i] end
			end
			return kids
		end

		return r_program()
	end

		-- Post-pass : the raw AST is processed identically after parsing.
	local function postProcess(ast, code, filename)
		plume.ast.set(ast, "filename", filename)
		plume.ast.set(ast, "code", code)

		-- Retrieve error if captured, else
		-- check if all the file has been parsed
		local pos = 0
		plume.ast.browse(ast, function (node)
			if node.error then
				node.error(node)
			end

			if node.name == "NAME" then
				plume.checkIdentifier(node, node.content)
			end

			if node.epos and node.epos > pos then
				pos = node.epos
			end
		end)

		plume.ast.labelMacro(ast)

		if pos < #code then
			plume.error.malformedCode({
				filename = filename,
				code = code,
				bpos = pos,
				epos = #code
			})
		end

		plume.ast.markParent(ast)
		plume.ast.markType(ast)
		plume.ast.fixIF_isUnic(ast)

		ast.pos = pos
		return ast
	end

	plume.parsePostProcess = function(children, code, filename)
		local ast = {
			name="FILE",
			children=children,
			bpos=1,
			epos=1
		}
		return postProcess(ast, code, filename)
	end

	function plume.parse(code, filename)
		-- parse will fail if empty line at programm end.
		-- dirty quick fix
		code = code:gsub('%s*$', '')
		local children = parseAST(code)
		return plume.parsePostProcess(children, code, filename)
	end

end
