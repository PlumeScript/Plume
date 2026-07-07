--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function (plume)
	local dynamicParseData

	local function buildGrammar()
		local S, R, P, V, Cp, Cmt = lpeg.S, lpeg.R, lpeg.P, lpeg.V, lpeg.Cp, lpeg.Cmt

		local function C(name, pattern)
			return Cp() * lpeg.C(pattern) * Cp() / function(bpos, content, epos)
				return {
					name = name,
					bpos = bpos,
					epos  = epos-1,
					content = content
				}
			end
		end

		local function Cc(name, pattern)
			return Cp() * lpeg.Cc(pattern) * Cp() / function(bpos, content, epos)
				return {
					name = name,
					bpos = bpos,
					epos  = epos-1,
					content = content
				}
			end
		end

		local function NOT(pattern)
			return (P(1) - pattern)
		end

		local function E(errorHandler, pattern)
			pattern = (pattern or NOT(S"\n")^0) 
			return Cp() * lpeg.C(pattern) * Cp() / function(bpos, content, epos)
				return {
					name = "Error",
					bpos = bpos,
					epos  = epos-1,
					content = content,
					error = errorHandler
				}
			end
		end
		local function Et(errorHandler, pattern)
			return Cp() * pattern * Cp() / function(bpos, content, epos)
				return {
					name = "Error",
					bpos = bpos,
					epos  = epos-1,
					content = content,
					error = errorHandler
				}
			end
		end

		local function W(pattern, warning, warningHint, issues)
			return Cp() * pattern * Cp() / function (bpos, epos)
				return {
					name = "NULL",
					issues = issues,
					bpos = bpos,
					epos  = epos-1,
					warning = warning,
					warningHint = warningHint
				}
			end
		end

		local function Ct(name, pattern)
			return Cp() * lpeg.Ct(pattern) * Cp() / function(bpos, children, epos)
				return {
					name=name, 
					bpos=bpos,
					epos=epos-1,
					children=children
				}
			end
		end

		local function bindWarning(a, b)
			if b then
				b.warning = a.warning
				b.warningHint = a.warningHint
				b.issues  = a.issues
				b.bpos    = a.bpos
				return b
			else
				return a
			end
		end

		local function sugarFlagParam(p)
			return p / function(capture)
				capture.name = "PARAM"
				capture.isFlag = true
				table.insert(capture.children, {
					name="BODY",
					bpos=capture.bpos,
					epos=capture.epos,
					children={{
						name="EVAL",
						bpos=capture.bpos,
						epos=capture.epos,
						children={{
							name = "FALSE",
							bpos=capture.bpos,
							epos=capture.epos,
						}}
					}},
				})
				return capture
			end
		end
		local function sugarFlagCall(p)
			return p / function(capture)
				capture.name = "HASH_ITEM"
				capture.isFlag = true
				table.insert(capture.children, {
					name="BODY",
					bpos=capture.bpos,
					epos=capture.epos,
					children={{
						name="EVAL",
						bpos=capture.bpos,
						epos=capture.epos,
						children={{
							name = "TRUE",
							bpos=capture.bpos,
							epos=capture.epos,
						}}
					}},
				})
				return capture
			end
		end

		local function applyDirective(subject, pos, node)
			local directiveNameNode = plume.ast.get(node, "NAME")
			local directiveName = directiveNameNode.content

			local options = {}
			for _, option in ipairs(plume.ast.getAll(node, "USE_OPTION")) do
				local keyNode = plume.ast.get(option, "KEY")
				local key = keyNode and keyNode.content
				if directiveName == "future" then
					if key == "lineEval" or key == "all" or key == "raven" then
						dynamicParseData.futureFlagLineEval = true
					end
				end
			end
			return pos, node
		end

		------------
		-- common --
		------------
		local function K(x) -- keyword
			return P(x) * (-R("az", "AZ")-P"_")
		end

		local s  = S" \t"^1
		local os = S" \t"^0
		local lt =  C("LINESTART", (os * S"\n")^1 * os) -- linestart
		local num = C("NUMBER", (R"09"^1 * P"." * R"09"^1) + R"09"^1)
		-- strict identifier
		local _idns = (R"az"+R"AZ"+P"_") * (R"az"+R"AZ"+P"_"+R"09")^0
		local name = C("NAME", _idns)
		local idns = C("IDENTIFIER", _idns)
		local idn = C("TRUE", K"true")   * -idns
				  + C("FALSE", K"false") * -idns
				  + C("EMPTY", K"empty") * -idns
				  + idns
		local escaped = P"\\s" * Cc("TEXT", " ")
					  + P"\\t" * Cc("TEXT", "\t")
					  + P"\\n" * Cc("TEXT", "\n")
					  + P"\\r" * Cc("TEXT", "\r")
					  + P"\\"*C("TEXT", P(1))
		

		---------------------------
		-- compilation directive --
		---------------------------
		local libidn = (P(1)-S",\n():")^0
		local libparam = Ct("USE_OPTION",
			(C("KEY", libidn) * os * ":") * os * Ct("VALUE", V"textic")
			+ E(plume.error.useDoesNotAcceptPositionalArgs, libidn)
		)
		local nameposLibparam = Ct("USE_OPTION",
			C("KEY", libidn) * (os * ":" * os * Ct("VALUE", V"textic"))^-1
		)
		local libparamlist = os * (P"("*P")" + P"(" * os * libparam * os * (P"," * os * libparam)^0 * os * ")")^-1
		local nameposLibparamlist = os * (P"("*P")" + P"(" * os * nameposLibparam * os * (P"," * os * libparam)^0 * os * ")")^-1

		local libname = Cmt(Ct("USE_DIRECTIVE", P"#" * C("NAME", libidn) * nameposLibparamlist), applyDirective)
					  + Ct("USE_LIB", C("NAME", libidn) * libparamlist)
		local use = K"use" * s * libname * (os*P","*os*libname)^0

		----------
		-- eval --
		----------
		local function fold_bin(t)
			if #t == 1 then return t[1] end
			local ast = t[1]
			for i = 2, #t, 2 do
				local operator = t[i]
				local right = t[i+1]
				ast = {
					name = operator.name,
					bpos = ast.bpos,
					epos = right.epos,
					children = {
						ast, 
						right
					}
				}
			end
			
			return ast
		end

		local function fold_un(t)
			if #t == 1 then return t[1] end
			local ast = t[#t]
			for i = #t - 1, 1, -1 do
				local operator = t[i]
				ast = {
					name = operator.name,
					bpos = operator.bpos,
					epos = ast.epos,
					children = {
						ast
					}
				}
			end
			
			return ast
		end

		local doublequoteText = C("TEXT", NOT(S'"\\')^1)
		local singlequoteText = C("TEXT", NOT(S'\'\\')^1)
		local quoteEscape =  P"\\" * C("ESCAPED",P(1))
		local quote = P'"' * Ct("QUOTE", (doublequoteText + quoteEscape)^0) * P'"'
					+ P"'" * Ct("QUOTE", (singlequoteText + quoteEscape)^0) * P"'"

		local opplist = {
			{{"OR",  "or"}},
			{{"AND", "and"}},
			{{"NOT", "not"}, unary=true},
			{{"EQ", "=="}, {"NEQ", "!="}, {"LTE", "<="}, {"GTE", ">="}, {"LT", "<"}, {"GT", ">"}},
			{{"ADD", "+"}, {"SUB", "-"}},
			{{"MUL", "*"}, {"DIV", "/"}, {"MOD", "%"}},
			{{"POW", "^"}},
			{{"NEG", "-"}, unary=true}
		}

		local function genALU()
			local rules = {"_layer1"}

			for deep, opps in ipairs(opplist) do
				local rule
				for i, opp in ipairs(opps) do
					local name, pattern = opp[1], opp[2]

					local opprule
					if pattern:match('^[a-z]+$') then
						opprule = C(name, P(pattern)) * -idn
					else
						opprule = C(name, P(pattern))
					end
	  
					if i==1 then
						rule = opprule
					else
						rule = rule + opprule
					end
				end
				local current = "_layer" .. deep
				local next    = "_layer" .. (deep+1)
				if opps.unary then
					rules[current] =  lpeg.Ct((rule * os)^0 * V(next)) / fold_un
				else
					rules[current] = lpeg.Ct(V(next) * (os * rule * os * V(next))^0) / fold_bin
				end
			end

			local safeidn = W(
				P"$",
				"Unnecessary `$` prefix inside eval mode `$(...)`.",
				"Everything inside is already evaluated. Extra `$` is allowed for convenience, though not required.",
				{547}
			)^-1 * idn / bindWarning

			-- Eval & index
			local posarg  = Ct("LIST_ITEM", V"_layer1")
			local optnarg = Ct("HASH_ITEM", (name + Ct("DYNAMIC_KEY", Ct("EVAL", P"$" * V"_layer1")))*os*P":"*os*Ct("BODY", V"_layer1"^-1))
			local arg = optnarg + posarg + sugarFlagCall(Ct("FLAG", os *"?"*name)) + Ct("EXPAND", Ct("EVAL", P"..."*V"_layer1"))
			local arglist = Ct("CALL", P"(" * arg^-1 * (os * P"," * os * arg)^0 * P")")
			local index = Ct("SAFE_INDEX", P"[" * V"_layer1" * P"]" * P"?") + Ct("INDEX", P"[" * V"_layer1" * P"]")
			local directindex = Ct("SAFE_DIRECT_INDEX", P"." * idn * P"?") + Ct("DIRECT_INDEX", P"." * idn)

			local inlinetable = Ct("INLINE_TABLE", P"(" * (arg^-1 * (os * P"," * os * arg)^1 + optnarg) * P")")

			local evalOpperator = arglist + index + directindex
			local primary = num + safeidn + quote + inlinetable + P"(" * V"_layer1" * P")"
			local access = Ct("EVAL", primary * evalOpperator^1)

			rules["_layer" .. (#opplist+1)] = os * (access + primary) * os

			return rules
		end

		local expr = Ct("EXPR", genALU())
		local evalBase = Ct("EVAL", (
				  P"("
					* (expr + E(plume.error.emptyExpr))
				* (P")" + E(plume.error.missingClosingBracket))
				+ idn
				+ num
				-- + E(plume.error.evalAlone)
			) * V"evalOpperator"^0
		)

		local eval = P"$" * evalBase
		local lineeval = P"$ " * Ct("EVAL", expr)
		lineeval = lineeval * P(function()
			return dynamicParseData.futureFlagLineEval
		end)
		local index = Ct("SAFE_INDEX", P"[" * expr * P"]" * P"?") + Ct("INDEX", P"[" * expr * P"]")
		local directindex = Ct("SAFE_DIRECT_INDEX", P"." * idn * P"?") + Ct("DIRECT_INDEX", P"." * idn)

		--------------
		-- commands --
		--------------
		-- common
		local condition = s * Ct("CONDITION", expr) + E(plume.error.missingCondition)
		local body      = Ct("BODY", V"statement"^0)
		local _end      = lt * K"end" + E(plume.error.missingEnd)

		-- if/elseif/else
		local _else   = Ct("ELSE", lt*K"else" * body)
		local _elseif = Ct("ELSEIF", lt*K"elseif" * condition * body)
		local _if     = Ct("IF", K"if" * condition * body * _elseif^0 * _else^-1 * _end)

		

		-- macro & calls
		local paramDefaultValue =   os * P":" * os * Ct("BODY", V"inlinetable" + V"textic"^-1)
		local param      = Ct("PARAM",
								  (C("VALIDATOR", _idns) * s)^-1 * (
								  name * paramDefaultValue^-1
								+ Ct("VARIADIC", P"..." * idn * Et(plume.error.cannotSetVariadicDefaultValue, paramDefaultValue)^-1)
							)) + sugarFlagParam(Ct("FLAG", "?"*name * Et(plume.error.cannotSetFlagDefaultValue, paramDefaultValue)^-1))
							
		local paramlist  = Ct("PARAMLIST",
				P"(" * os
					* param^-1 * (os * P"," *  (os * param + E(plume.error.missingParam, os-param)))^0
				* os * P")"
			)
		-- local paramlistM = paramlist + E(plume.error.missingParamList)
		local macro      = Ct("MACRO",           K"macro" * s * name * os * paramlist^-1 * body * _end)
		                 + Ct("ANONYMOUS_MACRO", K"macro"            * os * paramlist^-1 * body * _end)

		local namedArg  = (E(plume.error.cannotUseRef, K"ref") * s)^-1 * Ct("HASH_ITEM",
							os * (name + Ct("DYNAMIC_KEY", eval)) * os * P":"
							* os * Ct("BODY", (V"inlinetable" + V"textic")^-1)
						)
		local arg       = namedArg	
						+ E(plume.error.cannotUseRef, K"ref") * s * name
						+ sugarFlagCall(Ct("FLAG", os *"?"*name))
						+ Ct("EXPAND", P"..."*evalBase)
						+ Ct("LIST_ITEM", V"inlinetable")
						+ Ct("LIST_ITEM", V"textic")

		local call      = Ct("CALL", P"("
							* os * arg^-1 * (os * P"," * os * arg)^0 * (os
						* P")"
						+ E(plume.error.missingClosingBracketArgList)))

		local blockName = idn * (index + directindex)^0
		local blockStart = Ct("EVAL", P"@" * blockName * os
							* Ct("BLOCK_CALL", call^-1 * os * (Ct("BODY", V"blockStart") + body))
						)
		local block = blockStart * Ct("NULL", _end)
		local leave     = C("LEAVE", K"leave")

		-- affectations
		local lbody    = Ct("BODY", V"firstStatement")
		local lbodynlb = Ct("BODY", V"firstStatementNLB")
		local compound = Ct("COMPOUND", C("ADD", P"+") + C("SUB", P"-")
					   + C("MUL", P"*") + C("DIV", P"/"))
		local statconst = (s * C("CONST", K"const"))^-1 * (s * C("PARAM", K"param"))^-1
		

		--- Common identifier
		local _letsetdefaut = P":" * os * Ct("VALUE", (P"(" * V"textnp" * ")" + V"textns")^-1)
		local letsetvar = (
			Ct("ALIAS_DEFAULT", name * os * K"as" * os * name * os * _letsetdefaut)
			+ Ct("ALIAS", name * os * K"as" * os * name)
			+ Ct("DEFAULT", name * os * _letsetdefaut)
			+ name
			+ Ct("VARIADIC", P"..." * name)
		)

		--- Specific identifiers
		local letvar     = letsetvar
		local setvar     = Ct("SETINDEX", (name * V"evalOpperator"^1)) + letsetvar

		--- Make full rule
		local letvarlist = Ct("VARLIST", letvar * (os * P"," * os * letvar + E(plume.error.missingValue, P","))^0)
		local setvarlist = Ct("VARLIST", setvar * (os * P"," * os * setvar + E(plume.error.missingValue, P","))^0)
		
		local let = Ct("LET", K"let" * statconst * s * letvarlist * (
								  os * E(plume.error.letCompound, P"+"+"-"+"/"+"*")^-1 * P"=" * lbody
								+ s  * C("FROM", K"from") * s * lbody
							)^-1)

		local set = Ct("SET", K"set" * s * setvarlist * (
					  os * compound^-1 * P"=" * lbody
					+ s * C("FROM", K"from") * s * lbody
					))
		
		--- loops
		local forInd = letvarlist + E(plume.error.missingLoopIndentifier)
		local iterator  = (s * forInd * s * K"in" + E(plume.error.missingIteratorVariable, os * K"in"))
						* (s * Ct("ITERATOR", expr) + E(plume.error.missingIterator))
						
		local _while = Ct("WHILE", K"while" * condition * body * _end)
		local _for   = Ct("FOR", K"for" *  iterator * body * _end)

		local _break   = C("BREAK", K"break")
		local continue = C("CONTINUE", K"continue")

		-- table
		local ref      = name * (s * K"as" * s * Ct("ALIAS", name))^-1
		local listitem = Ct("LIST_ITEM", P"- " * os * V"firstStatementNLB" + P"-" * #lt) 
		local hashitem = Ct("HASH_ITEM",  Ct("META", K"meta"*s)^-1 * (name + Ct("DYNAMIC_KEY", eval)) * P":" * (os * lbodynlb + #lt))
						+ Ct("HASH_ITEM", Ct("REF", K"ref"*s) * ref * P":" *  os * lbodynlb)
						+ Ct("EMPTY_REF", Ct("REF", K"ref"*s) * ref) * (os * P"," * os * Ct("EMPTY_REF", ref))^0
		local expand   = Ct("EXPAND", P"..." * evalBase) 

		local _do = Ct("DO", os * K"do" * body * _end)

		local inlinetable = Ct("INLINE_TABLE", os * P"(" * (arg * (P"," * os * arg)^1 + namedArg) * P")")

		-- Deepness 0, 1 and 2 hardcoded.
		-- Should handle more case (#401)
		local raw = Ct("RAW", os * K"raw[[" *  C("TEXT", (P"\n"+-1) * (P(1)-P"]]end")^0)
						* (P"]]end" + E(plume.error.missingEnd, -P(1))))
				  + Ct("RAW", os * K"raw["  *  C("TEXT", (P"\n"+-1) * (P(1)-P"]end")^0)
				  		* (P"]end"  + E(plume.error.missingEnd, -P(1))))
				  + Ct("RAW", os * K"raw"   *  C("TEXT", (P"\n"+-1) * (P(1)-P"end")^0)
				  		* (P"end"   + E(plume.error.missingEnd, -P(1))))

		local with = Ct('WITH',
		K"with" * os * (
			Ct("PARAMLIST", inlinetable + eval)
		) * body * _end)

		-- Warning
		local fakeAffectation = C("TEXT", (R"az"+R"AZ"+P"_") * (R"az"+R"AZ"+P"_"+R"09")^0 * os * S"+-/*"^-1 * "=") /
		function(x)
			x.warning = "This is plain text, not an assignement."
			if x.content:match('[%+%-%*%/]') then
				x.warningHint = string.format("Do you mean `set %s ...` ?", x.content)
			else
				x.warningHint = string.format("Do you mean `let %s ...` or `set %s ...` ?", x.content, x.content)
			end
			x.issues = {381, 26}
			return x
		end

		----------
		-- main --
		----------
		local rules = {
			"program",
			program = V"firstStatement"^-1 * V"statement"^0,

			statementTerminator = K"elseif" + K"else" + K"end",
			firstStatement = os * (-V"statementTerminator")
								* (
									  V"command"
									+ Ct("RUN", K"run" * s * V"firstStatement")
									+ Ct("RAISE", K"raise" * s * V"firstStatement")
									+ V"invalid"^-1 * (fakeAffectation^-1 * V"text" + fakeAffectation)
								),
			firstStatementNLB = os * (-V"statementTerminator")
								* (
									  V"commandStd"
									+ Ct("RUN", K"run" * s * V"firstStatementNLB")
									+ Ct("RAISE", K"raise" * s * V"firstStatementNLB")
									+ V"invalid"^-1 * V"text"
								),
			statement    = lt * V"firstStatement",

			commandStd =  _if + _while + _for + _break + continue + macro
						  + _do + block + let + set + leave + inlinetable
						  + expand + use + raw + with + lineeval,
			-- Only at line start
			commandLB = listitem + hashitem,

			command = V"commandStd" + V"commandLB",

			text   = (escaped + eval + E(plume.error.nonEscapedEvalMark, P"$") + V"comment" + V"rawtext")^1,
			textns = (escaped + eval + E(plume.error.nonEscapedEvalMark, P"$") + V"comment" + V"rawtextns")^1,
			textnc = (escaped + eval + E(plume.error.nonEscapedEvalMark, P"$") + V"comment" + V"rawtextnc")^1,
			textnp = (escaped + eval + E(plume.error.nonEscapedEvalMark, P"$") + V"comment" + V"rawtextnp")^1,
			textic = (escaped + eval + E(plume.error.nonEscapedEvalMark, P"$") + V"comment"
						+ C("TEXT", P"(") * V"textic"^-1 * C("TEXT", P")") + V"rawtextic"
					)^1,

			comment  = os * (
				  P"//" * os * C("COMMENT", NOT(S"\n")^0)
				+ P"/*" * os * C("COMMENT", (P(1) - P("*/"))^0)  * C("NULL", P"*/")
			),
			rawtext   = C("TEXT", NOT(os * S"\n" + S"$\\" + os * (P"//" + P"/*"))^1),
			rawtextns = C("TEXT", NOT(S"$\n\\"   + P"//" + P"/*" + s)^1),
			rawtextnc = C("TEXT", NOT(S"$\n,\\"  + P"//" + P"/*" + s)^1),
			rawtextnp = C("TEXT", NOT(S"$\n)\\"  + P"//" + P"/*")^1),
			rawtextic = C("TEXT", NOT(S"$\n,()\\"+ P"//" + P"/*")^1),

			invalid = E(plume.error.emptySet, K"set"),
			evalOpperator = call + index + directindex,

			inlinetable= inlinetable,
			blockStart = blockStart
		}

		return lpeg.Ct(rules)
	end

	local grammar = buildGrammar()

	function plume.parse(code, filename)
		dynamicParseData = {}

		-- parse will fail if empty line at programm end.
		-- dirty quick fix
		code = code:gsub('%s*$', '')

		local ast = {
			name="FILE",
			children=lpeg.match(grammar, code),
			bpos=1,
			epos=1
		}
		
		plume.ast.set(ast, "filename", filename)
		plume.ast.set(ast, "code", code)

		-- Retrieve error if captured, else
		-- check if all the file has been parsed
		local pos = 0
		plume.ast.browse(ast, function (node)
			if node.error then
				if node.error == plume.error.nonEscapedEvalMark and not dynamicParseData.futureFlagLineEval then
					node.name = "TEXT"
				else
					node.error(node)
				end
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

end