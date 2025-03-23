# :coin: A Tokenizing Module for Jai

A simple tokenizing module for the Jai programming language. You can check the code in [module.jai](module.jai) and a few examples of how to use them in [example.jai](example.jai).

## How To

The idea is to take text and transform it to a set of tokens that are easier to work with for parsing purposes. To start you'd initialize a `Tokenizer` which just contains the running data used as we generate the tokens:
```
text := "1 123.123 abc";
tokenizer : Tokenizer;
init_tokenizer(*tokenizer, text);
```
Then you can retrieve an array of all tokens by calling `tokenize_all_tokens`:
```
tokens := tokenize_all_tokens(*tokenizer);
for tokens do_something_with(token);
```
Alternatively you could request one token at a time and handle them as they come:
```
while true
{
    token, error := tokenize_one_token(*tokenizer);
    if token.type == .INVALID || token.type == .END then break;
    do_something_with(token);
}
```
Some running examples of this in [example.jai](example.jai), including some toy parser for some code.

## License

I want people to be able to just use this without thinking about licensing, although give me a shout if you do use it and attribution is appreciated 😊. Replicating STB's (https://github.com/nothings/stb) licensing stuff where you can choose to use public domain or MIT.
