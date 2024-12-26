require "../src/tree-sitter"

parser = LibTreeSitter.ts_parser_new

LibTreeSitter.ts_parser_set_language(parser, LibTreeSitterCrystal.tree_sitter_crystal)

source_code = <<-CRYSTAL
puts "hello world"
CRYSTAL

tree = LibTreeSitter.ts_parser_parse_string(parser, nil, source_code, source_code.bytesize)

root_node = LibTreeSitter.ts_tree_root_node(tree)

root_node_name = String.new(LibTreeSitter.ts_node_type(root_node))

puts root_node_name
