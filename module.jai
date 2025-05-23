


#import "Basic";
#import "String";
#import "Unicode";



Token :: struct
{
    Type :: enum
    {
        INVALID;

        WHITESPACE;
        IDENTIFIER;
        COMMENT;
        INTEGER;
        FLOAT;
        BOOL;
        STRING;

        OPEN_PARENTHESES; 
        CLOSE_PARENTHESES;
        OPEN_BRACES; 
        CLOSE_BRACES;
        OPEN_BRACKETS; 
        CLOSE_BRACKETS;
        LESS_THAN;
        MORE_THAN;
        INTERROGATION;
        EXCLAMATION;
        AT_SIGN;
        EQUALS;
        PLUS;
        MINUS;
        ASTERISK;
        FORWARD_SLASH;
        BACK_SLASH;
        VERTICAL_SLASH;
        DOT;
        COMMA;
        SEMICOLON;
        COLON;
        HASH;
        AMPERSAND;
        PERCENT;
        TILDE;
        CARET;

        END;
    }
    type := Type.INVALID;
    text := "not available";
    line : Line;
}



Line :: struct
{
    number := -1;
    text := "not available";
}



Tokenizer :: struct
{
    text : string;
    current : string;
    beginning_of_current_token : *u8;
    current_line : Line;
}



init_tokenizer :: (tokenizer : *Tokenizer, text : string)
{
    tokenizer.text = text;
    tokenizer.current = text;
    tokenizer.current_line.text.data = text.data;
    tokenizer.beginning_of_current_token = tokenizer.current.data;
    tokenizer.current_line.number = 1;
    found : bool;
    found, tokenizer.current_line.text = split_from_left_by_any(tokenizer.current, "\n\r\0");
}



tokenize_all_tokens :: (tokenizer : *Tokenizer, tokens_to_ignore : [] Token.Type = .[.WHITESPACE, .COMMENT]) -> []Token #must, success : bool, error : string
{
    //
    // @@TODO: Stop doing multiple allocations and reallocations here with the dynamic array.
    //
    // A way that would be cool would be to disable the temporary allocator use during tokenize_one_token. Then here
    // start the first token at the temporary allocator location, and grow it linearly. This way we can use the temporary
    // allocator without reallocating and copying all the elements. The thing is that we'd need to handle the current
    // buffer running out and the temporary allocator needing a new one (in which case we would need a copy indeed).
    //
    tokens : [..] Token;
    while true
    {
        token, error := tokenize_one_token(tokenizer, tokens_to_ignore);
        if token.type == .INVALID
        {
            array_reset(*tokens);
            return .[], false, error;
        }
        else
        {
            array_add(*tokens, token);
            if token.type == .END then break;
        }
    }
    return tokens, true, "";
}



tokenize_one_token :: (tokenizer : *Tokenizer, tokens_to_ignore : [] Token.Type = .[.WHITESPACE, .COMMENT]) -> Token, error : string
{
    get :: (tokenizer : *Tokenizer) -> u8
    {
        if tokenizer.current.count <= 0 then return 0;
        return tokenizer.current.data.*;
    }

    peek :: (tokenizer : *Tokenizer, forward := 1) -> u8
    {
        if forward >= tokenizer.current.count then return 0;
        return (tokenizer.current.data + forward).*;
    }

    advance :: () #expand
    {
        if tokenizer.current.count <= 0 then `return .{}, error(tokenizer, "Unexpected end of text in line %, maybe a block like a string or comment aren't closed?", tokenizer.current_line);
        advancing_line := get(tokenizer) == #char "\n";
        tokenizer.current.data  += 1;
        tokenizer.current.count -= 1;
        if advancing_line
        {
            tokenizer.current_line.number += 1;
            found : bool;
            found, tokenizer.current_line.text = split_from_left_by_any(tokenizer.current, "\n\r\0");
        }
    }

    found_token :: (type : Token.Type) #expand
    {
        token : Token;
        token.type = type;
        token.line = tokenizer.current_line;
        token.text.data = tokenizer.beginning_of_current_token;
        token.text.count = tokenizer.current.data - tokenizer.beginning_of_current_token;
        tokenizer.beginning_of_current_token = tokenizer.current.data;
        ignore := false;
        for tokens_to_ignore  
            if token.type == it  
                ignore = true;
        if !ignore then result_token = token;
    }

    is_operator :: (tokenizer : *Tokenizer, $operator_string : string) -> bool
    {
        #assert(operator_string.count == 1);
        return get(tokenizer) == operator_string.data.*;
    }
    
    error :: (tokenizer : *Tokenizer, format : string, arguments : .. Any) -> string
    {
        user_message := tprint(format, ..arguments);
        complete_message := tprint("%\n    line %: %\n", user_message, tokenizer.current_line.number, tokenizer.current_line.text);
        return complete_message;
    } @PrintLike

    result_token : Token;

    using Token.Type;
    while tokenizer.current.count > 0
    {
        if is_space(get(tokenizer))
        {
            advance();
            while is_space(get(tokenizer)) advance();
            found_token(WHITESPACE);
        }
        else if get(tokenizer) == #char "/" && peek(tokenizer) == #char "/"
        {
            while get(tokenizer) != #char "\n" && get(tokenizer) != 0 advance();
            found_token(COMMENT);
        }
        else if get(tokenizer) == #char "/" && peek(tokenizer) == #char "*"
        {
            depth := 1;
            advance();
            advance();
            while true
            {
                if get(tokenizer) == #char "/" && peek(tokenizer) == #char "*"
                {
                    advance();
                    advance();
                    depth += 1;
                }
                else if get(tokenizer) == #char "*" && peek(tokenizer) == #char "/"
                {
                    advance();
                    advance();
                    depth -= 1;
                    if depth == 0 break;
                }
                else
                {
                    advance();
                }
            }
            found_token(COMMENT);
        }
        else if is_alpha(get(tokenizer)) || get(tokenizer) == #char "_"
        {
            advance();
            while is_alnum(get(tokenizer)) advance();
            found_token(IDENTIFIER);
            if result_token.text == "true" || result_token.text == "false" then result_token.type = BOOL;
        }
        else if get(tokenizer) == #char "0" && peek(tokenizer) == #char "b"
        {
            advance();
            advance();
            while is_binary_or_underscore(get(tokenizer)) advance();
            found_token(INTEGER);
        }
        else if get(tokenizer) == #char "0" && peek(tokenizer) == #char "x"
        {
            advance();
            advance();
            while is_hexadecimal_or_underscore(get(tokenizer)) advance();
            found_token(INTEGER);
        }
        else if is_digit(get(tokenizer)) || (get(tokenizer) == #char "." && is_digit(peek(tokenizer)))
        {
            has_floating_point := false; 
            while is_digit_or_underscore(get(tokenizer)) advance();
            if get(tokenizer) == #char "."
            {
                advance();
                has_floating_point = true; 
            }
            while is_digit_or_underscore(get(tokenizer)) advance();
            if has_floating_point then found_token(FLOAT); else found_token(INTEGER);
        }
        else if get(tokenizer) == #char "'"
        {
            advance();
            bytes_for_unicode_character := 1 + trailingBytesForUTF8[get(tokenizer)];
            for 0..bytes_for_unicode_character-1 advance();
            if get(tokenizer) != #char "'" then return .{}, error(tokenizer, "Malformed single unicode character");
            advance();
            found_token(INTEGER);
        }
        else if get(tokenizer) == #char "\""
        {
            advance();
            while true
            {
                if      get(tokenizer) == #char "\\" then advance();
                else if get(tokenizer) == #char "\"" then break;
                advance();
            }
            advance();
            found_token(STRING);
            result_token.text.count -= 2;
            result_token.text.data  += 1;
        }
        else if is_operator(tokenizer, "(")  { advance(); found_token(OPEN_PARENTHESES);  }
        else if is_operator(tokenizer, ")")  { advance(); found_token(CLOSE_PARENTHESES); }
        else if is_operator(tokenizer, "{")  { advance(); found_token(OPEN_BRACES);       }
        else if is_operator(tokenizer, "}")  { advance(); found_token(CLOSE_BRACES);      }
        else if is_operator(tokenizer, "[")  { advance(); found_token(OPEN_BRACKETS);     }
        else if is_operator(tokenizer, "]")  { advance(); found_token(CLOSE_BRACKETS);    }
        else if is_operator(tokenizer, "<")  { advance(); found_token(LESS_THAN);         }
        else if is_operator(tokenizer, ">")  { advance(); found_token(MORE_THAN);         }
        else if is_operator(tokenizer, "?")  { advance(); found_token(INTERROGATION);     }
        else if is_operator(tokenizer, "!")  { advance(); found_token(EXCLAMATION);       }
        else if is_operator(tokenizer, "@")  { advance(); found_token(AT_SIGN);           }
        else if is_operator(tokenizer, "=")  { advance(); found_token(EQUALS);            }
        else if is_operator(tokenizer, "+")  { advance(); found_token(PLUS);              }
        else if is_operator(tokenizer, "-")  { advance(); found_token(MINUS);             }
        else if is_operator(tokenizer, "*")  { advance(); found_token(ASTERISK);          }
        else if is_operator(tokenizer, "/")  { advance(); found_token(FORWARD_SLASH);     }
        else if is_operator(tokenizer, "\\") { advance(); found_token(BACK_SLASH);        }
        else if is_operator(tokenizer, "|")  { advance(); found_token(VERTICAL_SLASH);    }
        else if is_operator(tokenizer, ".")  { advance(); found_token(DOT);               }
        else if is_operator(tokenizer, ",")  { advance(); found_token(COMMA);             }
        else if is_operator(tokenizer, ";")  { advance(); found_token(SEMICOLON);         }
        else if is_operator(tokenizer, ":")  { advance(); found_token(COLON);             }
        else if is_operator(tokenizer, "#")  { advance(); found_token(HASH);              }
        else if is_operator(tokenizer, "&")  { advance(); found_token(AMPERSAND);         }
        else if is_operator(tokenizer, "%")  { advance(); found_token(PERCENT);           }
        else if is_operator(tokenizer, "~")  { advance(); found_token(TILDE);             }
        else if is_operator(tokenizer, "^")  { advance(); found_token(CARET);             }
        else
        {
            current_character := tokenizer.current;
            current_character.count = 1;
            return .{}, error(tokenizer, "Don't know what the hell this means: %", current_character);
        }

        if result_token.type != INVALID then return result_token, "";
    }
    found_token(END);
    return result_token, "";
}



get_text_between_tokens_including_last :: (first : Token, last : Token) -> string
{
    value : string;
    value.data = first.text.data;
    value.count = last.text.data + last.text.count - value.data;
    return value;
}



get_text_between_tokens_excluding_last :: (first : Token, one_past_last : Token) -> string
{
    value : string;
    value.data = first.text.data;
    value.count = one_past_last.text.data - value.data;
    return value;
}



token_to_integer :: (token : Token) -> value : u64, success : bool, error : string
{
    if token.type != .INTEGER then return 0, false, "The token to parse wasn't an integer";

    the_string := token.text;

    if begins_with(the_string, "'") && ends_with(the_string, "'")
    {
        unicode_string := the_string;
        unicode_string.count -= 2;
        unicode_string.data  += 1;
        utf32_integer, bytes_used, unicode_result := character_utf8_to_utf32(unicode_string.data, unicode_string.count);
        if bytes_used != unicode_string.count || unicode_result != .CONVERSION_OK
        {
            return 0, false, "Conversion between unicode literal to integer failed";
        }
        return utf32_integer, true, "";
    }

    base : u64 = 10;
    if begins_with(the_string, "0b")
    {
        the_string = advance(the_string, 2);
        base = 2;
    }
    else if begins_with(the_string, "0x")
    {
        the_string = advance(the_string, 2);
        base = 16;
    }

    sum : u64 = 0;
    add_checking_for_overflow :: (sum : u64, $base : u64, value : u64) -> u64 #expand
    {
        if sum > (~(cast(u64)0) / base)  then `return 0, false, "Number overflows an unsigned 64-bit integer";
        sum *= base;
        if sum > (~(cast(u64)0) - value) then `return 0, false, "Number overflows an unsigned 64-bit integer";
        sum += value;
        return sum;
    }
    if base ==
    {
        case 2;
        for c : cast([]u8)the_string
        {
            if c == #char "_" then continue;
            value : u8 = ---;
            if      c == #char "0" then value = 0;
            else if c == #char "1" then value = 1;
            else return 0, false, "Non base 2 value in base 2 number";
            sum = add_checking_for_overflow(sum, base = 2, value);
        }

        case 10;
        for c : cast([]u8)the_string
        {
            if c == #char "_" then continue;
            value : u8 = ---;
            if is_digit(c) then value = c - #char "0";
            else return 0, false, "Non base 10 value in base 10 number";
            sum = add_checking_for_overflow(sum, base = 10, value);
        }

        case 16;
        for c : cast([]u8)the_string
        {
            if c == #char "_" then continue;
            value: u8 = ---;
            if is_digit(c)                               then value = c - #char "0";
            else if (c >= #char "a") && (c <= #char "f") then value = c - #char "a" + 10;
            else if (c >= #char "A") && (c <= #char "F") then value = c - #char "A" + 10;
            else return 0, false, "Non base 16 value in base 16 number"; 
            sum = add_checking_for_overflow(sum, base = 16, value);
        }
    }

    return sum, true, "";
}



#scope_file



is_binary      :: (c : u8) -> bool { return c == #char "0" || c == #char "1"; }
is_hexadecimal :: (c : u8) -> bool { return is_digit(c) || (c >= #char "a" && c <= #char "f") || (c >= #char "A" && c <= #char "F"); }
is_digit_or_underscore       :: (c : u8) -> bool { return is_digit(c)       || c == #char "_"; }
is_binary_or_underscore      :: (c : u8) -> bool { return is_binary(c)      || c == #char "_"; }
is_hexadecimal_or_underscore :: (c : u8) -> bool { return is_hexadecimal(c) || c == #char "_"; }


