.PHONY: test lint
# Run tests/*_spec.lua, or one file with SPEC=tests/x_spec.lua.
test:
	nvim -l tests/minit.lua $(SPEC)

lint:
	stylua --check .
