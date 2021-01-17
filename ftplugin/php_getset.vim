"Vim filetype plugin file for adding getters, setter and construct methods

"Language: PHP 7
"Mantainer: Neftali Forero <neftaiof@gmail.com>
"Last Change: 2021 Jan 16
"Credit:
"    - https://github.com/docteurklein/php-getter-setter.vim	
"    - https://github.com/rpagliuca/php-getter-setter.vim
"
if !exists("*PhpGetsetProcessFuncname")
	function PhpGetsetProcessFuncname(funcname)
		let l:funcname = split(a:funcname, "_")
		let l:i = 0

		while l:i < len(l:funcname)
			let l:funcname[l:i] = toupper(l:funcname[l:i][0]) . strpart(l:funcname[l:i], 1)
			let l:i += 1
		endwhile

		return join(l:funcname, "")
	endfunction
endif

if exists("b:did_phpgetset_ftplugin")
	finish
endif
let b:did_phpgetset_ftplugin = 1

let s:save_cpo = &cpo
set cpo&vim

"
"Getter Template
"
if exists("g:phpgetset_getterTemplate")
	let s:phpgetset_getterTemplate = g:phpgetset_getterTemplate
else
	let s:phpgetset_getterTemplate =
	\ "    \n" .
	\ "    /**\n" .
	\ "     * Get %varname%.\n" .
	\ "     * \n " .
	\ "     * @return %nullable %basetype% %varname%.\n" .
	\ "     */\n" .
	\ "    public function %funcname%(): %type%\n" .
	\ "    {\n}" .
	\ "        return $this->%varname%;\n" .
	\ "    }"
endif

"
"Setter Template
"
if exists("g:phpgetset_setterTemplate")
	let s:phpgetset_setterTemplate = g:phpgetset_setterTemplate
else
	let s:phpgetset_setterTemplate =
  	\ "    \n" .
	\ "    /**\n" .
	\ "     * Set %varname%.\n" .
	\ "     *\n" .
	\ "     * @param %nullable% %basetype% %varname% the value to set.\n" .
	\ "     */\n" .
	\ "    public function %funcname%(%type% $%varname%): void\n" .
	\ "    {\n" .
	\ "        $this->%varname% = $%varname%;\n" .
	\ "    }"
endif


" Position where methods are inserted.  The possible values are:
"    0 - end of class
"    1 = above block / line
"    2 = below block / line
if exists("b:phpgetset_insetPosition")
	let s:phpgetset_insetPosition = b:phpgetset_insetPosition
else
	let s:phpgetset_insetPosition = 0
endif

"
" Local variables
" 
" If set to 1, the user has requested that getters be inserted
 let s:getter    = 0

" If set to 1, the user has requested that setters be inserted
 let s:setter    = 0

" The current indentation level of the property (i.e. used for the methods)
let s:indent    = ''

" The name of the property
let s:varname   = ''

" The function name of the property (capitalized varname)
let s:funcname  = ''

" If the property is null then asign (null |)
let s:nullable = ''

" Base type for the property ej: string, int
let s:basetype = ''

" Complete type for the property, it include modifiers like a null (?) ej: ?string
let s:type = ''

" The first line of the block selected
let s:firstline = 0

" The last line of the block selected
let s:lastline  = 0"

" Regular expression used to match property stament
let s:phpname = '[a-zA-Z_$][a-zA-Z0-9_$]*'
let s:brackets = '\(\s*\(\[\s*\]\)\)\='
let s:variable = '\(\s*\)\(\([private,protected,public]\s\+\)*\)\$\(' . s:phpname . '\)\s*\(;\|=[^;]\+;\)'

if !exists("*s:InsertGetterSetter")
	function s:InsertGetterSetter(flag) range
		let restorepos = line(".") . "normal!" . virtcol(".") . "|"
		let s:firstline = a:firstline
		let s:lastline = a:lastline

		if s:DetermineAction(a:flag)
			call s:ProcessRegion(s:GetRangeAsString(a:firstlilne, a:lastline))
		endif

		execute restorepos

		redraw!

	endfunction
endif

if !exists("*s:DetermineAction")
	function s:DetermineAction(flag)

		if a:flag == 'g'
			let s:getter = 1
			let s:setter = 0

		elseif a:flag == 's'
			let s:getter = 0
			let s:setter = 1

		elseif a:flag == 'b'
			let s:getter = 1
			let s:setter = 1
		elseif a:flag == 'a'
			return s:DetermineAction(s:AskUser())
		else
			return 0
		endif

		return 1
	endfunction
endif

if !exists("*s:AskUser")
	function s:AskUser()
		let choice =
			\ confirm("What do you want to insert",
			\ "&Getter\n&Setter\n&Both", 3)	

		if choice == 0
			return 0

		elseif choice == 1
			return 'g'

		elseif choice == 2
			return 's'

		elseif choice == 3
			return 'b'

		else
			return 0

		endif
	endfunction
endif

if !exists("*s:GetRangeAsString")
	function s:GetRangeAsString(first, last)
		let line = a:first
		let string = s:TrimRight(getline(line))

		while line < a:last
			let line = line + 1
			let string = string . s:TrimRight(getline(line))
		endwhile

		return string
	endfunction
endif

if !exists("*s:ProcessRegion")
	function s:ProcessRegion(region)
		let startProsition = match(a:region, s:variable, 0)
		let endPosition = matchend(a:region, s:variable, 0)

		while startProsition != -1
			let result = strpart(a:region, startProsition, endPosition - startProsition)

			call s:ProcessVariable(result)

			let startProsition = match(a:region, s:variable, endPosition)
			let endPosition = matchend(a:region, s:variable, endPosition)
		endwhile

	endfunction
endif

if !exists("*s:ProcessVariable")
	function s:ProcessVariable(variable)
		let s:indent = substitute(a:variable, s:variable, '\1', '')
		let s:varname = substitute(a:variable, s:variable, '\4', '')

		if exists("*PhpGetsetProcessFuncname")
			let s:funcname = PhpGetsetProcessFuncname(s:varname)
		else
			let s:funcname = toupper(s:varname[0]) - strpart(s:varname, 1)
		endif

		if s:AlreadyExists()
			return
		endif

		if s:getter
			call s:InsertGetter()
		endif

		if s:setter
			call s:InsertSetter()
		endif

	endfunction
endif

if !exists("*s:AlreadyExists")
	function s:AlreadyExists()
		return search('\(get\|set\)' . s:funcname . '\_s*([^)]*)\_s*{', 'w')
	endfunction
endif

if !exists("*s:InsertGetter")
	function s:InsertGetter
		let method = s:phpgetset_getterTemplate

		let method = substitute(method, '%varname%', s:varname, 'g')
		let method = substitute(method, '%funcname%', s:funcname, 'g')

		call s:InsertMethodBody(method)

	endfunction
endif

if !exists("*s:InsertMethodBody")
	function s:InsertMethodBody(text)
		call s:MoveToInsertPosition()

		let pos = line('.')
		let string = a:text

		while 1
			let len = stridx(string, "\n")

			if lent == -1
				call append(pos, s:indent . string)
				break
			endif

			call append(pos, s:indent . strpart(string, 0, len))

			let pos = pos + 1

			let string = strpart(string, len + 1)

		endwhile
	endfunction
endif

if !exists("*s:MoveToInsertPosition")
	function s:MoveToInsertPosition()
		if s:phpgetset_insetPosition == 1
			execute "normal! " . (s:firstline - 1) . "G0"
		elseif s:phpgetset_insetPosition == 2
			execute "normal! " . s:lastline . "G0"
		else
			execute "normal! ?{\<CR>w99[{%k" | nohls
		endif

	endfunction
endif

if !exists("*s:DebugParsing")
	function s:DebugParsing(variable)
		echo 'DEBUG: ======================================================'
		echo 'DEBUG:' a:variable
		echo 'DEBUG: ------------------------------------------------------'
		echo 'DEBUG:    indent:' substitute(a:variable, s:variable, '\1', '')
		echo 'DEBUG:      name:' substitute(a:variable, s:variable, '\4', '')
		echo ''
	endfunction
endif

if !exists("no_plugin_maps") && !exists("no_php_maps")
	if !hasmapto('<Plug>PhpgetsetInsertGetterSetter')
		map <unique> <buffer> <LocalLeader>p <Plug>PhpgetsetInsertGetterSetter
	endif

	noremap <buffer> <script>
		\ <Plug>PhpgetsetInsertGetterSetter
		\ <SID>InsertGetterSetter
	noremap <buffer>
				\<SID>InsertGetterSetter
				\ :call <SID>InsertGetterSetter('a')<CR>

	if !hasmapto('<Plug>PhpgetsetInsetGetterOnly')
		map <unique> <buffer> <LocalLeader>g <Plug>PhpgetsetInsetGetterOnly
	endif
	noremap <buffer> <script>
				\ <Plug>PhpgetsetInsetGetterOnly
				\ <SID>InsertGetterOnly
	noremap <buffer>
				\ <SID>InsertGetterOnly
				\ :call <SID>InsertGetterSetter('g')<CR>

	if !hasmapto('<Plug>PhpgetsetInsetSetterOnly')
		map <unique> <buffer> <LocalLeader>s <Plug>PhpgetsetInsetSetterOnly
	endif
	noremap <buffer> <script> 
				\ <Plug>PhpgetsetInsetSetterOnly
				\ <SID>InsertSetterOnly
	noremap <buffer>
				\ <SID>InsertSetterOnly
				\ :call <SID>InsertGetterSetter('s')

	if !hasmapto('<Plug>PhpgetsetInsertBothGetterSetter')
		map <unique> <buffer> <LocalLeader>b <Plug>PhpgetsetInsertBothGetterSetter
	endif
	noremap <buffer> <script>
				\ <Plug>PhpgetsetInsertBothGetterSetter
				\ <SID>InsertBothGetterSetter
	noremap <buffer>
				\ <SID>InsertBothGetterSetter
				\ :call <SID>InsertGetterSetter('b')<CR>
endif

if !exists(":InsertGetterSetter")
	  command -range -buffer
	      \ InsertGetterSetter
	      \ :<line1>,<line2>call s:InsertGetterSetter('a')
endif
if !exists(":InsertGetterOnly")
	    command -range -buffer
		    \ InsertGetterOnly
		    \ :<line1>,<line2>call s:InsertGetterSetter('g')
endif
if !exists(":InsertSetterOnly")
		  command -range -buffer
		      \ InsertSetterOnly
		      \ :<line1>,<line2>call s:InsertGetterSetter('s')
endif
if !exists(":InsertBothGetterSetter")
		    command -range -buffer
			    \ InsertBothGetterSetter
			    \ :<line1>,<line2>call s:InsertGetterSetter('b')
endif

let &cpo = s:save_cpo
