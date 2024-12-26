@[Link(ldflags: "#{__DIR__}/../ext/tree_sitter_crystal/libtree-sitter-crystal.a")]
lib LibTreeSitterCrystal
  fun tree_sitter_crystal : LibTreeSitter::TSLanguage*
end
