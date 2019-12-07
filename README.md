# Wasmin

A programming language that is a thin layer over pure WebAssembly (WASM).

Because it compiles down to WASM, it can run anywhere: browsers, native WASM runtimes, JVM.

Because the compiler is written in Dart, Wasmin code can be compiled from
 Flutter mobile apps, web apps, native Dart applications.

## Goals of this project

- stay close to WASM for fast compilation and zero runtime dependencies.
- no heap memory management (GC) by using a linear type system.
- mix the functional and concatenative (exposing the WASM stack) programming paradigms.
- simplest possible syntax that preserves readability.

## This is work in progress

Checklist:

- [x] primitive values.
- [x] parenthesis-grouped expressions.
- [x] ungrouped expressions.
- [x] let assignments.
- [x] math operators.
- [x] function calls.
- [ ] function declarations.
- [ ] single-line comments.
- [ ] multi-line comments.
- [ ] import external functions.
- [ ] export symbols.
- [ ] module declarations.
- [ ] global constants.
- [ ] if/else blocks.
- [ ] loops.
- [ ] stack operator `>`.
- [ ] string values.
- [ ] function pointers.
- [ ] arrays.
- [ ] records.
- [ ] mutability (single-owner only).

## The language

Wasmin is designed to be very simple, built from just a few very generic syntactic forms,
and fast to parse and compile, just like WASM itself, on which it is based! It should run as fast
as hand-written WASM programs on any platform supported by WASM.

It is able to leverage almost everything available in WASM, except unbounded mutability, because that
makes programs too difficult to reason about (but is necessary in a low-level virtual machine).

Wasmin is statically typed, non-garbage-collected
(but requires no memory management thanks to [linear types](http://home.pipeline.com/~hbaker1/ForthStack.html),
which do not generate garbage) and supports the procedural, functional and concatenative programming paradigms.

### Basics

The basic constructs of a Wasmin program are **expressions**.

Expressions are simply arrangements of constants and identifiers which evaluate to a value.

These are all expressions:

- `0` (the constant `0`, of type `i64`, or 64-bit integer).
- `(0)` (same as previous).
- `10i32` (the constant `10`, of type `i32`).
- `()` (the empty expression, of type `empty`).
- `add 1 2` (calls function<sup><a href="#footnote-1">[1]</a></sup> `add` with arguments `1` and `2`).
- `(let n = 1; add n 3)` (one expression grouping two others<sup><a href="#footnote-2">[2]</a></sup> - evaluates to the result of the last one).
- `((let n = 1) (add n 3))` (same as previous).
- `1 > 2 > add` (same as `add 1 2`, using concatenative style).

Because Wasmin gives special meaning to only a few special symbols, identifiers can use almost any symbol,
except control characters and the following special symbols:

- ` `, `\n`, `\r`, `\t` (whitespace symbols).
- `=` (assignment operator).
- `>` (stack operator).
- `(`, `)`, `;` (expression delimiters).
- `{`, `}` (record delimiters).
- `[`, `]` (array delimiters).

Examples of valid identifiers:

- `add`.
- `a1`.
- `number?`.
- `add-one-and-two`.
- `one+two`.
- `hej_då`.
- `こんにちは`.

Invalid identifiers:

- `1a` (cannot start with number<sup><a href="#footnote-3">[3]</a></sup>).
- `foo=bar` (`=` is the assignment operator, which can only appear in a `let` expression).
- `big>small` (`>` is the stack operator, so this is valid, but is an expression, not an identifier).
- `let`, `fun`, `mut` (these are the only keywords in Wasmin).

<small id="footnote-1">[1] expressions with more than one entry are evaluated as functions, with the first entry being the name of the function, and the rest as its arguments.</small>
<small id="footnote-2">[2] two consecutive expressions can appear anywhere, and are separated from one another with either a `;` between them, or by delimiting them with parenthesis, as in Lisp.</small>
<small id="footnote-3">[3] any word starting with a number is interpreted as a number constant.</small>

### Let expressions

In order to bind the value of an expression to an identifier, a `let` expression can be used.

Let expressions always evaluate to `()` and have the form:

```
let <identifier> = <expression>
```

For example:

```rust
let constant-ten = 10;

let five = add 2 3;

let ten = (mul 2 (add 2 3))

let multiline-ten = (
    let one = 1;
    let two = 2;
    let three = 3;
    mul two (add two three)
)
```

Optionally, the type of an identifier can be declared before it's assigned:

```rust
ten i32;
let ten = 10i32;
```

This is mostly useful when exporting an identifier, as we'll see later.

### Mut expressions

Mut expressions are almost exactly like `let` expressions, but allow the declared variable
to be both re-assigned and mutated (in the case of arrays and record types, as we'll see later).

The special `set` function is used to mutate values.

For example:

```rust
mut counter = 0;

// increment the counter
set counter (add counter 1);
```

Unlike `let`, `mut` can only be used to declare local variables, i.e. global variables are immutable. 

### Functions

Wasmin functions are similar to `let` expressions, with the following differences:
 
- functions are evaluated every time they are used, or called.
- they can take any number of arguments (0 to many, limited only by WASM itself).
- they return the value of the expression assigned to them.
- it is mandatory to declare their type.

Functions have the form:

```
<identifier> [<arg-types>] <return-type>
fun <identifier> <args> = <expression>
```

For example:

```rust
square [f64] f64
fun square n = mul n n;

// Lisp/functional style
pythagoras [f64 f64] f64;
fun pythagoras a b = (sqrt (add (square a) (square b)))

// using a more C-like syntax
pythagoras2 [f64 f64] f64;
fun pythagoras2 a b = (
    let sa = square a;
    let sb = square b;
    sqrt (add sa sb)
)

// using the concatenative style
pythagoras3 [f64 f64] f64;
fun pythagoras3 a b = square a > square b > add > sqrt;
```

> Notice that function's type signatures are separated from a function's implementation, and
> must be declared before they are used or implemented.

### Generic functions

A function's types can be generic, which means that the types it accepts and returns depend on
the arguments it was called with.

Generic functions have the form:

```
<identifier> [<arg-types>] <return-type> [, <T> = <type1> [ | <type2> ...], ...];
fun <identifier> <args> = <expression>
```

Most built-in functions are like that! For example, `add` can take any any numeric type, and will return
a value of the same type.

Its type declaration would look like this in Wasmin:

```rust
add [T T] T, T = i32 | i64 | f32 | f64;
```

> Single, capital letters are used to indicate a generic type.

If more than one type is generic, the type parameters need to have different names:

```rust
some-fun [I F] I, I = i32 | i64, F = f32 | f64;
```

The above should be read as _some-fun takes two arguments of type I and F respectively, where I is either i32 or i64,
and F is either f32 or f64_.

As we'll see in the arrays section, some operations do not even need to limit the types they can
work with, in which case it is not necessary to provide the types a function can accept.

For now, this is a silly example demonstrating a function which can accept any type (leveraging
the built-in `typeof`, which returns the name of the type of its argument):

```rust
to-string [T] string;
to-string value = typeof value;
```

A generic function can only pass its arguments to other generic functions with the same, or lower, bounds.

```rust
add-twice [T T] T, T = i32 | i64 | f32 | f64;
add-twice a b = add a b > add a b > add;
```

If that's not possible, different implementations can be provided for each type, without generics being used:

```rust
do-something [i32] i32;
fun do-something n = ...;

do-something [i64] i64;
fun do-something n = ...;

do-something [f32] f32;
fun do-something n = ...;
```

> TODO introduce pattern matching, or simple type checks, to allow branching depending on type?

### Stack operator

WASM is a stack-based virtual machine, which means that it uses a stack data structure to keep
track of values that are not necessarily assigned to local or global variables.

Wasmin exposes the stack to the programmer in a limited form to make it possible to write very
concise expressions in the [concatenative programming](https://en.wikipedia.org/wiki/Concatenative_programming_language)
style.

In a high level overview, the stack operator, `>`, uses the result of the previous expression(s) as the
first argument(s) of the next (if it takes any, otherwise the result is simply passed along):

```rust
let y = mul 2 3 > add 1;
```

In the above example, `mul 2 3` returns `6`, which is then passed to `add 1` via the stack,
resulting in the function invocation `add 6 1`, so `7` is assigned to `y`.

To understand how this works on a lower level, let's recall the `pythagoras3` function, which
used the stack operator when talking about functions:

```rust
fun pythagoras3 a b = square a > square b > add > sqrt;
```

If we let a be `2.0`, b be `3.0`, the stack operations would look like this:

```rust
2.0 > square > 3.0 > square > add > sqrt;
```

> Notice that `square 2` and `2 > square` are exactly equivalent, and the latter is actually closer
> to the WASM code generated by the Wasmin compiler.

Which gets translated into very efficient WASM as:

```wat
f64.const 2
call $square
f64.const 3
call $square
f64.add
f64.sqrt
```

The stack for the above example changes as follows for each operation:

```
f64.const 2 > call $square > f64.const 3 > call $square >  f64.add  > f64.sqrt

                              +-------+      +-------+   
                              |   3   |      |   9   |   
                              +-------+      +-------+
 +-------+      +-------+     +-------+      +-------+    +-------+   +-------+
 |   2   |  >   |   4   |  >  |   4   |  >   |   4   |  > |   16  | > |   4   |
 +-------+      +-------+     +-------+      +-------+    +-------+   +-------+
```

Notice how function invocations in WASM take their arguments from the stack, and put their results onto the stack.

So, when you write `2 > square` in Wasmin, WASM pushes `2` onto the stack, then calls `square`,
which pops the `2` from the stack, calculates its square, then puts the result back onto
the stack, which now has a `4` on it.

Functions taking 2 arguments pop 2 values from the stack, then optionally push the result back
onto the stack, as `add` does.

Unlike most stack-based programming languages, Wasmin and WASM type-check all operations at compile time,
so a function cannot be called unless the values on the top of the stack match its argument types, and it must leave
values with the expected types on top of the stack when it returns.

### Imports and Exports

Variables and functions may be exported by adding the `export` keyword before their type declarations:

```rust
// export the main function, which does not take any arguments
// and returns an i64
export main [] i64;

// export the variable `ten` of type `i64`
export ten i64;
let ten = 10;

fun main = add ten 20;
```

Definitions can be imported from other modules (or the host environment).

The function or variable's type must be declared as usual, but instead of providing an implementation
for them, an `import` statement can be used instead.

```rust
log [string] empty;
import log from "console";

// use log
main [] empty;
fun main = log "hello world";
```

### Built-in functions

Built-in WASM functions do not need to be declared or imported.

Most mathematical operators are simple functions in Wasmin, as in WASM:

* `mul` multiplies two numbers.
* `add` adds two numbers.
* `div_s` and `div_u` divide two signed or unsigned numbers, respectively.
* `and`, `or`, `xor` etc. perform logical operations.
* `sqrt` takes the square root of a floating-point number.

See the [WASM specification](https://webassembly.github.io/spec/core/bikeshed/index.html) for all available operators.

### Type system

Wasmin uses all the basic types provided by WASM:

* `i32` - 32-bit integers.
* `i64` - 64-bit integers.
* `f32` - 32-bit floating-point.
* `f64` - 64-bit floating-point.

Whole numbers are `i64` by default, and fractional numbers are `f64` by default.

To make a number use the 32-bit types, you need to append the appropriate type name to the
number:

```rust
let an-i32-int = 100i32;
let a-f32-float = 0.314f32;
```

Besides the numeric types provided by WASM, Wasmin also has the following types:
 
* `string` (for text).
* record types.
* arrays.

> custom types memory layouts are not defined yet, but should follow the WASI standard as closely as possible.

These are linear types, which means that instances of these types can only be _used up_ once.

For this reason, operations that should not _consume_ the variable should operate on a copy of the original value,
which can be obtained easily with the `copy` function (which is special in that it's the only function that can use
a non-primitive value without consuming it).

This will be explained for each type individually.

### Strings

Strings can be declared as in most other languages:

```rust
let my-string = "hello world";
```

Wasmin source code is encoded as UTF-8, and Wasmin Strings are stored in memory exactly as the bytes
encoded in the String source (prefixed with some header information which is not defined yet).

As Strings are not a core WASM type, no functions that work on Strings are defined yet.

> Wasmin should create a module exposing common string manipulating functions in the future.

Supposing there is a function `toUpper [string] string`, we could use that as follows:

```rust
let str = "hello world";
let upper = toUpper str;

// notice that `str` cannot be used here anymore!
```

If the original string is still required, pass a copy of it to the function to avoid destroying the original one:

```rust
let str = "hello world";
let upper = toUpper (copy str);

// `str` can still be used here!
```

### Record types 

Records can be defined similarly to functions and variables, but instead of taking an expression
as the body, they take a record definition, which has the following form:

```
{ [<field_name> <field_type>,]... }
```

For example:

```rust
let Person = {name string, age i32}
```

An instance of a record can be created as follows:

```rust
joe Person;
let joe = {name "Joe", age 35i32};
```

Record fields can be read by using the special `get` function:

```rust
joe Person;
let joe = {name "Joe", age 35i32};
let joesAge = get joe age;
```

If a record is declared as mutable, its fields can be modified with the `set` operation:

```rust
joe Person;
mut joe = {name "Joe", age 35i32};

set joe name "Johan";

set joe age (get joe age > add 1);
```

> The `set` and `get` functions do not consume their first argument! See the `get and set functions` Section
> for more details.

### Arrays

Arrays are fixed-length sequences of instances of a certain type.

Arrays have the forms:

```
[ <item> ... ]
```

Array types are declared as follows:

```
array <type> [<size>]
```

If the size is omitted, it means the array can be of any size
(but if it is initialized with a literal, its size will be that of the literal value).

For example:

```rust
// no type declaration required for literal arrays
let i64-array = [1 2 3];

// create an array of size 100, initializing items with their zeroth values
large-array array i32 100;
let large-array = [];
```

To be able to mutate an array with the `set` function, it must be declared as mutable:

```rust
large-array array i32 100;
mut large-array = [];

set large-array 0 1i32;
set large-array 1 2i32;

// large-array now looks like [1 2 0 0 ... ]
```

To read elements from an array, use the special `get` function:

```rust
let i64-array = [1 2 3];
let first = get i64-array 0;
let last = size i64-array > sub 1 > get i64-array;
```

Trying to read an element outside the bounds of the array is not an error, but simply results
in the zeroth-value for the array's type being returned:

```rust
let my-array = [1];

// element is assigned 0i64 as that's the zero-value for this array's type
let element = get my-array 22;
```

To avoid this situation, use `get-or-default`:

```rust
let my-array = [1];

// element is assigned the default value, 1
let element = get-or-default my-array 22 1;
```

### Conditional execution

In Wasmin, `if` is an expression of the form:

```
if <condition> <then-expression> <else-expression>;
```

This allows expressions to be evaluated only if some condition holds.

Examples:

```rust
let cond = 1;

// if cond is non-zero, y is assigned "true", otherwise, "false".
let y = if cond "true" else "false";
```

### Loops

Loops have the following form:

```
loop-if <condition> <expression>
```

The `expression` will be repeatedly evaluated until either:

* `condition` no longer holds, OR
* `break` is called from within the `expression`.

Example:

```rust
// implementing the traditional `map` function in Wasmin
// with the `loop-if` construct
map [[T] V array T] array V;
fun map function list = (
    mut index = 0;
    result array V (list > size);
    mut result = [];
    loop-if (list > size > lt index) (
        let item = get list index;
        set result index (function item)
        set index (add index 1)
    )
    result
)
```

### get, set, size and remove functions

We already saw how to use `get` and `set` to read and write fields in records and items in arrays, and `size` to
inspect the length of an array.

To recap:

```rust
let my-array = [1 2 3];
let first = get my-array 0;

let size-of-array = size my-array;

let Rec = {name string};

rec Rec;
mut rec = {name "the record"};

set rec name "another name";
```

Another function we haven't met yet is the `remove` function which:

* for arrays: returns the element at the index provided without making a copy of it, leaving the zeroth-value in its place.
* for records: returns the value of the field with the provided name without making a copy of it, leaving the zeroth-value in its place.

Notice that the `get` function, on the other hand, must return a copy of the element it picks from the array or record 
(unless the type of the value is a primitive) in order to not violate the linearity of the Wasmin type system
(which allows it to avoid memory management). 

Example:

```rust
let Rec = {name string};

rec Rec;
mut rec = {name "the record"};

let current-name = remove rec name;

// `get rec name` would now return the empty String!
```

Notice that these _special functions_ never consume their first argument (i.e. the receiver of the call), so that the
array or record can always be used after they are called.

### Memory Management

Finally, we can discuss one of the most innovative aspects of Wasmin in more detail: its memory management, or lack thereof.

As mentioned before, Wasmin does not have a garbage-collector, and it does not require the programmer
to manage memory in any way.

You may be asking yourself: how does it do that?

Simple: Wasmin use a [linear type](https://wiki.c2.com/?LinearTypes) system for everything except WASM primitives (number types).

Another small restriction is that no global state may be mutable, which is why only `let` can declare globals, but
not `mut`.

The fact that a linear type system is used, which means that there must only be a single reference to a variable at
any given time, allows Wasmin to know that once a variable goes out of scope locally, it can be immediately
de-allocated, together with everything it itself refers to (as everything else is also subject to this rule).

Wasmin only needs to insert some instructions at compile time to make sure that this happens, without having to
include a runtime to do anything more complicated, like a garbage collector or even a reference-count manager. 

The observation that linear types allow a programming language to completely avoid garbage collection and manual 
memory management is based on a short paper by [Henry G. Baker](http://home.pipeline.com/~hbaker1/ForthStack.html).
