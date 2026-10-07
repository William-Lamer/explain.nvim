.PHONY: test format check

test: deps/mini.nvim
	nvim --headless --noplugin -u tests/minimal_init.lua -c "lua MiniTest.run()"

deps/mini.nvim:
	git clone --depth 1 https://github.com/nvim-mini/mini.nvim $@

format:
	stylua .

check:
	stylua --check .
