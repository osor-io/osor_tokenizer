#import "Basic";
#import "Math";
#import,dir "../osor_tokenizer";



main :: ()
{
    simple();
    one_at_a_time();
    lets_do_some_code();
}



simple :: ()
{
    print_example_name("Simple");

    tokenizer : Tokenizer;
    init_tokenizer(*tokenizer, "1 123.123 abc");

    tokens := tokenize_all_tokens(*tokenizer);
    defer array_reset(*tokens);

    for tokens print(" [%] = % - %\n", it_index, it.type, it.text);
}



one_at_a_time :: ()
{
    print_example_name("One Token At A Time");

    tokenizer : Tokenizer;
    init_tokenizer(*tokenizer, "1 123.123 abc");

    while true
    {
        token, error := tokenize_one_token(*tokenizer);
        if token.type == .INVALID
        {
            print("Error while tokenizing: %\n", error);
            break;
        }
        else if token.type == .END
        {
            print("Ran out of tokens\n");
            break;
        }
        else
        {
            print(" % - %\n", token.type, token.text);
        }
    }
}



lets_do_some_code :: ()
{
    print_example_name("Let's Do Some Code");

    //
    // Gonna parse some code-looking stuff cause why not
    //
    // See https://youtu.be/fIPO4G42wYE?si=yaLHn69cpr9ON1M_&t=464 for some more
    // context of where this comes from and why you'd do this
    //

    TEXT :: #string DONE
    /*
        Some code here for the tokenizer to ingest, and then we'll parse it into some
        sort of toy executable-ish representation.

        Note that we're using comments, both block and single-line, the tokenizer ignores
        them by default based on the parameters to tokenize_all_tokens/tokenize_one_token
    */
    a = 1 + 2;                 // Simple math with an assignment
    a + b * (c + d[1]);        // Some more complex math
    (a + 1)[123];              // Disambiguating array indexing and parentheses
    b = my_procedure(123);     // Can do procedure calls too, in this case the parentheses is treated as a binary operator
    (x[123 * (a + b)])(123);   // This is a very convoluted way to index an array of procedures and call it
    my_procedure(a, b, c + d); // We can parse comma-separated arguments to a procedure, and they would get evaluated left-to-right
    DONE

    tokenizer : Tokenizer;
    init_tokenizer(*tokenizer, TEXT);

    tokens := tokenize_all_tokens(*tokenizer);
    defer array_reset(*tokens);

    if tokens
    {
        using parser : Parser;
        parser.token = tokens.data;
        while token && token.type != .END
        {
            first_token := token.*;
            node_index := parse_expression(*parser);
            last_token := token.*;
            assert(token.type == .SEMICOLON);
            token += 1;

            print("The following code: %\n", get_text_between_tokens_including_last(first_token, last_token));
            print("Generates the tree:\n");
            print_nodes(*parser, node_index);
            print("And the SSA:\n");
            /* avengers? */ assemble(*parser, node_index);
            print("\n");
        }
    }
}

Parser :: struct
{
    token : *Token;
    nodes : [..]Node;
}

Node :: struct
{
    Identifier :: struct
    {
        //
        // You'd have something here to retrieve the symbol
        //
    }

    Literal :: struct
    {
        //
        // You'd have something here to retrieve the literal value
        //
    }

    Unary_Operator :: struct
    {
        Type :: enum
        {
            INVALID;

            BLOCK;
            PARENTHESES;
        }
        type : Type = .INVALID;
        content : int = -1;
    }

    Binary_Operator :: struct
    {
        Type :: enum
        {
            INVALID;

            PROCEDURE_CALL;
            SUBSCRIPT;

            MULTIPLY;
            DIVIDE;

            ADD;
            SUBTRACT;

            COMMA;
            ASSIGN;
        }
        type : Type = .INVALID;
        left  : int = -1;
        right : int = -1;
    }

    type : Type;
    using per_node_type : union
    {
        identifier : Identifier;
        literal : Literal;
        unary_operator : Unary_Operator;
        binary_operator : Binary_Operator;
    }
    token : Token;
    register := -1;
}

add_node :: (using parser : *Parser, $T : Type, node_token : Token) -> *T, int
{
    node_index := nodes.count;
    node := array_add(*nodes);
    node.* = .{};
    node.token = node_token;
    node.type = T;
    node_data := cast(*T)*node.per_node_type;
    ini :: initializer_of(T);
    #if ini then ini(node_data);
            else memset(node_data, 0, size_of(T));
    return node_data, node_index;
}

parse_expression :: (using parser : *Parser, minimum_precedence := S64_MIN) -> int
{
    parse_unary_operator :: (token : Token) -> operator_type : Node.Unary_Operator.Type, precedence : int, closing_token_type : Token.Type = .INVALID
    {
        if token.type == 
        {
            case .OPEN_BRACES;      return .BLOCK,        2, .CLOSE_BRACES;
            case .OPEN_PARENTHESES; return .PARENTHESES,  2, .CLOSE_PARENTHESES;
        }
        return .INVALID, S64_MIN;
    }

    parse_binary_operator :: (token : Token) -> operator_type : Node.Binary_Operator.Type, precedence : int, closing_token_type : Token.Type = .INVALID
    {
        if token.type == 
        {
            case .OPEN_PARENTHESES; return .PROCEDURE_CALL, 2, .CLOSE_PARENTHESES;
            case .OPEN_BRACKETS;    return .SUBSCRIPT,      2, .CLOSE_BRACKETS;

            case .ASTERISK;      return .MULTIPLY,  1;
            case .FORWARD_SLASH; return .DIVIDE,    1;

            case .PLUS;          return .ADD,       0;
            case .MINUS;         return .SUBTRACT,  0;

            case .COMMA;         return .COMMA,    -1;

            case .EQUALS;        return .ASSIGN,   -2;
        }
        return .INVALID, S64_MIN;
    }

    parse_leaf :: (using parser : *Parser) -> int
    {
        operator_type, precedence, closing_token_type := parse_unary_operator(token);
        leaf_token := token.*;
        token += 1;
        if operator_type != .INVALID
        {
            contents := -1;
            if closing_token_type == .INVALID
            {
                contents = parse_expression(parser, precedence);
            }
            else
            {
                contents = parse_expression(parser);
                assert(token.type == closing_token_type);
                token += 1;
            }

            node, node_index := add_node(parser, Node.Unary_Operator, leaf_token);
            node.type = operator_type;
            node.content = contents;
            return node_index;
        }
        else
        {
            node_index : int;
            if leaf_token.type ==
            {
                case .IDENTIFIER;
                node:, node_index = add_node(parser, Node.Identifier, leaf_token);

                case .STRING;
                node:, node_index = add_node(parser, Node.Literal, leaf_token);

                case .INTEGER;
                node:, node_index = add_node(parser, Node.Literal, leaf_token);

                case .FLOAT;
                node:, node_index = add_node(parser, Node.Literal, leaf_token);

                case;
                assert(false, "Unexpected token %", leaf_token);
            }
            return node_index;
        }
    }

    left := parse_leaf(parser);
    while true
    {
        operator_type, precedence, closing_token_type := parse_binary_operator(token);
        if operator_type == .INVALID then return left;
        if precedence > minimum_precedence
        {
            operator_token := token.*;

            token += 1;

            right := -1;
            if closing_token_type == .INVALID
            {
                right = parse_expression(parser, precedence);
            }
            else
            {
                right = parse_expression(parser);
                assert(token.type == closing_token_type);
                token += 1;
            }

            node, node_index := add_node(parser, Node.Binary_Operator, operator_token);
            node.type = operator_type;
            node.left = left;
            node.right = right;

            left = node_index;
        }
        else
        {
            break;
        }
    }
    return left;
}



print_nodes :: (using parser : *Parser, node_index : int)
{
    print_node :: (using parser : *Parser, node_index : int, depth := 0)
    {
        print_padded :: (format_string : string, args : ..Any) #expand
        {
            builder: String_Builder;
            for 0..depth-2 append(*builder, "    ");
            if depth > 0 then append(*builder, "└───");
            print_to_builder(*builder, format_string, ..args);
            append(*builder, "\n");
            write_builder(*builder);
        } @PrintLike

        if node_index >= 0
        {
            node := nodes[node_index];
            if node.type ==
            {
                case Node.Identifier; 
                print_padded("%", node.token.text);

                case Node.Literal; 
                print_padded("%", node.token.text);

                case Node.Unary_Operator;
                print_padded("%", node.token.text);
                print_node(parser, node.unary_operator.content, depth + 1);

                case Node.Binary_Operator;
                print_padded("%", node.token.text);
                print_node(parser, node.binary_operator.right, depth + 1);
                print_node(parser, node.binary_operator.left, depth + 1);

                case; assert(false);
            }
        }
        else
        {
            print_padded("null");
        }
    }
    print_node(parser, node_index);
}

assemble :: (using parser : *Parser, node_index : int)
{
    register_count := 0;
    assemble_one :: (using parser : *Parser, node_index : int, register_count : *int)
    {
        node := *nodes[node_index];
        if node.type ==
        {
            case Node.Identifier; 
            node.register = register_count.*; register_count.* += 1;
            print("$% = %\n", node.register, node.token.text);

            case Node.Literal; 
            node.register = register_count.*; register_count.* += 1;
            print("$% = %\n", node.register, node.token.text);

            case Node.Unary_Operator; 
            if #complete node.unary_operator.type ==
            {
                case .INVALID; assert(false);
                case .BLOCK;

                case .PARENTHESES;
                node_content := *nodes[node.unary_operator.content];
                if node_content.register == -1 then assemble_one(parser, node.unary_operator.content, register_count);
                node.register = node_content.register; // Parens don't do anything, just steal the register from the contents
            }

            case Node.Binary_Operator;
            node_left  := *nodes[node.binary_operator.left];
            node_right := *nodes[node.binary_operator.right];
            if node_left.register  == -1 then assemble_one(parser, node.binary_operator.left,  register_count);
            if node_right.register == -1 then assemble_one(parser, node.binary_operator.right, register_count);
            node.register = register_count.*; register_count.* += 1;
            if #complete node.binary_operator.type ==
            {
                case .INVALID; assert(false);

                case .PROCEDURE_CALL;
                print("$% = $%($%)\n", node.register, node_left.register, node_right.register);

                case .SUBSCRIPT;
                print("$% = $%[$%]\n", node.register, node_left.register, node_right.register);

                case .MULTIPLY; #through;
                case .DIVIDE;   #through;
                case .ADD;      #through;
                case .SUBTRACT;
                print("$% = $% % $%\n", node.register, node_left.register, node.token.text, node_right.register);

                case .COMMA;
                print("$% = $%, $%\n", node.register, node_left.register, node_right.register);

                case .ASSIGN;
                print("$% = $% <- $%\n", node.register, node_left.register, node_right.register);
            }

            case; assert(false);
        }
    }
    assemble_one(parser, node_index, *register_count);
}



#scope_file



print_example_name :: (name : string) #expand
{
    for 0..(8 + name.count)-1 print("#");
    print("\n### % ###\n", name);
    for 0..(8 + name.count)-1 print("#");
    print("\n");
    `defer print("\n\n\n");
}



/*


##############
### Simple ###
##############
 [0] = INTEGER - 1
 [1] = FLOAT - 123.123
 [2] = IDENTIFIER - abc
 [3] = END -



###########################
### One Token At A Time ###
###########################
 INTEGER - 1
 FLOAT - 123.123
 IDENTIFIER - abc
Ran out of tokens



##########################
### Let's Do Some Code ###
##########################
The following code: a = 1 + 2;
Generates the tree:
=
└───+
    └───2
    └───1
└───a
And the SSA:
$0 = a
$1 = 1
$2 = 2
$3 = $1 + $2
$4 = $0 <- $3

The following code: a + b * (c + d[1]);
Generates the tree:
+
└───*
    └───(
        └───+
            └───[
                └───1
                └───d
            └───c
    └───b
└───a
And the SSA:
$0 = a
$1 = b
$2 = c
$3 = d
$4 = 1
$5 = $3[$4]
$6 = $2 + $5
$7 = $1 * $6
$8 = $0 + $7

The following code: (a + 1)[123];
Generates the tree:
[
└───123
└───(
    └───+
        └───1
        └───a
And the SSA:
$0 = a
$1 = 1
$2 = $0 + $1
$3 = 123
$4 = $2[$3]

The following code: b = my_procedure(123);
Generates the tree:
=
└───(
    └───123
    └───my_procedure
└───b
And the SSA:
$0 = b
$1 = my_procedure
$2 = 123
$3 = $1($2)
$4 = $0 <- $3

The following code: (x[123 * (a + b)])(123);
Generates the tree:
(
└───123
└───(
    └───[
        └───*
            └───(
                └───+
                    └───b
                    └───a
            └───123
        └───x
And the SSA:
$0 = x
$1 = 123
$2 = a
$3 = b
$4 = $2 + $3
$5 = $1 * $4
$6 = $0[$5]
$7 = 123
$8 = $6($7)

The following code: my_procedure(a, b, c + d);
Generates the tree:
(
└───,
    └───+
        └───d
        └───c
    └───,
        └───b
        └───a
└───my_procedure
And the SSA:
$0 = my_procedure
$1 = a
$2 = b
$3 = $1, $2
$4 = c
$5 = d
$6 = $4 + $5
$7 = $3, $6
$8 = $0($7)



*/
