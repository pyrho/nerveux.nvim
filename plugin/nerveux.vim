" in plugin/whid.vim
if exists('g:loaded_nerveux') | finish | endif " prevent loading file twice

let s:save_cpo = &cpo " save user coptions
set cpo&vim " reset them to defaults

" command to run our plugin
command! Nerv lua require'nerveux'.Nerv()

hi def link NerveuxHelpHeader htmlH1
hi def NerveuxHelpText   gui=bold

let &cpo = s:save_cpo " and restore after
unlet s:save_cpo

let g:loaded_nerveux = 1
