.PHONY: tree-sitter
tree-sitter:
	cd src/ext/tree_sitter && make
	cd src/ext/tree_sitter_crystal && make
	@echo "Success!"
