# Records demo/diagnostic.gif. Run `make demo` from the repository root.

Output demo/diagnostic.gif
Source demo/settings.tape
Require clangd

Hide
Type "cd demo && EXPLAIN_DEMO_LSP=1 NVIM_APPNAME=explain-demo nvim -u init.lua +4 greet.c"
Enter
Sleep 2s
Show

# clangd needs a moment before the diagnostics show up
Sleep 3s
Type ":Explain"
Sleep 400ms
Enter
Sleep 14s
