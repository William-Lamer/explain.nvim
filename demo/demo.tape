# Records demo/demo.gif. Run `make demo` from the repository root.
# The answers come from real Claude calls, so they differ between recordings.

Output demo/demo.gif

Require nvim
Require claude

Set Shell bash
Set FontFamily "JetBrainsMonoNL Nerd Font"
Set FontSize 18
Set Width 1400
Set Height 860
Set Padding 16
Set Theme "TokyoNight"
Set WindowBar Colorful
Set TypingSpeed 60ms

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
