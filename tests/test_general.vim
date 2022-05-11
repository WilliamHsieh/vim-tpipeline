func SetUp()
	let s:tpipeline_filepath = tpipeline#get_filepath()
	let s:tpipeline_right_filepath = s:tpipeline_filepath . '-R'

	" init statusline manually, because VimEnter is not triggered
	call tpipeline#init_statusline()
	" wait a bit for tmux to catch up
	sleep 500m
endfunc

func Read_socket()
	call tpipeline#update()
	" wait a few ms to catch up
	sleep 200m

	let s:left = ''
	let l:written_file = readfile(s:tpipeline_filepath, '', -1)
	if !empty(l:written_file)
		let s:left = l:written_file[0]
	endif

	let s:right = ''
	let l:written_file = readfile(s:tpipeline_right_filepath, '', -1)
	if !empty(l:written_file)
		let s:right = l:written_file[0]
	endif
endfunc

func Test_autoembed()
	call assert_equal('status-left "#(cat #{socket_path}-\\#{session_id}-vimbridge)"', trim(system('tmux show-options -g status-left')))
endfunc

func Test_socket()
	let g:tpipeline_statusline = 'test'
	call Read_socket()
	call assert_match('test', s:left)
endfunc

func Test_colors()
	hi Bold guifg=#000000 guibg=#ffffff gui=bold cterm=bold
	hi Red guifg=#ffffff guibg=#ff0000
	let g:tpipeline_statusline = '%#Bold#BOLD%#Red#RED'
	call Read_socket()
	call assert_equal('#[fg=#000000,bg=#ffffff,bold]BOLD#[fg=#ffffff,bg=#ff0000,nobold]RED', s:left)
endfunc

func Test_focusevents()
	let g:tpipeline_statusline = 'focused'
	call Read_socket()
	call assert_match('focused', s:left)
	" lose focus
	call tpipeline#deferred_cleanup()
	call Read_socket()
	call assert_notmatch('focused', s:left)
	" gain focus
	call tpipeline#forceupdate()
	call Read_socket()
	call assert_match('focused', s:left)
endfunc

func Test_split()
	let g:tpipeline_statusline = 'LEFT%=RIGHT'
	call Read_socket()
	call assert_match('LEFT', s:left)
	call assert_notmatch('RIGHT', s:left)
	call assert_match('RIGHT', s:right)
	call assert_notmatch('LEFT', s:right)
endfunc

" test that if a vim window is much smaller than the console window, that we still use the entire space available
func Test_small_pane()
	let c = &columns / 3
	if c < 5
		" this test does not make much sense for small overall console size
		return
	endif
	let left = repeat('L', c)
	let right = repeat('R', c)
	let g:tpipeline_statusline = left . '%=' . right
	" split window in half
	vsplit
	" Since 2/3 > 1/2, now the width of the pane is smaller than the width of the fully expanded statusline.
	" Make sure we still use the entire tmux statusline regardless, since we are not bound by the vim window size
	" This especially means that the right part is NOT empty.
	call Read_socket()
	call assert_false(empty(s:right))
	call assert_match(left, s:left)
	call assert_match(right, s:right)

	bd
endfunc
