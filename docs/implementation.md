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

_Pling!_ source code is designed to be assembled into a compact, binary form with a single-pass[^1], forward-only assembler without look-ahead[^2].

[^1]: There will be a need to "fix up" forward-references after the first pass, but the language is designed so that these can be logged during the first-pass and patched immediately without having to walk the entire binary form which is often considered a second pass.

[^2]: Infix operators may look like they require look-ahead but, due to the closing-parenthesis, can be read blind. Either an operator is found or the end of an expression which ends expression parsing. This is why the parentheses are required.

It should be possible to assemble a file by reading one byte at a time from disk and without reading the entire file into RAM.

Like _Forth_, every token is separated by whitespace.  
Any non-whitespace character is a valid character in a token.

    : each word is a token 1 2 3 4 ;

There are two exceptions to this made in the name of programmer comfort and the fact that we are assembling code to be interpreted later rather than interpreting as we parse (i.e. _Forth_): Comments and Strings

* **Comments:**

  Comments begin with a hash mark `#` and a space. The space is required after the hash mark so long as the end of the line doesn't immediately follow. Once the comment marker occurs, the rest of the line can be read in and skipped. This is the only instance where the end of a line matters

* **Strings:**

  Strings in _Pling!_ look like strings in any other language rather than _Forth_'s oddly disconnected strings (` " Space after opening speech mark!"`), a concession to fit its simple design.

  When a token begins with a speech-mark, keep reading bytes until a closing speech-mark. The whole string is taken as one token

  > TODO: escape codes, cannot yet include speech marks in strings.

Therefore the parser must skip leading whitespace until it comes upon a character and handle the special cases: comments, numbers and strings, before resorting to a standard token.

This EBNF grammar presents the parser's view of the incoming bytes, but doesn't enforce program structure, for example pairing `:` with `;`, that happens during assembling; although parsing and assembling may be happening at the same time depending on implementation.

```ebnf
eol               = [ "\r" ] , "\n" ;
spaces            = "\s" + ;                  (* space + tab, no eol      *)
whitespace        = ( spaces | eol ) + ;      (* spaces and newlines      *)
letter            = "\S" ;                    (* non-whitespace character *)

(* only comments distinguish end-of-line so Pling! source code
   is simply a stream of tokens and whitespace *)
source            = { [ whitespace ]          (* leading whitespace       *)
                    , { token , whitespace }  (* separated by whitespace  *)
                    , [ comment ]             (* optional comment         *)
                    } ;

(* comments begin with # and run to the end of the line *)
comment           = "#" , spaces , { ? not-eol ? } , eol
                  | "#" , eol ;

(* tokens are made from a group of any non-whitespace characters
   or the special case handling of numbers & strings *)
token             = ( number | string | letter + ) ;

(* TODO: we won't include floats initially *)
number            = integer | hexadecimal | binary ;
integer           = first-digit , { digits } ;
hexadecimal       = "$" , hexit + ;
binary            = "%" , bit + ;

first-digit       = "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" ;
digits            = "0" | first-digit ;
hexit             = digits | "a" | "b" | "c" | "d" | "e" | "f"
                           | "A" | "B" | "C" | "D" | "E" | "F" ;
bit               = "0" | "1" ;

(* TODO: strings should support escape codes,
   no way to embed a speech mark in a string a.t.m. *)
string            = '"' , { ? any-character ? } , '"' ;
```

As each token is ingested from the source file, it is categorised according to its type and assembled into the binary representation.

Assembled code is simply a list of Values. For the implementation a Value is stored as a 1 byte type and a 2 byte datum. During execution, the interpreter checks the type and handles the datum accordingly.

      type   datum        type   datum
    +------+------------+------+------------+--- - - -
    | byte | word       | byte | word       |
    +------+------------+------+------------+--- - - -

The Value data-types are:

- **Function:**  
  A function call. The datum is the address of the function's lambda (i.e. another list of value-instructions).

- **Native Call:**  
  A function call to native Z80 code. The datum is the address of the Z80 assembly routine.

- **Small Constant:**  
  A constant that can fit within 2 bytes.
  The datum is the value.
  
  This will probably be unsigned-integer only, but a separate type could exist for signed integers

- **An Integer:**  
  The datum is a pointer to the value in memory.

  > TODO: Should signed and unsigned be different types, should _Pling!_ care?

- **A Float:**  
  The datum is a pointer to the value in memory.

  For an 8-bit system, it makes sense to separate integers and floats as the routines they use will be fundamentally different and float support might not be available. An x86-64 implementation could use a shared "number" type and do everything as 64-bit floats

- **A String:**  


- **A List:**  
  The datum is a pointer to the List's contents, another list.

- **End:**  
  The end of a list, either a function or a list of values. For functions, this means returning from the call.

> TODO: Struct

As we assemble one list, we will often need to start another list and then return to where we were. Consider an `if` function-call that is followed by a lambda to execute when true; the lambda is not inline as there would have to be a means of skipping over it.

    +----+------+---- - - -
    | if | true |...
    +----+------+---- - - -
            |
            |      +---- - - -
            '----> | ...
                   +---- - - -

Therefore the assembler must be able to manage multiple on-going lists of unknown length.

### Assembler Keywords:

In _Pling!_ every token can be thought of as a function call, however during assembly there are special keywords that only have meaning during assembly and cannot be called at runtime.

* Comments are parsed and discarded without being assembled

* The `fn` keyword defines a function to be assembled.  
  Functions cannot be assembled during program execution

* The lambda definition `:` is a directive to the assembler to create a new list and begin populating it. The lambda ends with `;`

* The opening bracket `(` is a directive to assemble an expression, which uses different assembling rules. The expression ends with `)`

> TODO: `import`, `export`, `include` etc.

