# Pling! #

A nice looking functional, concatenative programming language for minimal systems.  
By Kroc Camen.

## Goals

_Pling!_ is intended for rapid application development on 8-bit modern-retro hardware, such as the [Agon Light], where memory is constrained but CPU speed is adequate (typically 4 ~ 20 MHz).

[Agon Light]: https://www.thebyteattic.com/p/agon.html

The language has been specifically designed to be easy to parse on an 8-bit CPU with <= 64KB RAM:

- Simple left-to-right, context-free parser. No look-ahead!
- Can be parsed as a byte-at-a-time stream without backtracking; the whole source file does not have to be in RAM at once
- Link-time modules provide easy code reuse without building monolithic binaries

The syntax is minimal, but easy to read and understand.

## Comments:

    # a comment begins with a hash mark and a space
    # -- the space is required because the hash mark is a
    # function that reads the rest of the line and discards it

## Constants:

A constant is a function that always returns the same value.

    let true    1
    let false   0

## Variables:

A variable is a function that returns its current value.  
It must be defined ahead of time and must have a default value.

    var is_the_queen_dead false

A variable's value is changed with the `set` function.

    set is_the_queen_dead true

## Numbers:

    let DECIMAL         0
    let HEXADECIMAL     $01
    let BINARY          %00000001
    let FLOAT           1.0

## Arithmetic:

Arithmetic is done purely left-to right, there is no [operator precedence]. The result of an infix calculation (e.g. `4 + 5`) is totalled before proceeding to the next operator (e.g. `* 3`). This behaviour is intentional for simplicity of parsing, particularly by 8-bit CPUs and almost entirely does away with the need to nest parentheses.

[operator precedence]: https://en.wikipedia.org/wiki/Order_of_operations

Since there is no look-ahead, the brackets are required to indicate an expression that must be evaluated to produce the result -- an expression can be thought of a small inline function that produces a value.

    set number ( 4 + 5 * 3 )
    set number ( number + 1 )

An expression is the only place operators may be used.

## Operators:

    let ADD             ( 1 + 1 )
    let SUBTRACT        ( 1 - 1 )
    let MULTIPLY        ( 1 * 1 )
    let DIVIDE          ( 1 / 1 )
    let EXPONENT        ( 2 ^ 1 )
    let MODULO          ( 10 % 2 )
    let LOGICAL_OR      ( 0 or 1 )
    let LOGICAL_AND     ( 1 and 1 )
    let BINARY_OR       ( 0 | 0 )
    let BINARY_AND      ( 0 & 0 )
    let BINARY_XOR      ( 0 ~ 0 )
    let EQUAL           ( 0 = 0 )
    let NOT_EQUAL       ( 0 != 0 )
    let LESS            ( 0 < 0 )
    let GREATER         ( 0 > 0 )
    let LESS_EQUAL      ( 0 <= 0 )
    let GREATER_EQUAL   ( 0 >= 0 )

## Strings:

    let greeting "Hello, World!"

## Functions:

A lambda is a fixed, immutable list of values. A "value" is a number, a string, an expression, a function, other lambdas, and any other types.

Lambdas begin with `:` and end with `;`.

    : cat sit mat … ;

Any functions calls or expressions in the lambda are not evaluated until execution; the expressions are stored in the lambda in a frozen, uncalculated state.

A function is a lambda with a name.  
A function is defined with the `fn` keyword, a name and a lambda of instructions:

    fn three :
        ( 1 + 2 )
    ;

Functions do not define a parameter list up-front, instead they take their parameters from the instruction stream when desired using the `get` function. Therefore a function could read a different number of parameters depending on what's read!

    fn add :
        get first
        get second

        ( first + second )
    ;
    echo add 1 2                # prints "3"

Note how functions return values by evaluation. So long as a value is not being used as a parameter to a function call, it is returned from the function.

Local variables (and constants) can be defined within functions and exist only within the function scope. The `get` function acts the same as `var`, defining the variable, but also retrieving the parameter at the same time.

    fn add :
        get first
        get second
        var third ( first + second )
        
        third
    ;
    echo add 1 2                # prints "3"

## Conditionals:

An `if` block takes any value, including an expression, and a lambda to execute if the value resolves to true.

    fn max :
        get first
        get second
        if ( first > second ) :
            first
            exit                # exits a function early
        ;
        second
    ;

For if-then-else constructs, the function `if-else` takes a value and two lambdas, the first is executed if the value resolves to true and the second is executed otherwise.

    fn max :
        get first
        get second
        if-else ( first > second ) :
            first
        ; :
            second
        ;
    ;

The true & false parameters do not need to be lambdas, they can be function calls or even values to return:

    fn min :
        get first
        get second
        if-else ( first > second ) first second
    ;

> TODO: switch / match

## Loops:

    while ( expression ) :
        ⋮
    ;

    do :
        ⋮
        exit
    ;
    
> TODO: for loops

## Lists:

Lists are dynamically generated and managed lists of values.  
If lambdas are functions as constants then lists are functions as variables.

A list is defined by square brackets, either closed for an empty list, or containing a number of default values.

    var empty_list []
    var three_list [ 1 2 3 ]

Unlike lambdas, expressions and function calls will be evaluated when defining the list. A list can be thought of as a function that allocates memory for a list and then begins populating the list with each value it comes across.

Functions for manipulating lists exist, but these are library functions rather than intrinsic syntax so I won't got into detail here.

    count list                  # return number of values in list
    first list                  # return first value in list
    last list                   # return last value in list
    push list value             # add value to end of list
    pop list                    # remove (+return) last value in list
    prepend list value          # add value to start of list
    insert list index value     # insert value at index
    replace list index value    # replace value at index
    remove list index           # remove value at index
    join list list              # join two lists together as one
    slice list index length     # slice list starting at index

### Indexing:

Accessing an index of a list is done with the `@` operator.

    var numbers [ 1 2 3 ]
    echo ( numbers @ 2 )        # prints "2"

<!--

#### Indexing:

The last value of a list can be returned by the `last` function. The `last` function is equivalent to returning the number of elements and then accessing that index.

    var numbers [ 1 2 3 ]
    echo last numbers                   # prints "3"
    echo ( numbers @ count numbers )    # prints "3"

Likewise `first` returns the value of the first index:

    var numbers [ 1 2 3 ]
    echo first numbers                  # prints "1"
    echo ( numbers @ 1 )                # prints "1"

Therefore we see that lists are 1-based. An index of 0 is considered an error.

The size of a list can be returned by the `count` function.

    var numbers [ 1 2 3 ];
    echo count numbers                  # prints "3"

Note how an expression is not needed because `count` is a function that takes a parameter and not an infix operator.

-->

## The Data Stack:

Up to this point we've been avoiding an important implementation detail that makes _Pling!_ different; it has an implicit data stack.

This means that, as well as parameters, functions can work on data that is pushed to and popped from a data stack. Unlike parameters, this data persists as we move across functions. This allows _Pling!_ to work with both static and dynamic data types.

The data stack is always separate from the function return stack and any other implementation-specific stacks.

Values returned by functions are being pushed on to the data stack, ergo a function can return more than one value:

    fn potatoes :
        1
        2
    ;

When we call a function with a parameter, such as `echo`, what we are really saying is that `echo` will print the result on top of the stack of what the following value / function evaluates to.

    echo sir_lancelots_favourite_colour

## ! + ? + .

_Pling!_ is so named because an exclamation mark (also known as a "bang" or "pling") is a function that pops the top item off the stack instead of pushing something new on. It can be used as a replacement for parameters!

    1                       # push the value "1" on to the data stack
    echo !                  # pop a value off the data stack and print it

Each value on the stack is opaque. It's important to understand that if you push a list on to the data stack, you will pop the entire list, not each item one-by-one:

    [ 1 2 3 ]               # push a list on to the stack
    echo !                  # prints "[ 1 2 3 ]"!

You can temporarily move the data pointer into the list using a `with` block:

    4                       # note how the stack is first-in, last-out
    [ 1 2 3 ]               # this will be on top of the stack
    with ! :
        echo !              # prints "1"
        echo !              # prints "2"
    ;
    echo !                  # prints "4"

You can also take a list and iterate over it. The `each` function takes a list as a parameter (or, with `!`, the stack) and calls a function / lambda for each value in the list, automatically pointing the data parameter at the popped value.

    [ 1 2 3 ]
    each ! : echo ! ;           # prints "1", "2", "3"

If a list is nested however, we don't automatically get recursion:

    [ 1 2 [ 3 4 ]]
    each ! : echo ! ;           # prints "1", "2", "[ 3 4 ]"

The `map` function calls a function for each value in a list and will handle the recursion for us. Note how we can also do away with the lambda since the `map` function takes a function name as a 2nd parameter.

    [ 1 2 [ 3 4 ]]
    map ! echo                  # prints "1", "2", "3", "4"

The `?` function 'peeks' the stack value, but does not pop it. You can use this when you want to get the value atop the stack, but don't want to remove it.

    [ 1 2 3 4 ]
    map ? echo                  # prints "1", "2", "3", "4"
    echo count ?                # prints 4

The `.` function throws away (or "drops") the value atop the stack.  
Use this when you need to level the stack for parameters you don't use.

    1 2 3 4                     # 4 items on stack, not a list
    . . .                       # drop three items
    echo !                      # prints "1"

## Data Types:

In Forth it's easy to make mistakes where you put one value on the stack but you accidentally read it back and treat it as something it's not. Forth's lack of a type system exposes its unforgiving nature for beginners, or just feeling your way through a problem. Most modern Forth-like languages therefore include a type system.

Everything in _Pling!_ is a _list_ of _values_.

_Values_ can be of any type:

* A _number_
* A _string_
* An _expression_, a kind of _list_ specific to operators
* A _lambda_ -- a statically assembled list
* A list -- a dynamically allocated list
* A _function_ name
* A _structure_

We've covered all but the last type in some way or another thus far.

A data type can be thought of as a class in other programming languages. Each data type has to have methods for printing and for pushing and popping from the stack.

In _Pling!_, data types are the lowest-level primitives that are typically implemented in machine code. How the data is stored and retrieved is highly machine-specific, however _Pling!_ programs don't ever deal with the implementation details directly.

The type of a value is bound to it. If you push a number to the data-stack you can not read it back as a function name. Whatever is pushed will always pop as the same type as it was before.

## Structures:

(in progress...)

## Keywords ##

_Pling!_ reserves these symbol names for built-in keywords, functions, operators and type-sigils:

    fn      let     var     set     get     true    false
    :       ;       (       )       [       ]       #
    +       -       *       /       ^       %       or
    and     |       &       ~       =       !=      >
    <       >=      <=      @       !       ?       .

    "..."   $...    %...


<!--

#### Appending + Prepending:

Lists can be extended by adding or prepending values to the ends.

    var numbers [ 1 2 3 ]
    append numbers 4
    prepend numbers 0
    # prints "[ 0 1 2 3 4 ]"
    echo numbers

#### Inserting + Replacing + Removing:

Values can be inserted into lists in arbitrary places. The `insert` function takes a list, a value and an index to insert the value into, replacing that index and shifting all other values along.

    var numbers [ 1 2 4 ]
    insert numbers 3 4                  # TODO: returns?
    echo ( numbers @ 3 )                # prints "3"

Replacing an existing value can be done with `replace` which takes an index and a new value. The old value is returned before it is replaced in the list.

    var numbers [ 1 4 3 ]
    echo replace numbers 2 2            # prints "4"
    echo ( numbers @ 2 )                # prints "2"

A value can be deleted from a list with the `remove` function which takes a list and an index. Note that the value removed is returned before deletion from the list.

    var numbers [ 1 2 2 3 4 ]
    echo remove numbers 3               # prints "2"
    echo ( numbers @ 3 )                # prints "3"

#### Slicing:

    var numbers [ 1 2 3 4 ]
    echo slice numbers 2 2              # prints "[ 2 3 ]"

### Cursoring:

A cursor is a pointer into a list (or lambda!). One is used in the instruction stream for the current instruction executing and each function call has a cursor to the call site for getting parameters.

Lists can also have cursors, although because they are dynamic, you can have multiple cursors pointing into the same list.

The `index` function returns a cursor into the given list, with the given initial index-position. Outputting the cursor returns the current index.

    var numbers [ 1 2 3 4 ]
    var cursor index numbers 1
    echo cursor                         # prints "1"

A cursor is intrinsically bound to its list. `current` returns the value in the list the cursor is currently pointing to.

    var numbers [ 1 2 3 4 ]
    var cursor index numbers 3
    echo current cursor                 # prints "3"

Moving the cursor can be done by changing its value, or using `next` and `prev` functions to move one at a time.

    var numbers [ 1 2 3 4 ]
    var cursor index numbers 1
    next cursor
    echo current cursor                 # prints "2"
    set cursor 4
    prev cursor
    echo current cursor                 # prints "3"

A cursor can be rewound by either setting its value to 1, or by using `begin`. Likewise it can be wound to the end by using `end`.

    var numbers [ 1 2 3 4 ]
    var cursor index numbers 4
    echo ( numbers @ cursor )           # prints "4"
    begin cursor
    echo ( numbers @ cursor )           # prints "1"
    end cursor
    echo ( numbers @ cursor )           # prints "4"

-->