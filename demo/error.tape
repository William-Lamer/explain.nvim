# Records demo/error.gif. Run `make demo` from the repository root.
# The answers come from real Claude calls, so they differ between recordings.

Output demo/error.gif
Source demo/settings.tape

Hide
Type "cd demo && rm -f a.out && NVIM_APPNAME=explain-demo nvim -u init.lua main.c"
Enter
Sleep 2s
Show

Sleep 1.5s
Type ":split | terminal gcc main.c"
Sleep 400ms
Enter
Sleep 3s

# Close the terminal: the failed run is still remembered
Type ":q"
Enter
Sleep 1s

Type ":Explain"
Sleep 400ms
Enter
Sleep 14s

Type "c"
Sleep 8s
