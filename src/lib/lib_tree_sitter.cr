@[Link(ldflags: "#{__DIR__}/../ext/tree_sitter/libtree-sitter.a")]
lib LibTreeSitter
  # The latest ABI version that is supported by the current version of the
  # library. When Languages are generated by the Tree-sitter CLI, they are
  # assigned an ABI version number that corresponds to the current CLI version.
  # The Tree-sitter library is generally backwards-compatible with languages
  # generated using older CLI versions, but is not forwards-compatible.
  TREE_SITTER_LANGUAGE_VERSION = 14

  # The earliest ABI version that is supported by the current version of the
  # library.
  TREE_SITTER_MIN_COMPATIBLE_LANGUAGE_VERSION = 13

  # Types

  type TSStateId = LibC::UInt16T
  type TSSymbol = LibC::UInt16T
  type TSFieldId = LibC::UInt16T
  type TSLanguage = Void*
  type TSParser = Void*
  type TSTree = Void*
  type TSQuery = Void*
  type TSQueryCursor = Void*
  type TSLookaheadIterator = Void*

  enum TSInputEncoding
    UTF8
    UTF16
  end

  enum TSSymbolType
    Regular
    Anonymous
    Supertype
    Auxiliary
  end

  struct TSPoint
    row, column : LibC::UInt32T
  end

  struct TSRange
    start_point, end_point : TSPoint
    start_byte, end_byte : LibC::UInt32T
  end

  struct TSInput
    payload : Void*
    read : Proc(Void*, LibC::UInt32T, TSPoint, LibC::UInt32T, LibC::Char*)
    encoding : TSInputEncoding
  end

  enum TSLogType
    Parse
    Lex
  end

  struct TSLogger
    payload : Void*
    log : Proc(Void*, TSLogType, LibC::Char*, Void)
  end

  struct TSInputEdit
    start_byte, old_end_byte, new_end_byte : LibC::UInt32T
    start_point, old_end_point, new_end_point : TSPoint
  end

  struct TSNode
    context : LibC::UInt32T[4]
    id : Void*
    tree : TSTree
  end

  struct TSTreeCursor
    tree : Void*
    id : Void*
    context : LibC::UInt32T[3]
  end

  struct TSQueryCapture
    node : TSNode
    index : LibC::UInt32T
  end

  enum TSQuantifier
    Zero       = 0 # must match the array initialization value
    ZeroOrOne
    ZeroOrMore
    One
    OneOrMore
  end

  struct TSQueryMatch
    id : LibC::UInt32T
    pattern_index : LibC::UInt16T
    capture_count : LibC::UInt16T
    captures : TSQueryCapture*
  end

  enum TSQueryPredicateStepType
    Done
    Capture
    String
  end

  struct TSQueryPredicateStep
    type : TSQueryPredicateStepType
    value_id : LibC::UInt32T
  end

  enum TSQueryError
    None      = 0
    Syntax
    NodeType
    Field
    Capture
    Structure
    Language
  end

  # Parser

  # Create a new parser.
  fun ts_parser_new : TSParser*

  # Delete the parser, freeing all of the memory that it used.
  fun ts_parser_delete(TSParser*)

  # Get the parser's current language.
  fun ts_parser_language(TSParser*) : TSLanguage*

  # Set the language that the parser should use for parsing.
  #
  # Returns a boolean indicating whether or not the language was successfully
  # assigned. True means assignment succeeded. False means there was a version
  # mismatch: the language was generated with an incompatible version of the
  # Tree-sitter CLI. Check the language's version using [`ts_language_version`]
  # and compare it to this library's [`TREE_SITTER_LANGUAGE_VERSION`] and
  # [`TREE_SITTER_MIN_COMPATIBLE_LANGUAGE_VERSION`] constants.
  fun ts_parser_set_language(self : TSParser*, language : TSLanguage*) : Bool

  # Set the ranges of text that the parser should include when parsing.
  #
  # By default, the parser will always include entire documents. This function
  # allows you to parse only a *portion* of a document but still return a syntax
  # tree whose ranges match up with the document as a whole. You can also pass
  # multiple disjoint ranges.
  #
  # The second and third parameters specify the location and length of an array
  # of ranges. The parser does *not* take ownership of these ranges; it copies
  # the data, so it doesn't matter how these ranges are allocated.
  #
  # If `count` is zero, then the entire document will be parsed. Otherwise,
  # the given ranges must be ordered from earliest to latest in the document,
  # and they must not overlap. That is, the following must hold for all:
  #
  # `i < count - 1`: `ranges[i].end_byte <= ranges[i + 1].start_byte`
  #
  # If this requirement is not satisfied, the operation will fail, the ranges
  # will not be assigned, and this function will return `false`. On success,
  # this function returns `true`
  fun ts_parser_set_included_ranges(
    self : TSParser*, ranges : TSRange*, count : LibC::UInt32T
  ) : Bool

  # Get the ranges of text that the parser will include when parsing.
  #
  # The returned pointer is owned by the parser. The caller should not free it
  # or write to it. The length of the array will be written to the given
  # `count` pointer.
  fun ts_parser_included_ranges(self : TSParser*, count : LibC::UInt32T*) : TSRange*

  # Use the parser to parse some source code and create a syntax tree.
  #
  # If you are parsing this document for the first time, pass `NULL` for the
  # `old_tree` parameter. Otherwise, if you have already parsed an earlier
  # version of this document and the document has since been edited, pass the
  # previous syntax tree so that the unchanged parts of it can be reused.
  # This will save time and memory. For this to work correctly, you must have
  # already edited the old syntax tree using the [`ts_tree_edit`] function in a
  # way that exactly matches the source code changes.
  #
  # The [`TSInput`] parameter lets you specify how to read the text. It has the
  # following three fields:
  # 1. [`read`]: A function to retrieve a chunk of text at a given byte offset
  #    and (row, column) position. The function should return a pointer to the
  #    text and write its length to the [`bytes_read`] pointer. The parser does
  #    not take ownership of this buffer; it just borrows it until it has
  #    finished reading it. The function should write a zero value to the
  #    [`bytes_read`] pointer to indicate the end of the document.
  # 2. [`payload`]: An arbitrary pointer that will be passed to each invocation
  #    of the [`read`] function.
  # 3. [`encoding`]: An indication of how the text is encoded. Either
  #    `TSInputEncodingUTF8` or `TSInputEncodingUTF16`.
  #
  # This function returns a syntax tree on success, and `NULL` on failure. There
  # are three possible reasons for failure:
  # 1. The parser does not have a language assigned. Check for this using the
  #    [`ts_parser_language`] function.
  # 2. Parsing was cancelled due to a timeout that was set by an earlier call to
  #    the [`ts_parser_set_timeout_micros`] function. You can resume parsing from
  #    where the parser left out by calling [`ts_parser_parse`] again with the
  #    same arguments. Or you can start parsing from scratch by first calling
  #    [`ts_parser_reset`].
  # 3. Parsing was cancelled using a cancellation flag that was set by an
  #    earlier call to [`ts_parser_set_cancellation_flag`]. You can resume parsing
  #    from where the parser left out by calling [`ts_parser_parse`] again with
  #    the same arguments.
  #
  # [`read`]: TSInput::read
  # [`payload`]: TSInput::payload
  # [`encoding`]: TSInput::encoding
  # [`bytes_read`]: TSInput::read
  fun ts_parser_parse(self : TSParser*, old_tree : TSTree*, input : TSInput) : TSTree*

  # Use the parser to parse some source code stored in one contiguous buffer.
  # The first two parameters are the same as in the [`ts_parser_parse`] function
  # above. The second two parameters indicate the location of the buffer and its
  # length in bytes.
  fun ts_parser_parse_string(
    self : TSParser*, old_tree : TSTree*, string : LibC::Char*, length : LibC::UInt32T
  ) : TSTree*

  # Use the parser to parse some source code stored in one contiguous buffer with
  # a given encoding. The first four parameters work the same as in the
  # [`ts_parser_parse_string`] method above. The final parameter indicates whether
  # the text is encoded as UTF8 or UTF16.
  fun ts_parser_parse_string_encoding(
    self : TSParser*, old_tree : TSTree*,
    string : LibC::Char*, length : LibC::UInt32T, encoding : TSInputEncoding
  )

  # Instruct the parser to start the next parse from the beginning.
  #
  # If the parser previously failed because of a timeout or a cancellation, then
  # by default, it will resume where it left off on the next call to
  # [`ts_parser_parse`] or other parsing functions. If you don't want to resume,
  # and instead intend to use this parser to parse some other document, you must
  # call [`ts_parser_reset`] first.
  fun ts_parser_reset(TSParser*) : Void

  # Set the maximum duration in microseconds that parsing should be allowed to
  # take before halting.
  #
  # If parsing takes longer than this, it will halt early, returning NULL.
  # See [`ts_parser_parse`] for more information.
  fun ts_parser_set_timeout_micros(self : TSParser*, timeout_micros : LibC::UInt64T) : Void

  # Get the duration in microseconds that parsing is allowed to take.
  fun ts_parser_timeout_micros(TSParser*) : LibC::UInt64T

  # Set the parser's current cancellation flag pointer.
  #
  # If a non-null pointer is assigned, then the parser will periodically read
  # from this pointer during parsing. If it reads a non-zero value, it will
  # halt early, returning NULL. See [`ts_parser_parse`] for more information.
  fun ts_parser_set_cancellation_flag(self : TSParser*, flag : LibC::SizeT) : Void

  # Get the parser's current cancellation flag pointer.
  fun ts_parser_cancellation_flag(TSParser*) : LibC::SizeT*

  # Set the logger that a parser should use during parsing.
  #
  # The parser does not take ownership over the logger payload. If a logger was
  # previously assigned, the caller is responsible for releasing any memory
  # owned by the previous logger.
  fun ts_parser_set_logger(self : TSParser*, logger : TSLogger) : Void

  # Get the parser's current logger.
  fun ts_parser_logger(TSParser*) : TSLogger

  # Set the file descriptor to which the parser should write debugging graphs
  # during parsing. The graphs are formatted in the DOT language. You may want
  # to pipe these graphs directly to a `dot(1)` process in order to generate
  # SVG output. You can turn off this logging by passing a negative number.
  fun ts_parser_print_dot_graphs(self : TSParser*, fd : LibC::Int) : Void

  # Tree

  # Create a shallow copy of the syntax tree. This is very fast.
  #
  # You need to copy a syntax tree in order to use it on more than one thread at
  # a time, as syntax trees are not thread safe.
  fun ts_tree_copy(TSTree*) : TSTree*

  # Delete the syntax tree, freeing all of the memory that it used.
  fun ts_tree_delete(TSTree*) : Void

  # Get the root node of the syntax tree.
  fun ts_tree_root_node(TSTree*) : TSNode

  # Get the root node of the syntax tree, but with its position
  # shifted forward by the given offset.
  fun ts_tree_root_node_with_offset(
    self : TSTree*, offset_bytes : LibC::UInt32T, offset_extent : TSPoint
  ) : TSNode

  # Get the language that was used to parse the syntax tree.
  fun ts_tree_language(TSTree*) : TSLanguage*

  # Get the array of included ranges that was used to parse the syntax tree.
  #
  # The returned pointer must be freed by the caller.
  fun ts_tree_included_ranges(self : TSTree*, length : LibC::UInt32T*) : TSRange*

  # Edit the syntax tree to keep it in sync with source code that has been
  # edited.
  #
  # You must describe the edit both in terms of byte offsets and in terms of
  # (row, column) coordinates.
  fun ts_tree_edit(self : TSTree*, edit : TSInputEdit*) : Void

  # Compare an old edited syntax tree to a new syntax tree representing the same
  # document, returning an array of ranges whose syntactic structure has changed.
  #
  # For this to work correctly, the old syntax tree must have been edited such
  # that its ranges match up to the new tree. Generally, you'll want to call
  # this function right after calling one of the [`ts_parser_parse`] functions.
  # You need to pass the old tree that was passed to parse, as well as the new
  # tree that was returned from that function.
  #
  # The returned array is allocated using `malloc` and the caller is responsible
  # for freeing it using `free`. The length of the array will be written to the
  # given `length` pointer.
  fun ts_tree_get_changed_ranges(
    old_tree : TSTree*, new_tree : TSTree*, length : LibC::UInt32T*
  ) : TSRange*

  # Write a DOT graph describing the syntax tree to the given file.
  fun ts_tree_print_dot_graph(self : TSTree*, file_descriptor : LibC::Int) : Void

  # Node

  # Get the node's type as a null-terminated string.
  fun ts_node_type(TSNode) : LibC::Char*

  # Get the node's type as a numerical id.
  fun ts_node_symbol(TSNode) : TSSymbol

  # Get the node's language.
  fun ts_node_language(TSNode) : TSLanguage*

  # Get the node's type as it appears in the grammar ignoring aliases as a
  # null-terminated string.
  fun ts_node_grammar_type(TSNode) : LibC::Char*

  # Get the node's type as a numerical id as it appears in the grammar ignoring
  # aliases. This should be used in [`ts_language_next_state`] instead of
  # [`ts_node_symbol`].
  fun ts_node_grammar_symbol(TSNode) : TSSymbol

  # Get the node's start byte.
  fun ts_node_start_byte(TSNode) : LibC::UInt32T

  # Get the node's start position in terms of rows and columns.
  fun ts_node_start_point(TSNode) : TSPoint

  # Get the node's end byte.
  fun ts_node_end_byte(TSNode) : LibC::UInt32T

  # Get the node's end position in terms of rows and columns.
  fun ts_node_end_point(TSNode) : TSPoint

  # Get an S-expression representing the node as a string.
  #
  # This string is allocated with `malloc` and the caller is responsible for
  # freeing it using `free`.
  fun ts_node_string(TSNode) : LibC::Char*

  # Check if the node is null. Functions like [`ts_node_child`] and
  # [`ts_node_next_sibling`] will return a null node to indicate that no such node
  # was found.
  fun ts_node_is_null(TSNode) : Bool

  # Check if the node is *named*. Named nodes correspond to named rules in the
  # grammar, whereas *anonymous* nodes correspond to string literals in the
  # grammar.
  fun ts_node_is_named(TSNode) : Bool

  # Check if the node is *missing*. Missing nodes are inserted by the parser in
  # order to recover from certain kinds of syntax errors.
  fun ts_node_is_missing(TSNode) : Bool

  # Check if the node is *extra*. Extra nodes represent things like comments,
  # which are not required the grammar, but can appear anywhere.
  fun ts_node_is_extra(TSNode) : Bool

  # Check if a syntax node has been edited.
  fun ts_node_has_changes(TSNode) : Bool

  # Check if the node is a syntax error or contains any syntax errors.
  fun ts_node_has_error(TSNode) : Bool

  # Check if the node is a syntax error.
  fun ts_node_is_error(TSNode) : Bool

  # Get this node's parse state.
  fun ts_node_parse_state(TSNode) : TSStateId

  # Get the parse state after this node.
  fun ts_node_next_parse_state(TSNode) : TSStateId

  # Get the node's immediate parent.
  # Prefer [`ts_node_child_containing_descendant`] for
  # iterating over the node's ancestors.
  fun ts_node_parent(TSNode) : TSNode

  # @deprecated use [`ts_node_contains_descendant`] instead, this will be removed in 0.25
  #
  # Get the node's child containing `descendant`. This will not return
  # the descendant if it is a direct child of `self`, for that use
  # `ts_node_contains_descendant`.
  fun ts_node_child_containing_descendant(self : TSNode, descendant : TSNode) : TSNode

  # Get the node that contains `descendant`.
  #
  # Note that this can return `descendant` itself, unlike the deprecated function
  # [`ts_node_child_containing_descendant`].
  fun ts_node_child_with_descendant(self : TSNode, descendant : TSNode) : TSNode

  # Get the node's child at the given index, where zero represents the first
  # child.
  fun ts_node_child(self : TSNode, child_index : LibC::UInt32T) : TSNode

  # Get the field name for node's child at the given index, where zero represents
  # the first child. Returns NULL, if no field is found.
  fun ts_node_field_name_for_child(self : TSNode, child_index : LibC::UInt32T) : LibC::Char*

  # Get the field name for node's named child at the given index, where zero
  # represents the first named child. Returns NULL, if no field is found.
  fun ts_node_field_name_for_named_child(
    self : TSNode, named_child_index : LibC::UInt32T
  ) : LibC::Char*

  # Get the node's number of children.
  fun ts_node_child_count(TSNode) : LibC::UInt32T

  # Get the node's *named* child at the given index.
  #
  # See also [`ts_node_is_named`].
  fun ts_node_named_child(self : TSNode, child_index : LibC::UInt32T) : TSNode

  # Get the node's number of *named* children.
  #
  # See also [`ts_node_is_named`].
  fun ts_node_named_child_count(TSNode) : LibC::UInt32T

  # Get the node's child with the given field name.
  fun ts_node_child_by_field_name(
    self : TSNode, name : LibC::Char*, name_length : LibC::UInt32T
  ) : TSNode

  # Get the node's child with the given numerical field id.
  #
  # You can convert a field name to an id using the
  # [`ts_language_field_id_for_name`] function.
  fun ts_node_child_by_field_id(self : TSNode, field_id : TSFieldId) : TSNode

  # Get the node's next / previous *named* sibling.
  fun ts_node_next_sibling(TSNode) : TSNode
  fun ts_node_prev_sibling(TSNode) : TSNode

  # Get the node's first child that extends beyond the given byte offset.
  fun ts_node_first_child_for_byte(self : TSNode, byte : LibC::UInt32T) : TSNode

  # Get the node's first named child that extends beyond the given byte offset.
  fun ts_node_first_named_child_for_byte(self : TSNode, byte : LibC::UInt32T) : TSNode

  # Get the node's number of descendants, including one for the node itself.
  fun ts_node_descendant_count(TSNode) : LibC::UInt32T

  # Get the smallest node within this node that spans the given range of bytes
  # or (row, column) positions.
  fun ts_node_descendant_for_byte_range(
    self : TSNode, start : LibC::UInt32T, end : LibC::UInt32T
  ) : TSNode
  fun ts_node_descendant_for_point_range(
    self : TSNode, start : TSPoint, end : TSPoint
  ) : TSNode

  # Get the smallest named node within this node that spans the given range of
  # bytes or (row, column) positions.
  fun ts_node_named_descendant_for_byte_range(
    self : TSNode, start : LibC::UInt32T, end : LibC::UInt32T
  ) : TSNode
  fun ts_node_named_descendant_for_point_range(
    self : TSNode, start : TSPoint, end : TSPoint
  ) : TSNode

  # Edit the node to keep it in-sync with source code that has been edited.
  #
  # This function is only rarely needed. When you edit a syntax tree with the
  # [`ts_tree_edit`] function, all of the nodes that you retrieve from the tree
  # afterward will already reflect the edit. You only need to use [`ts_node_edit`]
  # when you have a [`TSNode`] instance that you want to keep and continue to use
  # after an edit.
  fun ts_node_edit(self : TSNode*, edit : TSInputEdit*) : Void

  # Check if two nodes are identical.
  fun ts_node_eq(self : TSNode, other : TSNode) : Bool

  # TreeCursor

  # Create a new tree cursor starting from the given node.
  #
  # A tree cursor allows you to walk a syntax tree more efficiently than is
  # possible using the [`TSNode`] functions. It is a mutable object that is always
  # on a certain syntax node, and can be moved imperatively to different nodes.
  fun ts_tree_cursor_new(TSNode) : TSTreeCursor

  # Delete a tree cursor, freeing all of the memory that it used.
  fun ts_tree_cursor_delete(TSTreeCursor*) : Void

  # Re-initialize a tree cursor to start at the original node that the cursor was
  # constructed with.
  fun ts_tree_cursor_reset(self : TSTreeCursor*, node : TSNode)

  # Re-initialize a tree cursor to the same position as another cursor.
  #
  # Unlike [`ts_tree_cursor_reset`], this will not lose parent information and
  # allows reusing already created cursors.
  fun ts_tree_cursor_reset_to(dst : TSTreeCursor*, src : TSTreeCursor*) : Void

  # Get the tree cursor's current node.
  fun ts_tree_cursor_current_node(self : TSTreeCursor*) : TSNode

  # Get the field name of the tree cursor's current node.
  #
  # This returns `NULL` if the current node doesn't have a field.
  # See also [`ts_node_child_by_field_name`].
  fun ts_tree_cursor_current_field_name(TSTreeCursor*) : LibC::Char*

  # Get the field id of the tree cursor's current node.
  #
  # This returns zero if the current node doesn't have a field.
  # See also [`ts_node_child_by_field_id`], [`ts_language_field_id_for_name`].
  fun ts_tree_cursor_current_field_id(TSTreeCursor*) : TSFieldId

  # Move the cursor to the parent of its current node.
  #
  # This returns `true` if the cursor successfully moved, and returns `false`
  # if there was no parent node (the cursor was already on the root node).
  fun ts_tree_cursor_goto_parent(TSTreeCursor*) : Bool

  # Move the cursor to the next sibling of its current node.
  #
  # This returns `true` if the cursor successfully moved, and returns `false`
  # if there was no next sibling node.
  fun ts_tree_cursor_goto_next_sibling(TSTreeCursor*) : Bool

  # Move the cursor to the previous sibling of its current node.
  #
  # This returns `true` if the cursor successfully moved, and returns `false` if
  # there was no previous sibling node.
  #
  # Note, that this function may be slower than
  # [`ts_tree_cursor_goto_next_sibling`] due to how node positions are stored. In
  # the worst case, this will need to iterate through all the children upto the
  # previous sibling node to recalculate its position.
  fun ts_tree_cursor_goto_previous_sibling(TSTreeCursor*) : Bool

  # Move the cursor to the first child of its current node.
  #
  # This returns `true` if the cursor successfully moved, and returns `false`
  # if there were no children.
  fun ts_tree_cursor_goto_first_child(TSTreeCursor*) : Bool

  # Move the cursor to the last child of its current node.
  #
  # This returns `true` if the cursor successfully moved, and returns `false` if
  # there were no children.
  #
  # Note that this function may be slower than [`ts_tree_cursor_goto_first_child`]
  # because it needs to iterate through all the children to compute the child's
  # position.
  fun ts_tree_cursor_goto_last_child(TSTreeCursor*) : Bool

  # Move the cursor to the node that is the nth descendant of
  # the original node that the cursor was constructed with, where
  # zero represents the original node itself.
  fun ts_tree_cursor_goto_descendant(
    self : TSTreeCursor*, goal_descendant_index : LibC::UInt32T
  ) : Void

  # Get the index of the cursor's current node out of all of the
  # descendants of the original node that the cursor was constructed with.
  fun ts_tree_cursor_current_descendant_index(TSTreeCursor*) : LibC::UInt32T

  # Get the depth of the cursor's current node relative to the original
  # node that the cursor was constructed with.
  fun ts_tree_cursor_current_depth(TSTreeCursor*) : LibC::UInt32T

  # Move the cursor to the first child of its current node that extends beyond
  # the given byte offset or point.
  #
  # This returns the index of the child node if one was found, and returns -1
  # if no such child was found.
  fun ts_tree_cursor_goto_first_child_for_byte(
    self : TSTreeCursor*, start : LibC::UInt32T, end : LibC::UInt32T
  ) : LibC::UInt64T
  fun ts_tree_cursor_goto_first_child_for_point(
    self : TSTreeCursor*, start : TSPoint, end : TSPoint
  ) : LibC::UInt64T

  fun ts_tree_cursor_copy(TSTreeCursor*) : TSTreeCursor

  # Query

  # Create a new query from a string containing one or more S-expression
  # patterns. The query is associated with a particular language, and can
  # only be run on syntax nodes parsed with that language.
  #
  # If all of the given patterns are valid, this returns a [`TSQuery`].
  # If a pattern is invalid, this returns `NULL`, and provides two pieces
  # of information about the problem:
  # 1. The byte offset of the error is written to the `error_offset` parameter.
  # 2. The type of error is written to the `error_type` parameter.
  fun ts_query_new(
    language : TSLanguage*,
    source : LibC::Char*,
    source_len : LibC::UInt32T,
    error_offset : LibC::UInt32T*,
    error_type : TSQueryError*
  ) : TSQuery*

  # Delete a query, freeing all of the memory that it used.
  fun ts_query_delete(TSQuery*) : Void

  # Get the number of patterns, captures, or string literals in the query.
  fun ts_query_pattern_count(TSQuery*) : LibC::UInt32T
  fun ts_query_capture_count(TSQuery*) : LibC::UInt32T
  fun ts_query_string_count(TSQuery*) : LibC::UInt32T

  # Get the byte offset where the given pattern starts in the query's source.
  #
  # This can be useful when combining queries by concatenating their source
  # code strings.
  fun ts_query_start_byte_for_pattern(
    self : TSQuery*, pattern_index : LibC::UInt32T
  ) : LibC::UInt32T

  # Get the byte offset where the given pattern ends in the query's source.
  #
  # This can be useful when combining queries by concatenating their source
  # code strings.
  fun ts_query_end_byte_for_pattern(
    self : TSQuery*, pattern_index : LibC::UInt32T
  ) : LibC::UInt32T

  # Get all of the predicates for the given pattern in the query.
  #
  # The predicates are represented as a single array of steps. There are three
  # types of steps in this array, which correspond to the three legal values for
  # the `type` field:
  # - `TSQueryPredicateStepTypeCapture` - Steps with this type represent names
  #    of captures. Their `value_id` can be used with the
  #   [`ts_query_capture_name_for_id`] function to obtain the name of the capture.
  # - `TSQueryPredicateStepTypeString` - Steps with this type represent literal
  #    strings. Their `value_id` can be used with the
  #    [`ts_query_string_value_for_id`] function to obtain their string value.
  # - `TSQueryPredicateStepTypeDone` - Steps with this type are *sentinels*
  #    that represent the end of an individual predicate. If a pattern has two
  #    predicates, then there will be two steps with this `type` in the array.
  fun ts_query_predicates_for_pattern(
    self : TSQuery*,
    pattern_index : LibC::UInt32T,
    step_count : LibC::UInt32T*
  ) : TSQueryPredicateStep*

  # Check if the given pattern in the query has a single root node.
  fun ts_query_is_pattern_rooted(self : TSQuery*, pattern_index : LibC::UInt32T) : Bool

  # Check if the given pattern in the query is 'non local'.
  #
  # A non-local pattern has multiple root nodes and can match within a
  # repeating sequence of nodes, as specified by the grammar. Non-local
  # patterns disable certain optimizations that would otherwise be possible
  # when executing a query on a specific range of a syntax tree.
  fun ts_query_is_pattern_non_local(self : TSQuery*, pattern_index : LibC::UInt32T) : Bool

  # Check if a given pattern is guaranteed to match once a given step is reached.
  # The step is specified by its byte offset in the query's source code.
  fun ts_query_is_pattern_guaranteed_at_step(self : TSQuery*, byte_offset : LibC::UInt32T) : Bool

  # Get the name and length of one of the query's captures, or one of the
  # query's string literals. Each capture and string is associated with a
  # numeric id based on the order that it appeared in the query's source.
  fun ts_query_capture_name_for_id(
    self : TSQuery*, index : LibC::UInt32T, length : LibC::UInt32T*
  ) : LibC::Char*

  # Get the quantifier of the query's captures. Each capture is * associated
  # with a numeric id based on the order that it appeared in the query's source.
  fun ts_query_capture_quantifier_for_id(
    self : TSQuery*, pattern_index : LibC::UInt32T, capture_index : LibC::UInt32T
  ) : TSQuantifier

  fun ts_query_string_value_for_id(
    self : TSQuery*, index : LibC::UInt32T, length : LibC::UInt32T*
  ) : LibC::Char*

  # Disable a certain capture within a query.
  #
  # This prevents the capture from being returned in matches, and also avoids
  # any resource usage associated with recording the capture. Currently, there
  # is no way to undo this.
  fun ts_query_disable_capture(self : TSQuery*, name : LibC::Char*, length : LibC::UInt32T) : Void

  # Disable a certain pattern within a query.
  #
  # This prevents the pattern from matching and removes most of the overhead
  # associated with the pattern. Currently, there is no way to undo this.
  fun ts_query_disable_pattern(self : TSQuery*, pattern_index : LibC::UInt32T) : Void

  # Create a new cursor for executing a given query.
  #
  # The cursor stores the state that is needed to iteratively search
  # for matches. To use the query cursor, first call [`ts_query_cursor_exec`]
  # to start running a given query on a given syntax node. Then, there are
  # two options for consuming the results of the query:
  # 1. Repeatedly call [`ts_query_cursor_next_match`] to iterate over all of the
  #    *matches* in the order that they were found. Each match contains the
  #    index of the pattern that matched, and an array of captures. Because
  #    multiple patterns can match the same set of nodes, one match may contain
  #    captures that appear *before* some of the captures from a previous match.
  # 2. Repeatedly call [`ts_query_cursor_next_capture`] to iterate over all of the
  #    individual *captures* in the order that they appear. This is useful if
  #    don't care about which pattern matched, and just want a single ordered
  #    sequence of captures.
  #
  # If you don't care about consuming all of the results, you can stop calling
  # [`ts_query_cursor_next_match`] or [`ts_query_cursor_next_capture`] at any point.
  #  You can then start executing another query on another node by calling
  #  [`ts_query_cursor_exec`] again.
  fun ts_query_cursor_new : TSQueryCursor*

  # Delete a query cursor, freeing all of the memory that it used.
  fun ts_query_cursor_delete(TSQueryCursor*) : Void

  # Start running a given query on a given node.
  fun ts_query_cursor_exec(self : TSQueryCursor*, query : TSQuery*, node : TSNode) : Void

  # Manage the maximum number of in-progress matches allowed by this query
  # cursor.
  #
  # Query cursors have an optional maximum capacity for storing lists of
  # in-progress captures. If this capacity is exceeded, then the
  # earliest-starting match will silently be dropped to make room for further
  # matches. This maximum capacity is optional — by default, query cursors allow
  # any number of pending matches, dynamically allocating new space for them as
  # needed as the query is executed.
  fun ts_query_cursor_did_exceed_match_limit(TSQueryCursor*) : Bool
  fun ts_query_cursor_match_limit(TSQueryCursor*) : LibC::UInt32T
  fun ts_query_cursor_set_match_limit(self : TSQueryCursor*, limit : LibC::UInt32T) : Void

  # Set the maximum duration in microseconds that query execution should be allowed to
  # take before halting.
  #
  # If query execution takes longer than this, it will halt early, returning NULL.
  # See [`ts_query_cursor_next_match`] or [`ts_query_cursor_next_capture`] for more information.
  fun ts_query_cursor_set_timeout_micros(
    self : TSQueryCursor*, timeout_micros : LibC::UInt64T
  ) : Void

  # Get the duration in microseconds that query execution is allowed to take.
  #
  # This is set via [`ts_query_cursor_set_timeout_micros`].
  fun ts_query_cursor_timeout_micros(self : TSQueryCursor*) : LibC::UInt64T

  # Set the range of bytes or (row, column) positions in which the query
  # will be executed.
  fun ts_query_cursor_set_byte_range(
    self : TSQueryCursor*, start_byte : LibC::UInt32T, end_byte : LibC::UInt32T
  ) : Void
  fun ts_query_cursor_set_point_range(
    self : TSQueryCursor*, start_point : TSPoint, end_point : TSPoint
  ) : Void

  # Advance to the next match of the currently running query.
  #
  # If there is a match, write it to `*match` and return `true`.
  # Otherwise, return `false`.
  fun ts_query_cursor_next_match(self : TSQueryCursor*, match : TSQueryMatch*) : Bool
  fun ts_query_cursor_remove_match(self : TSQueryCursor*, match_id : LibC::UInt32T) : Void

  # Advance to the next capture of the currently running query.
  #
  # If there is a capture, write its match to `*match` and its index within
  # the matche's capture list to `*capture_index`. Otherwise, return `false`.
  fun ts_query_cursor_next_capture(
    self : TSQueryCursor*, match : TSQueryMatch*, capture_index : LibC::UInt32T*
  ) : Bool

  # Set the maximum start depth for a query cursor.
  #
  # This prevents cursors from exploring children nodes at a certain depth.
  # Note if a pattern includes many children, then they will still be checked.
  #
  # The zero max start depth value can be used as a special behavior and
  # it helps to destructure a subtree by staying on a node and using captures
  # for interested parts. Note that the zero max start depth only limit a search
  # depth for a pattern's root node but other nodes that are parts of the pattern
  # may be searched at any depth what defined by the pattern structure.
  #
  # Set to `UINT32_MAX` to remove the maximum start depth.
  fun ts_query_cursor_set_max_start_depth(
    self : TSQueryCursor*, max_start_depth : LibC::UInt32T
  ) : Void

  # Language

  # Get another reference to the given language.
  fun ts_language_copy(TSLanguage*) : TSLanguage*

  # Free any dynamically-allocated resources for this language, if
  # this is the last reference.
  fun ts_language_delete(TSLanguage*) : Void

  # Get the number of distinct node types in the language.
  fun ts_language_symbol_count(TSLanguage*) : LibC::UInt32T

  # Get the number of valid states in this language.
  fun ts_language_state_count(TSLanguage*) : LibC::UInt32T

  # Get a node type string for the given numerical id.
  fun ts_language_symbol_name(self : TSLanguage*, symbol : TSSymbol) : LibC::Char*

  # Get the numerical id for the given node type string.
  fun ts_language_symbol_for_name(
    self : TSLanguage*, string : LibC::Char*, length : LibC::UInt32T, is_named : Bool
  ) : TSSymbol

  # Get the number of distinct field names in the language.
  fun ts_language_field_count(TSLanguage*) : LibC::UInt32T

  # Get the field name string for the given numerical id.
  fun ts_language_field_name_for_id(self : TSLanguage*, id : TSFieldId) : LibC::Char*

  # Get the numerical id for the given field name string.
  fun ts_language_field_id_for_name(
    self : TSLanguage*, name : LibC::Char*, name_length : LibC::UInt32T
  ) : TSFieldId

  # Check whether the given node type id belongs to named nodes, anonymous nodes,
  # or a hidden nodes.
  #
  # See also [`ts_node_is_named`]. Hidden nodes are never returned from the API.
  fun ts_language_symbol_type(self : TSLanguage*, symbol : TSSymbol) : TSSymbolType

  # Get the ABI version number for this language. This version number is used
  # to ensure that languages were generated by a compatible version of
  # Tree-sitter.
  #
  # See also [`ts_parser_set_language`].
  fun ts_language_version(TSLanguage*) : LibC::UInt32T

  # Get the next parse state. Combine this with lookahead iterators to generate
  # completion suggestions or valid symbols in error nodes. Use
  # [`ts_node_grammar_symbol`] for valid symbols.
  fun ts_language_next_state(self : TSLanguage*, state : TSStateId, symbol : TSSymbol) : TSStateId

  # Lookahead Iterator

  # Create a new lookahead iterator for the given language and parse state.
  #
  # This returns `NULL` if state is invalid for the language.
  #
  # Repeatedly using [`ts_lookahead_iterator_next`] and
  # [`ts_lookahead_iterator_current_symbol`] will generate valid symbols in the
  # given parse state. Newly created lookahead iterators will contain the `ERROR`
  # symbol.
  #
  # Lookahead iterators can be useful to generate suggestions and improve syntax
  # error diagnostics. To get symbols valid in an ERROR node, use the lookahead
  # iterator on its first leaf node state. For `MISSING` nodes, a lookahead
  # iterator created on the previous non-extra leaf node may be appropriate.
  fun ts_lookahead_iterator_new(self : TSLanguage*, state : TSStateId) : TSLookaheadIterator*

  # Delete a lookahead iterator freeing all the memory used.
  fun ts_lookahead_iterator_delete(TSLookaheadIterator*) : Void

  # Reset the lookahead iterator to another state.
  #
  # This returns `true` if the iterator was reset to the given state and `false`
  # otherwise.
  fun ts_lookahead_iterator_reset_state(self : TSLookaheadIterator*, state : TSStateId) : Bool

  # Reset the lookahead iterator.
  #
  # This returns `true` if the language was set successfully and `false`
  # otherwise.
  fun ts_lookahead_iterator_reset(
    self : TSLookaheadIterator*, language : TSLanguage*, state : TSStateId
  ) : Bool

  # Get the current language of the lookahead iterator.
  fun ts_lookahead_iterator_language(TSLookaheadIterator*) : TSLanguage*

  # Advance the lookahead iterator to the next symbol.
  #
  # This returns `true` if there is a new symbol and `false` otherwise.
  fun ts_lookahead_iterator_next(TSLookaheadIterator*) : Bool

  # Get the current symbol of the lookahead iterator;
  fun ts_lookahead_iterator_current_symbol(TSLookaheadIterator*) : TSSymbol

  # Get the current symbol type of the lookahead iterator as a null terminated
  # string.
  fun ts_lookahead_iterator_current_symbol_name(TSLookaheadIterator*) : LibC::Char*

  # WebAssembly Integration

  # NOTE(margret): not binding for now

  # Global Configuration

  # NOTE(margret): not binding for now
end