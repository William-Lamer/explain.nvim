.PHONY: test format check demo

test: deps/mini.nvim
	nvim --headless --noplugin -u tests/minimal_init.lua -c "lua MiniTest.run()"

deps/mini.nvim:
	git clone --depth 1 https://github.com/nvim-mini/mini.nvim $@

# Records the GIFs in demo/ with vhs, making real Claude calls
demo: deps/tokyonight.nvim
	vhs demo/error.tape
	vhs demo/diagnostic.tape
	vhs demo/code.tape

deps/tokyonight.nvim:
	git clone --depth 1 https://github.com/folke/tokyonight.nvim $@

format:
	stylua .

check:
	stylua --check .
