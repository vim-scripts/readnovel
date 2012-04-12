" 看中文小说txt专用插件
" Maintainer:  sunsolzn@gmail.com
" Date:        2012-4-12
" Version:     0.1
"README{{{
"只适用gvim和txt文件,本文件放到plugin目录
"F5 读取字体等设置（默认保存在.vim/read_novel_config.vim）
"F6 保存字体窗口大小等设置
"F7 截断长行（略耗时）必须先设置好字体和窗口再作这一步
"F8 自动滚屏（按Ctrl-C中止）
"F9 开始测试读文速度，读完一屏后按空格翻页，不要使用jk或鼠标翻页
"F10 停止测试（一般需要读文7-8页较为准确，停止后按F6保存测试结果）
"使用方法：
"第一次使用：用gvim打开txt小说，调整读小说所用的字体和窗口大小，设置好颜色，按F6保存
"看新的小说：用gvim打开新小说，按F5，再按F7
"看小说：用gvim打开txt小说，按F5,再按F8
"调整阅读速度：用gvim打开已断行的小说，按F5,按F9开始看小说，期间按空格或pgdn翻页，不受打扰的看10页以后按F10结束，再按F6保存
"}}}
"{{{
if exists('g:did_read_novel_plugin')
    finish
endif
let g:did_read_novel_plugin = 1

if !has('gui')
    finish
endif
"}}}
"默认参数 {{{
"参数文件位置
if !exists('g:read_novel_config_file')
    let g:read_novel_config_file=split(&runtimepath,',')[0] .  '/read_novel_config.vim'
endif
"截断长行的同时是否清除空行
if !exists('g:read_novel_enable_clear_empty_lines')
    let g:read_novel_enable_clear_empty_lines = 1
endif
"是否备份原始txt文件
if !exists('g:read_novel_enable_backup')
    let g:read_novel_enable_backup = 1
endif
"读文速度--读一个字的秒数
if !exists('g:read_novel_config_a')
    let g:read_novel_config_a = 0.10
endif
"读文速度--额外冗余秒数
if !exists('g:read_novel_config_b')
    let g:read_novel_config_b = -10.0
endif
"}}}
"局部变量 {{{
let s:seconds =[]
let s:start_time=0
let s:chars=[]
"}}}
function! s:global_config_load()"{{{
    if ! filereadable(g:read_novel_config_file)
        let config = ['let &guifont="Monospace Bold 16"' , 'set lines=999' , 'set columns=9999' , 'highlight Normal guibg=#e9faff guifg=black']
        call writefile(config,g:read_novel_config_file)
    endif
    execute 'source ' . g:read_novel_config_file
endfunc
"}}}
function! s:global_config_save()"{{{
    let config = ['let &guifont="' . &guifont . '"']
    call add(config, 'set lines=' . &lines)
    call add(config, 'set columns=' . &columns)
    redir => highstat
    silent highlight Normal
    redir END
    let colorbg = matchstr(highstat, '\sguibg\s*=\s*\S*')
    let colorfg = matchstr(highstat, '\sguifg\s*=\s*\S*')
    if colorfg . colorbg != ''
        call add(config, 'highlight Normal ' . colorbg . colorfg)
    endif
    call add(config, 'let g:read_novel_config_a= ' . string(g:read_novel_config_a))
    call add(config, 'let g:read_novel_config_b= ' . string(g:read_novel_config_b))
    call add(config, 'normal g`"')
    call writefile(config,g:read_novel_config_file)
endfunc
"}}}
function! s:Backup_file()"{{{
    if g:read_novel_enable_backup
        let f = expand('%:p')
        if ! filereadable(f . '.bak')
            execute 'write ' . f . '.bak'
        else
            let i = 0
            while filereadable(f . '.bak' . i)
                let i = i + 1
            endwhile
            execute 'write ' . f . '.bak' . i
        endif
    endif
endfunc
    "}}}
function! s:Clear_empty_line()"{{{
    if g:read_novel_enable_clear_empty_lines
        g/^\s*$/d
    endif
endfunc
"}}}
function! s:Wrap_longline()"{{{
    set nocindent
    set noautoindent
    set nosmartindent
    set indentexpr=
 "    set lazyredraw
    set wrap
    call s:Backup_file()
	normal gg
    let processmax = line('$')
    let i = 0
    let max = &columns - 5
	let lastline = 0
    let save = &statusline
    let save1 = &laststatus
    set laststatus=2
    set statusline=%=0%%
	while 1
		normal 0g$
		let a = col(".")
		normal $
		let b = col(".")
		if a == b
			normal j
            let i = i + 1
            execute 'set statusline=' . repeat('⬛',i * max / processmax) . '%=' . i * 100 / processmax . '%%'
            redrawstatus
		else
			execute "normal 0g$i\<CR>"
		endif
		let a = line('.')
		if lastline == a
			break
		else
			let lastline = a
		endif
	endwhile
    call s:Clear_empty_line()
    write
    let &statusline = save
    let &laststatus = save1
 "    set nolazyredraw
    normal gg
endfunc
"}}}
function! s:Calc_charnumber()"{{{
    let c = 0
    let i = line('w0')
    if has('python')
python << EOF
import vim
def ischar(x):
    if u'\u3400'<=x<=u'\u9fff': return True
    if u'0'<=x<=u'9': return True
    if u'a'<=x<=u'z': return True
    if u'A'<=x<=u'Z': return True
    if u'\uf900'<=x<=u'\ufae3': return True
    return False
EOF
    endif
    while i <= line('w$')
        let s = getline(i)
        if has('python')
            python vim.command("let c+="+str(len(filter(ischar,vim.eval('s').decode('utf8')))))
        else
            let c = c + strlen(substitute(s,'.','x','g'))
        endif
        let i += 1
    endwhile
    return c
endfunc
"}}}
function! s:Calc_time()"{{{
    let s = localtime() - s:start_time
    let s:start_time = localtime()
    return s
endfunc
"}}}
function! s:Pagedown()"{{{
    call add(s:chars,s:Calc_charnumber())
    call add(s:seconds,s:Calc_time())
 "    call feedkeys("\<c-f>")
    execute "normal \<c-f>"
endfunc
"}}}
function! s:Calc_ab()"{{{
    let xa = 0
    let ya = 0
    let ll = len(s:chars)
    for x in s:chars
        let xa += x
    endfor
    for y in s:seconds
        let ya += y
    endfor
    let xaf = (xa + 0.0)/ll
    let yaf = (ya + 0.0)/ll
    let i = 0
    let bb = 0.0
    let cc = 0.0
    while i < ll
        let bb += (s:chars[i] - xaf) * (s:seconds[i] - yaf)
        let cc += (s:chars[i] - xaf) * (s:chars[i] -xaf)
        let i = i + 1
    endwhile
    let a = bb / cc
    let b = yaf - a * xaf
    let r=[a,b]
    return r
endfunc
"}}}
function! s:Start_test()"{{{
    let s:chars = []
    let s:seconds = []
    let s:start_time = localtime()
    normal H
    nnoremap <silent> <buffer> <PageDown> :call <SID>Pagedown()<CR>
    nnoremap <silent> <buffer> <space> :call <SID>Pagedown()<CR>
 "    nnoremap <silent> <buffer> <c-f> :call <SID>Pagedown()<CR>
 "    nnoremap <silent> <buffer> <s-down> :call <SID>Pagedown()<CR>
endfunc
"}}}
function! s:End_test()"{{{
    nunmap <buffer> <PageDown>
 "    nunmap <buffer> <c-f>
 "    nunmap <buffer> <s-down>
    nunmap <buffer> <space>
    let r = s:Calc_ab()
    let g:read_novel_config_a = r[0]
    let g:read_novel_config_b = r[1]
    echom string(r)
endfunc
"}}}
function! s:Auto_scroll()"{{{
    let save = &statusline
    let save1 = &laststatus
    set laststatus=2
    set statusline=%=0%%
    let max = &columns - 5
    while 1
        try
            normal H
            let c = s:Calc_charnumber()
            let t = c * g:read_novel_config_a + g:read_novel_config_b
            let tt = float2nr(t) + 1
            let i = 0
            while i < tt
                execute 'set statusline=' . repeat('⬛',i * max / tt) . '%=%p%%'
                redrawstatus
                let i += 1
                sleep 1
            endwhile
            execute "normal \<c-f>"
            redraw
        catch
            break
        endtry
    endwhile
    let &statusline = save
    let &laststatus = save1
endfunc
        "}}}
augroup readnovel"{{{
    au!
    au BufRead *.txt nmap <silent> <buffer> <f5> :call <SID>global_config_load()<CR>
    au BufRead *.txt nmap <silent> <buffer> <f6> :call <SID>global_config_save()<CR>
    au BufRead *.txt nmap <silent> <buffer> <f7> :call <SID>Wrap_longline()<CR>
    au BufRead *.txt nmap <silent> <buffer> <f8> :call <SID>Auto_scroll()<CR>
    au BufRead *.txt nmap <silent> <buffer> <f9> :call <SID>Start_test()<CR>
    au BufRead *.txt nmap <silent> <buffer> <f10> :call <SID>End_test()<CR>
augroup END
"}}}
