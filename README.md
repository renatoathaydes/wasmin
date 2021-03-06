# Wasmin

A functional, concatenative, statically typed programming language that builds on the primitives provided by
[WebAssembly (WASM)](https://developer.mozilla.org/en-US/docs/WebAssembly).

Because it compiles down to WASM, it can run anywhere at near-native speeds:

- nearly [all browsers](https://developer.mozilla.org/en-US/docs/WebAssembly#Browser_compatibility).
- native WASM runtimes ([Wasmtime](https://wasmtime.dev/), [Wasmer](https://wasmer.io/)).
- JVM ([GraalWasm](https://medium.com/graalvm/announcing-graalwasm-a-webassembly-engine-in-graalvm-25cd0400a7f2)).

Because the compiler is written in Dart, Wasmin code can be compiled from:

- Dart applications.
- Web applications (by compiling Dart to JS).
- Flutter apps (iOS, Android).
- Any native application (by calling the native Wasmin compiler).

## Wasmin Goals

- stay close to WASM for fast compilation and zero runtime dependencies.
- no heap memory management (GC) by using a linear type system.
- mix the functional and concatenative (exposing the WASM stack) programming paradigms.
- simplest possible syntax that preserves readability.

## This is work in progress

Feature Checklist:

- [x] primitive values.
- [x] parenthesis-grouped expressions.
- [x] ungrouped expressions.
- [x] multi-expressions.
- [x] type declarations.
- [ ] generic type declarations.
- [x] let assignments.
- [x] mut assignments.
- [x] math operators.
- [x] function calls.
- [x] function implementations.
- [ ] generic functions.
- [x] single-line comments.
- [ ] multi-line comments.
- [x] global constants.
- [ ] import from other Wasmin files.
- [ ] import external functions.
- [x] export functions and constants.
- [x] if/else blocks.
- [x] loops.
- [ ] stack operator `>`.
- [ ] string values.
- [ ] function pointers.
- [ ] arrays.
- [ ] records.
- [ ] generic records.
- [ ] special functions (`get`, `set`, `remove`, `size`, `copy`).
- [ ] `typeof` special function.

Not yet designed features (may never be added):

- pattern matching.
- type checks.
- threads.
- [SIMD](https://medium.com/wasmer/webassembly-and-simd-13badb9bf1a8).
- [WASI interface types](https://hacks.mozilla.org/2019/08/webassembly-interface-types/).
- embed WAT code inside Wasmin.

## The language

Wasmin is designed to be simple, built from very few generic syntactic forms,
and therefore fast to parse and compile, like WASM itself!

It attempts to minimize punctuation to be as syntactically light as possible without losing readability.

Because it only contains primitives that can be mapped easily to WASM, it should run as fast 
as hand-written WASM programs on any platform.

Wasmin is statically typed, non-garbage-collected
(but requires no memory management thanks to [linear types](http://home.pipeline.com/~hbaker1/ForthStack.html),
which do not generate garbage) and supports the procedural, functional and concatenative programming paradigms.

### Basics

The basic constructs of a Wasmin program are **expressions**.

Expressions are simply arrangements of symbols, constants and other expressions which evaluate to a value or perform some
side-effect.

An expression may consist of several sub-expressions that are evaluated in sequence within a parenthesis-demarked
group. Its value is that of the last sub-expression. To separate each sub-expression, either group each of them within
parenthesis, or add a semi-colon `;` between them.

For example, these are all expressions:

- `0` (the constant `0`, of type `i64`, or 64-bit integer).
- `(0)` (same as previous).
- `add 1 2` (calls function<sup><a href="#footnote-1">[1]</a></sup> `add` with arguments `1` and `2`).
- `(let n = 1; add n 3)` (one expression grouping two others<sup><a href="#footnote-2">[2]</a></sup> - evaluates to the result of the last one).
- `1 > 2 > add` (same as `add 1 2`, using concatenative style).

Because Wasmin gives special meaning to only a few special symbols, identifiers can use almost any symbol,
except control characters and the following special symbols:

- ` `, `\n`, `\r`, `\t` (whitespace symbols).
- `#` (starts a line-comment).
- `,` (used to separate record elements and types in type signatures).
- `=` (assignment operator).
- `>` (stack operator).
- `<` (reserved, but not currently used).
- `:` (starts listing generic type bounds).
- `(`, `)`, `;` (expression and generic types delimiters).
- `{`, `}` (record delimiters).
- `[`, `]` (array delimiters).

> Wasmin source code must always be encoded using UTF-8.

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
- `foo=bar` (`=` is the assignment operator, so this means _assign bar to foo_).
- `big>small` (`>` is the stack operator, so this is valid, but is an expression, not an identifier).
- `let`, `fun`, `mut`, `def`, `import`, `pub`, `if`, `loop` (these are the only keywords in Wasmin).
- `get`, `set`, `remove`, `size`, `copy` (special functions).

#### Footnotes

<div id="footnote-1">
<small>[1] expressions with more than one entry are evaluated as functions, with the first entry being the name of the function, and the rest as its arguments.</small>
</div>
<div id="footnote-2">
<small>[2] two consecutive expressions can appear anywhere, and are separated from one another with either a `;` between them, or by delimiting them with parenthesis, as in Lisp.</small>
</div>
<div id="footnote-3">
<small>[3] any word starting with a number is interpreted as a number constant.</small>
</div>

### Let expressions

In order to bind the value of an expression to an identifier, a `let` expression can be used.

Let expressions always evaluate to `empty`, or `()` (which cannot be assigned or returned) and have the form:

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

Optionally, the type of an identifier can be defined with the `def` keyword before it's assigned:

```rust
def ten i32;
let ten = 10;
```

This is mostly useful when exporting an identifier, as we'll see later.

### Mut expressions

Mut expressions are almost exactly like `let` expressions, but allow the declared variable
to be both re-assigned and mutated (in the case of arrays and record types, as we'll see later).

For example:

```rust
mut counter = 0;

# increment the counter
set counter = counter > add 1;
```

### Functions

Wasmin functions are similar to `let` expressions, with the following differences:
 
- functions are evaluated every time they are called.
- they can take any number of arguments (0 to many, limited only by WASM itself).
- they return the value of the expression assigned to them.
- it is mandatory to declare their type if they take one or more arguments.

Functions have the form:

```
def <identifier> [<arg-types>, ...] <return-type>
fun <identifier> [<arg> ...] = <expression>
```

> Currently, WASM support only one return value, but it will allow multiple returns values in the future.
> Wasmin will allow multiple return values as soon as WASM does.

For example:

```rust
def square [f64] f64;
fun square n = mul n n;

# Lisp/functional style
def pythagoras [f64, f64] f64;
fun pythagoras a b = (sqrt (add (square a) (square b)))

# using a more C-like syntax
def pythagoras2 [f64, f64] f64;
fun pythagoras2 a b = (
    let sa = square a;
    let sb = square b;
    sqrt (add sa sb)
)

# using the concatenative style, which can be the cleanest in certain cases!
def pythagoras3 [f64, f64] f64;
fun pythagoras3 a b = square a > square b > add > sqrt;
```

> Notice that function's type signatures are separated from a function's implementation, and
> must be defined before they are used or implemented.

### Generic functions

A function's types can be generic, which means that the types it accepts and returns depend on
the arguments it was called with.

Generic functions have the form:

```
def <identifier> [<arg-types>, ...] <return-type> [: <T> = <type1> [ | <type2> ...], ...];
fun <identifier> <args ...> = <expression>
```

Most built-in functions are like that! For example, `add` can take any any numeric type, and will return
a value of the same type.

Its type declaration would look like this in Wasmin:

```rust
def add [T, T] T: T = i32 | i64 | f32 | f64;
```

> Single, capital letters are used to indicate a generic type.

If more than one type is generic, the type parameters need to have different names:

```rust
def some-fun [I, F] I: I = i32 | i64, F = f32 | f64;
```

The above should be read as _some-fun takes two arguments of type I and F respectively, and returns a value of type I,
 where I is either i32 or i64, and F is either f32 or f64_.

As we'll see in the arrays section, some operations do not even need to limit the types they can
work with, in which case it is not necessary to provide the types a function can accept.

A generic function can only pass its arguments to other generic functions with the same, or lower, bounds.

```rust
def add-twice [T T] T, T = i32 | i64 | f32 | f64;
fun add-twice a b = add a b > add a b > add;
```

If that's not possible, different implementations can be provided for each type, without generics being used:

```rust
def do-something [i32] i32;
fun do-something n = ...;

def do-something [i64] i64;
fun do-something n = ...;

def do-something [f32] f32;
fun do-something n = ...;
```

### Stack operator

WASM is a stack-based virtual machine, which means that it uses a stack data structure to keep
track of values that are not necessarily assigned to local or global variables.

Wasmin exposes the stack to the programmer in a limited form to make it possible to write very
concise expressions in the [concatenative programming](https://en.wikipedia.org/wiki/Concatenative_programming_language)
style.

As a high level description, we can say that the stack operator, `>`, uses the result of the previous 
expression(s) as the first argument(s) of the next (if it takes any, otherwise the result is simply passed along):

```rust
let y = mul 2 3 > add 1;
```

> The `>` operator can be read as `then`, so the above example could be read as
> _let y be the result of multiplying 2 and 3, then adding 1_.

In this example, `mul 2 3` returns `6`, which is then passed to `add 1` via the stack,
resulting in the function invocation `add 6 1`, so `7` is assigned to `y`.

To understand how this works on a lower level, let's recall the `pythagoras3` function, which
used the stack operator when talking about functions:

```rust
fun pythagoras3 a b = square a > square b > add > sqrt;
```

If we let `a` be `3.0` and `b` be `4.0`, the stack operations would look like this:

```rust
3.0 > square > 4.0 > square > add > sqrt;
```

> Notice that `square 3` and `3 > square` are exactly equivalent, and the latter is actually closer
> to the WASM code generated by the Wasmin compiler.

Which gets translated into very efficient WASM as:

```wat
f32.const 3
call $square
f32.const 4
call $square
f32.add
f32.sqrt
```

The stack for the above example changes as follows for each operation:

```
f32.const 3 > call $square > f32.const 4 > call $square >  f32.add  > f32.sqrt

                              +-------+      +-------+   
                              |   4   |      |   16  |   
                              +-------+      +-------+
 +-------+      +-------+     +-------+      +-------+    +-------+   +-------+
 |   3   |  >   |   9   |  >  |   9   |  >   |   9   |  > |   25  | > |   5   |
 +-------+      +-------+     +-------+      +-------+    +-------+   +-------+
```

Notice how function invocations in WASM take their arguments from the stack, and put their results onto the stack.

So, when you write `3 > square` in Wasmin, WASM pushes `3` onto the stack, then calls `square`,
which pops the `3` from the stack, calculates its square, then puts the result back onto
the stack, which now has a `9` on it.

Functions taking 2 arguments pop 2 values from the stack, then optionally push the result back
onto the stack, as `add` does.

Unlike most stack-based programming languages, Wasmin and WASM type-check all operations at compile time,
so a function cannot be called unless the values on the top of the stack match its argument types, and it must leave
values with the expected types on top of the stack when it returns.

### Imports and Exports

Variables and functions may be exported (i.e. made public) by adding the `pub` keyword before their type declarations:

```rust
# export the main function, which does not take any arguments
# and returns an i64
pub def main [] i64;

# export the variable `ten` of type `i64`
pub def ten i64;
let ten = 10;

# implementations don't need to immediately follow definitions  
fun main = add ten 20;
```

Definitions can be imported from other modules (or the host environment) and from other Wasmin files.

To import something from another Wasmin file, simply refer to the other file with a relative path:

```rust
import "./factorial.wasmin";

# use factorial, which is defined in factorial.wasmin
def main [] i64;
fun main = factorial 10;
```

Using the form `import "./other-file";`, all definitions exported by `other-file` are imported into the current file.
To only import certain definitions, use the form `import "./other-file" show <identifier> ...;"`

For example:

```rust
import "./factorial.wasmin" 
    show factorial other-function;
```

In case a definition is external (i.e. not from another Wasmin file, but from the host environment), 
it is declared with `ext def`:

```rust
ext def log [T];

# use log
fun main = log "hello world";
```

> Notice that a type declaration for a function without arguments is optional,
> as its return type can be inferred by the compiler.

If the host environment or another module does not provide the imported definition, or it has a different type than
the one declared, an error will occur when loading the WASM module.

### Built-in functions

Built-in WASM functions do not need to be declared or imported.

Wasmin supports all [WASM numeric instructions](https://webassembly.github.io/spec/core/syntax/instructions.html)
as simple functions:

* `mul` multiplies two numbers.
* `add` adds two numbers.
* `div` divides two floating-point numbers.
* `div_s` and `div_u` divide two signed or unsigned integers, respectively.
* `and`, `or`, `xor` etc. logical operations on integers.
* `sqrt` takes the square root of a floating-point number.

See the [WASM specification](https://webassembly.github.io/spec/core/syntax/instructions.html) for all available operators.

### Type system

Wasmin uses all the basic types provided by WASM:

* `i32` - 32-bit integers.
* `i64` - 64-bit integers.
* `f32` - 32-bit floating-point.
* `f64` - 64-bit floating-point.

Whole numbers are `i32` by default, and fractional numbers, `f32`, but when literals are used in a position that 
requires a 64-bit number, or the literal is just too big to fit in 32 bits, the 64-bit version will automatically
be used.

Besides the numeric types provided by WASM, Wasmin also has the following types:
 
* `string` (for text).
* record types.
* arrays.

> custom types memory layouts are not defined yet, but should follow the WASI standard as closely as possible.

These are linear types, which means that instances of these types can only be _used up_ once.

For this reason, operations that should not _consume_ the variable should operate on a copy of the original value,
which can be obtained easily with the `copy` function.

This will be explained for each type individually.

### Strings

Strings can be declared as in most other languages:

```rust
let my-string = "hello world";
```

Wasmin source code is encoded as UTF-8, and Wasmin Strings are stored in memory exactly as the bytes
encoded in the String source (prefixed with some type header information).

> TODO How should Wasmin provide string operations to programs without incurring a runtime?

Supposing a module defined a function `toUpper [string] string`, we could use that as follows:

```rust
let str = "hello world";
let upper = str > toUpper;

# notice that `str` cannot be used here anymore!
```

If the original string is still required, pass a copy of it to the function to avoid destroying the original one:

```rust
let str = "hello world";
let upper = copy str > toUpper;

# `str` can still be used here!
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
def joe Person;
let joe = {name "Joe", age 35}
```

Record fields can be read by using the special `get` function:

```rust
def joe Person;
let joe = {name "Joe", age 35};
let joesAge = get joe age;
```

If a record is declared as mutable, its fields can be modified with the `set` function:

```rust
def joe Person;
mut joe = {name "Joe", age 35};

set joe name = "Johan";

set joe age = get joe age > add 1;
```

> Notice that special functions, like `set` and `get`, do not consume their first argument! See the `Special functions` Section
> for more details.

A record may use generic types to let the user decide what type one or more fields should have:

```rust
let Box(T) = {item T};

def int-box Box(i64);
let int-box = Box(item 32);

def string-box Box(string);
let string-box = Box(item "my box");
```

We'll see more details about generic types in the `Type system` Section.

### Arrays

Arrays are generic, fixed-length sequences of instances of a certain type.

Arrays have the forms:

```
[ <item> ... ]
```

Array types are declared as follows:

```
array(<type>)[(<size>)]
```

If the size is omitted, it means the array can be of any size,
but if it is initialized with a literal, its size will be that of the literal value.

For example:

```rust
# no type declaration required for literal arrays
let i64-array = [1 2 3];

# create an array of size 100, initializing items with their zeroth values
def large-array array(i32)(100);
let large-array = [];

# function that requires an array of length 100
def use-array [i64(i32)(100)];
fun use-array a = ...
```

To be able to mutate an array with the `set` function, it must be declared as mutable:

```rust
def large-array array(i32)(100);
mut large-array = [];

set large-array 0 = 1;
set large-array 1 = 2;

# large-array now looks like [1 2 0 0 ... ]
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

# element is assigned 0 as that's the zero-value for this array's type
let element = get my-array 22;
```

To avoid this situation, use `get-or-default`:

```rust
let my-array = [1];

# element is assigned the default value, 1
let element = get-or-default my-array 22 1;
```

### Conditional execution

In Wasmin, `if` is an expression of the form:

```
if <condition> <then-expression> [<else-expression>];
```

This allows expressions to be evaluated only if some condition holds.

Examples:

```rust
let cond = 1;

# if cond is non-zero, y is assigned "true", otherwise, "false".
let y = if cond "true" else "false";
```

If the `else` branch is missing, the `if` expression will always evaluate to `()`, which means its result cannot be
assigned to a variable. This is useful for performing side-effects:

> To stop the Wasmin parser from interpreting the next expression as the `else` block, you can either wrap the whole
> `if` expression into parenthesis, as shown below, or add an extra `;` as in `if cond; then;;`.

```rust
def log-if-greater-than-0 [i64];
fun log-if-greater-than-0 x =
    (if x > gt 0; log "greater than 0")
```

### Loops

Loops have the following form:

```
loop <expression>
```

The `expression` will be repeatedly evaluated until `break` is called.

To avoid infinite loops, most `loop` expressions will start or end with a break check, as in this example:

```rust
mut i = 0;
loop (
    (if i > gt 10; break)
    # iterating from 0 to 10
)
```

A more complex example:

```rust
# implementing the traditional `map` function in Wasmin
def map [[T] V, array(T)] array(V);
fun map function list = (
    mut index = 0;
    def result array(V)(list > size);
    mut result = [];
    loop (
        if index > ge_u (list > size); break;;
        let item = get list index;
        set result index = function item;
        set index = add index 1;
    )
    result
)
```

### Special functions (get, get-or-default, set, remove, size)

We already saw how to use `get` and `set` to read and write fields in records and items in arrays, and `size` to
inspect the length of an array.

To recap:

```rust
let my-array = [1 2 3];
let first = get my-array 0;

let size-of-array = size my-array;

let Rec = {name string};

def rec Rec;
mut rec = {name "the record"};

set rec name = "another name";
```

Another function we haven't met yet is the `remove` function, which:

* for arrays: returns the element at the index provided without making a copy of it, leaving the zeroth-value in its place.
* for records: returns the value of the field with the provided name without making a copy of it, leaving the zeroth-value in its place.

Notice that the `get` function, on the other hand, must return a copy of the element it picks from the array or record 
(unless the type of the value is a primitive) in order to not violate the linearity of the Wasmin type system
(which allows it to avoid memory management). 

Example:

```rust
let Rec = {name string};

def rec Rec;
mut rec = {name "the record"};

let current-name = remove rec name;

# `get rec name` would now return the empty String!
```

Notice that these _special functions_ never consume their first argument (i.e. the receiver of the call), so that the
array or record can always be used after they are called.

### Memory Management

Finally, we can discuss one of the most innovative aspects of Wasmin in more detail: its memory management, or lack thereof.

As mentioned before, Wasmin does not have a garbage-collector, and it does not require the programmer
to manage memory in any way.

You may be asking yourself: how does it do that?

Simple: Wasmin uses a [linear type](https://wiki.c2.com/?LinearTypes) system for everything except WASM primitives (number types).

The fact that a linear type system is used, which means that there must only be a single reference to a value at
any given time, allows Wasmin to know that once a variable goes out of scope locally, its value can be immediately
de-allocated, together with everything it itself refers to (as everything else is also subject to this rule).

Wasmin only needs to insert some instructions at compile time to make sure that this happens, without having to
include a runtime to do anything more complicated like a garbage collector or even a reference-count manager. 

The observation that linear types allow a programming language to completely avoid garbage collection and manual 
memory management is based on a short paper by [Henry G. Baker](http://home.pipeline.com/~hbaker1/ForthStack.html).
