function! health#nerveux#check() abort
    lua require"nerveux.checkhealth".checks() 
endfunction

