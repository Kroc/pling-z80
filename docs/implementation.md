# Pling! Implementation Considerations

Here we will discuss an approach to implementing the _Pling!_ language on a Z80 / eZ80 processor. Other processors would probably require vastly different approaches, particularly the 6502, but this document should give an idea on how the language is well designed for constrained systems.

The Z80 has a 16-bit address bus and is therefore limited to 64KB of RAM / address space. Z80 systems with > 64KB RAM have to use memory banking and these are not standardised in any way. The eZ80 is a modern Z80 with an optional extended addressing mode that allows for 24-bit addresses. Where implementation concerns differ for the two, this document will provide commentary on the different approaches expected.

This document is speculative and doesn't represent working code / design.

## Source:

_Pling!_ source code is represented as a list of _words_.  
Words are _Pling!_'s variant data type.

At the syntax level (regardless of implementation),  
these are the word types provided by _Pling!_:

- A function call `echo` / lambda `:` ... `;`
- A number, `0`, `$00`, `%00000000`
- A string `"` ... `"`
- An expression `(` ... `)`
- A list `[` ... `]`
- A struct `{` ... `}` (TODO)

_Pling!_ source code is designed to be assembled into a compact, binary form with a single-pass, forward-only assembler without look-ahead; that is, any token can be identified without the need to know what the next token is.

It should be possible to assemble a file by reading one byte at a time from disk and without reading the entire file into RAM.

Like _Forth_, every token is separated by whitespace.  
Any non-whitespace character is a valid character in a token.

    : each word is a token 1 2 3 4 ;

There are two exceptions to this made in the name of programmer comfort and the fact that we are assembling code to be interpreted later rather than interpreting as we parse (i.e. _Forth_): Comments and Strings

* **Comments:**

  Comments begin with a hash mark `#` and a space. The space is required after the hash mark so long as the end of the line doesn't immediately follow. Once the comment marker occurs, the rest of the line can be read in and skipped

* **Strings:**

  Strings in _Pling!_ look like strings in any other language rather than _Forth_'s oddly disconnected strings (` " Space after opening quote mark!"`), a concession to fit its simple design.

  When a token begins with a quote-mark, keep reading bytes until a closing quote-mark, this includes line-breaks! The whole string is taken as one token

  > TODO: escape codes, cannot yet include quote-marks in strings.

Therefore, the tokeniser must skip leading whitespace until it comes upon a character and handle the special cases: comments and strings, before resorting to a standard token.

This EBNF grammar presents the tokeniser's view of the incoming bytes, but doesn't enforce program structure, for example pairing `:` with `;`, that happens during parsing, although tokenising and parsing may be happening at the same time depending on implementation.

```ebnf
eol         = [ "\r" + ] , "\n" ;
spaces      = "\s" + ;                  (* space + tab, no eol      *)
whitespace  = ( spaces | eol ) + ;      (* spaces and newlines      *)
letter      = "\S" ;                    (* non-whitespace character *)

(* only comments distinguish end-of-line so Pling! source code
   is simply a stream of tokens and whitespace *)
source      = { [ whitespace ]          (* leading whitespace       *)
              , { token , whitespace }  (* separated by whitespace  *)
              , [ comment ]             (* optional comment         *)
              } ;

(* comments begin with # and run to the end of the line *)
comment     = "#" , spaces , { ? not-eol ? } , eol
            | "#" , eol ;

(* tokens are made from a group of any non-whitespace characters
   or the special case handling of numbers & strings *)
token       = ( number | string | letter + ) ;

(* TODO: we won't include floats initially *)
number      = integer | hexadecimal | binary ;
integer     = first-digit , { digits } ;
hexadecimal = "$" , hexit + ;
binary      = "%" , bit + ;

first-digit = "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" ;
digits      = "0" | first-digit ;
hexit       = digits | "a" | "b" | "c" | "d" | "e" | "f"
                     | "A" | "B" | "C" | "D" | "E" | "F" ;
bit         = "0" | "1" ;

(* TODO: strings should support escape codes,
   no way to embed a quote mark in a string a.t.m. *)
string      = '"' , { ? any-character ? } , '"' ;
```

### The Problem of Order

As each token is ingested from the source file, it is categorised according to its type and assembled into a binary representation.

As we assemble one list, we will often need to start another list and then return to where we were. Consider an `if` function-call that is followed by an expression and a lambda to execute when true; the lambda is not inline as there would have to be a means of skipping over it.

                           +---- - - -
                    .----> | ...
                    |      +---- - - -
                    |      
    +----+------+---+--+---- - - -
    | if | expr | true |...
    +----+--+---+------+---- - - -
            |
            |      +---- - - -
            '----> | ...
                   +---- - - -

Therefore the assembler must be able to manage multiple on-going lists of unknown length.

You cannot simply begin a new list a little ways off in memory hoping that when you return to where you were, there's enough headroom to continue; you cannot know ahead of time how long a list will be and if you have to keep shifting lists in memory to make additional room the process will not only be slow but may run out of memory.

Every byte read *must* be handled and put somewhere as there is no way to go 'back' to it (the whole source file is not in RAM), therefore you cannot defer handling of a token until later.

### Intermediate Representation

_Pling!_'s solution to indeterminate order is an intermediate representation using a linked-list of word-types on a simple heap (i.e. no allocator).

A heap is a "pile" of data much like a stack where data is added to the top (or end, if we consider it horizontal) and only the top-most data can be removed.

               top of heap ->|
    ----+------+------+------+
    ... | data | data | data |  (free space)
    ----+------+------+------+----------------->

A heap is useful because it has no "gaps" (unused space) but there are severe restrictions -- only the top-most item can be expanded or contracted, and data can only be added or removed in-order. You cannot place two items on the heap and then remove the older (underneath) item first; all data is bound by scope.

## The Tokeniser

As a token is read in, it is written to the top of the heap as a length-prefixed string.

    ----+------------------------+
    ... | str-len ¦ token-string |
    ----+------------------------+

The first character of the token is then looked at to determine the token-type:

### Numbers

If the token is a number type, marked by a `$`, `%` or numerical digit then it is converted from a string into a number literal and the token string on the heap is overwritten with a 1 byte type field and then the number literal in however many bytes are required as given by the type:

    ----+------------------------+
    ... | str-len ¦ token-string |
    ----+------------------------+
        |<------ discarded ----- ^
        v
    ----+-------------------+
    ... | num-type ¦ number |
    ----+-------------------+

The datum of the word has been captured but it is not the word itself that can be executed. We now add a word structure to the heap.

        |<---   datum   --->|<---           word struct          --->|
    ----+-------------------+----------------------------------------+
    ... | num-type ¦ number | type ¦ data-ptr ¦ next-ptr ¦ row ¦ col |
    ----+-------------------+-----------+----------------------------+
        ^                               |
        '-------------------------------'

The word structure includes a 1-byte type that indicates that this word is a number. The data-pointer contains the address in the heap of the word's data. The next-pointer will point to the next word in the current list (when reached), and the row and column fields contain the line-number and column of text in the source file where the original word occurs (for printing of error messages).

### Strings

As a string is read in it is appended to the end of the heap like so; again with the 1-byte reserved at the head. The opening quote-mark is included as the first character of every token is always included, however the final quote-mark is excluded.

    ----+----------------------------------------------------------+
    ... | reserved ¦ " ¦ H ¦ e ¦ l ¦ l ¦ o ¦   ¦ w ¦ o ¦ r ¦ l ¦ d |
    ----+----------------------------------------------------------+

Strings can be much, much longer than other tokens, so once the entire string has been read in, the first *two* bytes of the string are replaced with the string-length. Note how this overwrites the opening quote-mark.

    ----+--------------------------------------------------------+
    ... | str-length ¦ H ¦ e ¦ l ¦ l ¦ o ¦   ¦ w ¦ o ¦ r ¦ l ¦ d |
    ----+--------------------------------------------------------+

Now that the string has been captured on the heap, the word structure is appended.

        |<---  string  --->|<---           word struct          --->|
    ----+------------------+----------------------------------------+
    ... | str-len ¦ string | type ¦ data-ptr ¦ next-ptr ¦ row ¦ col |
    ----+------------------+------------+---------------------------+
        ^                               |
        '-------------------------------'

### Lambdas

Since a lambda is a list within a list, a word-structure is placed on the heap that will point to the next word where the lambda will be assembled (be aware that a number / string literal might be added to the heap, before the next word-struct).

        |<---          word struct           --->|
    ----+----------------------------------------+---------------
    ... | type ¦ data-ptr ¦ next-ptr ¦ row ¦ col | ... lambda ...
    ----+------------+---------------------------+---------------
        (lambda)     |                              ^
                     '------------------------------'

The location [in the heap] of the parent list is remembered for later and the lambda is assembled, word by word, as any other. When that list terminates, the location of the parent list is recalled and the next-pointer is updated to point to the top of the heap where the parent list may continue.

                                .------------------------------.
                                |                              v
    ----+-----------------------+----------------+----------+----
    ... | type ¦ data-ptr ¦ next-ptr ¦ row ¦ col | (lambda) | ...
    ----+------------+---------------------------+----------+----
                     |                             ^
                     '-----------------------------'

It is the chaining of the data and next fields that allows lists to be built out of order and for lists-within-lists of any length and any depth of nesting, memory permitting, to be handled.

### Function Calls

A function call is simply a link to another list (Lambda) that has already been defined previously.

                    ----+----------------------------------------+----
                    ... | type ¦ data-ptr ¦ next-ptr ¦ row ¦ col | ...
                    ----+------------+----------+----------------+----
                                     |          |                   ^
        .----------------------------'          '-------------------'
        v
    ----+----------------------------------------+----
    ... | type ¦ data-ptr ¦ next-ptr ¦ row ¦ col | ...
    ----+-----------------------+----------------+----
                                |                   ^
                                '-------------------'

The heading below describes the process of mapping function names in string form from the source code to the existing assembled code.

## The Dictionary

A dictionary is a lookup of symbol names to their position within the assembled code. It is named after _Forth_'s dictionary which calls tokens "words". When a token is not a literal value (like a string or number), the dictionary is searched for the symbol name. The dictionary is always searched _backwards_, that is, the most recently defined word first to the oldest word last. This allows for simple scope resolution, with newer defined words overriding older ones if they share the same name.

The _Pling!_ keyword `fn` defines a new function; it is a special keyword that only the assembler understands and does not exist in the assembled code when running.

When the parser comes across the `fn` keyword, it reads the next token as the name of the function to use. A dictionary entry is created on top of the heap, pointing to the function name just captured.

        |< function-name >|<---        dictionary-entry        --->|
    ----+-----------------+----------------------------------------+
    ... | len ¦ f | o | o | type ¦ data-ptr ¦ next-ptr ¦ row ¦ col |
    ----+-----------------+------------+---------------------------+
        ^                              |
        '------------------------------'

The type field is used for private flags. The data field points to the beginning of the function-name string. The "next" field points to the *previous dictionary entry* on the heap, not the beginning of the function lambda; the function lambda is assumed to immediately follow the dictionary entry:

        |<---        dictionary-entry        --->|< lambda >|
    ----+----------------------------------------+----------+
    ... | type ¦ data-ptr ¦ next-ptr ¦ row ¦ col |    ...   |
    ----+-----------------------+----------------+----------+
                                |
    (previous dict-entry) <-----'

The `next-ptr` field of the previous entry is not updated until after the function is defined and a non function-definition occurs. That is, the previous entry skips 'over' the function definition.

        .----------------------------.
        |                            |
    +---+--+---------------------+---v--+----
    | word | dict-entry ¦ lambda | word | ...
    +------+---+----^------------+------+----
               |    |
    <- - - ----'    '------- (dict-entry)

When a function name token is encountered, the chain of dictionary entries is followed to find the function. This is why dictionary entries are linked backwards through the heap, to search newest first.

The language grammar is designed to not require forward-references, that is, calling a function before it's been defined. You must define a function before it can be called. This avoids having to do a second pass on the code to fix up forward-references and to minimise the amount of meta-data that needs to be held during assembly.

A more efficient method of building the dictionary and searching it might be used in the future, however the current method allows building directly on the heap during tokenisation without having to place a dictionary structure somewhere in memory that may grow too large, or that the heap might run into!