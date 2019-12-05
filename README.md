# Wasmin

A programming language that is a thin layer over pure WebAssembly (WASM).

Because it compiles down to WASM, it can run anywhere: browsers, native WASM runtimes, JVM.

Because the compiler is written in Dart, Wasmin code can be compiled from
 Flutter mobile apps, web apps, native Dart applications.

## Goals of this project

- stay close to WASM for fast compilation and zero runtime dependencies.
- no heap memory management (GC) - at least until WASM supports it.
- favour the functional programming paradigm.
- allow the WASM virtual stack to be used directly.
- simplest possible syntax that preserves readability.

## This is work in progress

Checklist:

- [x] primitive values.
- [x] let declarations.
- [x] math operators.
- [x] function calls.
- [ ] function declarations.
- [ ] module declarations.
- [ ] explicitly typed constants.
- [ ] if/else blocks.
- [ ] loops.
- [ ] stack operator `>`.
- [ ] constant globals.
- [ ] string values.
- [ ] function pointers.
- [x] parenthesis grouping.
- [ ] records.
- [ ] arrays.
- [ ] single-line comments.
- [ ] multi-line comments.
- [ ] import external functions.
- [ ] export symbols.

## The language

Wasmin is very simple! It has very few concepts, but is still able to leverage the full
power of WASM, so while Wasmin programs look simple, they can do anything more complicated languages
can!

### Basics

There's only one way to define variables and functions, with the `let` keyword:

```rust
// variable
let my-var = 10;

// function with one arg of type i32, returns i32
echo [i32] i32;
let echo i = i + 1;
```

> Notice that function's type signatures are separated from a function's implementation, and
> must be declared before they are used or implemented.

Function signatures have the following form:

```
function_name [ args ... ] return_type;
```

Variables do not declare their types, they assume the type of the last expression in their body.

The only difference between a variable and a function is the fact that functions take one or more arguments.

A variable definition, like a function, can even be made up of many expressions! Just group the expressions
together within parenthesis:

```rust
// variable that resolves to the result of some expressions
let complex-var = (
    let a = 1;
    let b = 2;
    let c = add a b;
    mul c 3
)

let complex-fun a b = (
    let c = add a b;
    mul c 3
)
```

> The body of a "variable" is evaluated only once, where it is declared. To evaluate the body multiple times, it must be
> declared as a function instead. Hence, it must take at least one argument even if it just ignores it.

A `;` (semi-colon) is used to separate consecutive expressions. Grouping expressions inside parenthesis,
however, makes it unnecessary to use `;`.

The 2 examples below are equivalent:

```rust
// using ;
let x = mul 2 3;
let y = add x 1;

// using ( )
let x = (mul 2 3)
let y = (add x 1)
```

Nested expressions are either grouped with parenthesis:

```rust
let y = (add 1 (mul 2 3))
```

Or passed over with the `>` operator, which uses the result of the previous expression(s) as the
last argument(s) of the next (if it takes any):

```rust
// this is equivalent to the previous example
let y = mul 2 3 > add 1;
```

The `>` operator actually allows the programmer to use the WASM stack machine directly!

This example:

```rust
2 > 3 > add > mul 2
```

Gets translated into WASM as:

```wat
i64.const 2
i64.const 3
add
i64.const 2
mul
```

And is equivalent to:

```rust
(mul 2 (add 2 3))
```

Variables and functions may be exported:

```rust
// export the main function, which does not take any arguments
// and returns an i64
export main i64;

let main = add 10 20;
```

Mathematical operators are simple functions in Wasmin, as in WASM:

* `mul` multiplies two numbers.
* `add` adds two numbers.
* `div_s` and `div_u` divide two signed or unsigned numbers, respectively.
* `and`, `or`, `xor` etc. perform logical operations.

See the WASM specification for all available operators.

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

Besides number types, Wasmin also has `String`, for text, and custom record types.

> TODO: these types necessarily allocate on the heap. How to manage them without a Garbage Collector?

Strings can be declared as in most other languages:

```rust
let my-string = "hello world";
```

Records can be defined similarly to functions and variables, but instead of taking an expression
as the body, they take a record definition, which have the following form:

```
{ [field_name field_type,]... }
```

For example:

```rust
let Person = {name string, age i32}
```

An instance of a record can be created as follows:

```rust
let joe = {name "Joe", age 35i32};
```

As Wasmin has no methods, only functions can manipulate data.

Supposing there is a function `toUpper [String] String`, one could use it as such:

```rust
let upper = toUpper "hello";

// alternatively
let upper2 = "hello" > toUpper;
```

Similarly, record fields can be obtained by using their names as functions:

```rust
let joe = {name "Joe", age 35i32};
let joesAge = age joe;

// or, more property-like
let joesAge2 = joe > age;
```
