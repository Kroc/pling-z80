# Pling! Implementation Considerations

Here we will discuss an approach to implementing the _Pling!_ language on a Z80 / eZ80 processor. Other processors would probably require vastly different approaches, particularly the 6502, but this document should give an idea on how the language is well designed for constrained systems.

The Z80 has a 16-bit address bus and is therefore limited to 64KB of RAM / address space. Z80 systems with > 64KB RAM have to use memory banking and these are not standardised in any way. The eZ80 is a modern Z80 with an optional extended addressing mode that allows for 24-bit addresses. Where implementation concerns differ for the two, this document will provide commentary on the different approaches expected.

This document is speculative and doesn't represent working code / design.

## Assembly:

_Pling!_ source code is represented as a list of _Values_.  
Values are _Pling!_'s variant data type.

At the syntax level (regardless of implementation),  
these are the Value Types provided by _Pling!_:

- A function call `echo` / lambda `:` ... `;`
- A number, `0`, `$00`, `%00000000`
- A string `"` ... `"`
- An expression `(` ... `)`
- A list `[` ... `]`
- A struct `{` ... `}` (TODO)

_Pling!_ source code is designed to be assembled into a compact, binary form with a single-pass, forward-only assembler without look-ahead.

It should be possible to assemble a file by reading one byte at a time from disk and without reading the entire file into RAM.

Like _Forth_, every token is separated by whitespace.  
Any non-whitespace character is a valid character in a token.

    : each word is a token 1 2 3 4 ;

There are two exceptions to this made in the name of programmer comfort and the fact that we are assembling code to be interpreted later rather than interpreting as we parse (i.e. _Forth_): Comments and Strings

* **Comments:**

  Comments begin with a hash mark `#` and a space. The space is required after the hash mark so long as the end of the line doesn't immediately follow. Once the comment marker occurs, the rest of the line can be read in and skipped

* **Strings:**

  Strings in _Pling!_ look like strings in any other language rather than _Forth_'s oddly disconnected strings (` " Space after opening speech mark!"`), a concession to fit its simple design.

  When a token begins with a speech-mark, keep reading bytes until a closing speech-mark. The whole string is taken as one token

  > TODO: escape codes, cannot yet include speech marks in strings.

Therefore the parser must skip leading whitespace until it comes upon a character and handle the special cases: comments, numbers and strings, before resorting to a standard token.

This EBNF grammar presents the parser's view of the incoming bytes, but doesn't enforce program structure, for example pairing `:` with `;`, that happens during assembling, although parsing and assembling may be happening at the same time depending on implementation.

```ebnf
eol         = [ "\r" ] , "\n" ;
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
   no way to embed a speech mark in a string a.t.m. *)
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

_Pling!_'s solution to this is an intermediate representation consisting of a linked-list of Value types on a simple heap (i.e. no allocator).

A heap is a "pile" of data much like a stack where data is added to the top (or end, if we consider it horizontal) and only the top-most data can be removed.

               top of heap ->|
    ----+------+------+------+
    ... | data | data | data |
    ----+------+------+------+

A heap is useful because it has no "gaps" (unused space) but there are severe restrictions -- only the top-most item can be expanded or contracted, and data can only be added or removed in-order. You cannot place two items on the heap and then remove the older (underneath) item first; all data is bound by scope.

## The Tokeniser

As a token is read in, it is written to the top of the heap as a string.  
A 1-byte padding is included at the beginning for later use.

    ----+-------------------------+
    ... | reserved ¦ token-string |
    ----+-------------------------+

The first character of the token is then looked at to determine the token-type.

### Numbers

If the token is a number type, marked by a `$`, `%` or numerical digit then it is converted from a string into a number literal and the token string on the heap is overwritten with a 1 byte type field and then the number literal in however many bytes are required as given by the type:

    ----+-------------------------+
    ... | reserved ¦ token-string |
    ----+-------------------------+
        |<------ discarded ------ ^
        v
    ----+-------------------+
    ... | num-type ¦ number |
    ----+-------------------+

The datum of the Value has been captured but it is not the Value itself that can be executed. We now add a Value structure to the heap.

        |<---   datum   --->|<---          value struct          --->|
    ----+-------------------+----------------------------------------+
    ... | num-type ¦ number | type ¦ data-ptr ¦ next-ptr ¦ row ¦ col |
    ----+-------------------+-----------+----------------------------+
        ^                               |
        '-------------------------------'

The Value structure includes a 1-byte type that indicates that this Value is a number. The data-pointer contains the address in the heap of the Value's data. The next-pointer will point to the next Value in the current list (when reached), and the row and column fields contain the line-number and column of text in the source file where the original Value occurs (for printing of error messages).

### Strings

As a string is read in it is appended to the end of the heap like so; again with the 1-byte reserved at the head. The opening speech-mark is included as the first character of every token is always included, however the final speech mark is excluded.

    ----+----------------------------------------------------------+
    ... | reserved ¦ " ¦ H ¦ e ¦ l ¦ l ¦ o ¦   ¦ w ¦ o ¦ r ¦ l ¦ d |
    ----+----------------------------------------------------------+

Strings can be much, much longer than other tokens, so once the entire string has been read in, the first *two* bytes of the string are replaced with the string-length. Note how this overwrites the opening speech-mark.

    ----+-----------------------------------------------------------+
    ... | string-length ¦ H ¦ e ¦ l ¦ l ¦ o ¦   ¦ w ¦ o ¦ r ¦ l ¦ d |
    ----+-----------------------------------------------------------+

Now that the string has been captured on the heap, the Value structure is appended.

        |<---  string  --->|<---          value struct          --->|
    ----+------------------+----------------------------------------+
    ... | str-len ¦ string | type ¦ data-ptr ¦ next-ptr ¦ row ¦ col |
    ----+------------------+------------+---------------------------+
        ^                               |
        '-------------------------------'

### Lambdas

Since the lambda is a list within a list, a Value-structure is placed on the heap that points to the top of the heap where the sub-list will be assembled.

        |<---          value struct          --->|
    ----+----------------------------------------+
    ... | type ¦ data-ptr ¦ next-ptr ¦ row ¦ col |
    ----+------------+---------------------------+
                     |                           ^
                     '---------------------------'

The location [in the heap] of the parent list is remembered for later and the sub-list is assembled, Value by Value, as any other. When that list terminates, the location of the parent list is recalled and the next-pointer is updated to point to the top of the heap where the parent list may continue.

                                .-----------------------------------.
                                |                                   v
    ----+-----------------------+----------------+------------------+
    ... | type ¦ data-ptr ¦ next-ptr ¦ row ¦ col | ... sub-list ... |
    ----+------------+---------------------------+------------------+
                     |                           ^
                     '---------------------------'

It is the chaining of the data and next fields that allows lists to be built out of order and for lists-within-lists of any length and any depth of nesting, memory permitting, to be handled.

### Function Calls

A function call is simply a link to another list (Lambda) that has already been defined previously.

                    ----+----------------------------------------+----
                    ... | type ¦ data-ptr ¦ next-ptr ¦ row ¦ col | ...
                    ----+------------+----------+----------------+----
                                     |          |                ^
        .----------------------------'          '----------------'
        v
    ----+----------------------------------------+----
    ... | type ¦ data-ptr ¦ next-ptr ¦ row ¦ col | ...
    ----+-----------------------+----------------+----
                                |                ^
                                '----------------'

The language grammar is designed to not require forward-references, that is, calling a function before it's been defined. You must define a function before it can be called. This avoids having to do a second pass on the code to fix up forward-references and to minimise the amount of meta-data that needs to be held during assembly.

