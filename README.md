# Wasmin

A programming language that is a thin layer over pure WebAssembly (WASM).

Because it compiles down to WASM, it can run anywhere: browsers, native, JVM.

Because the compiler is written in Dart, Wasmin code can be compiled from anything:
 Flutter mobile apps, web apps, native applications.

## Goals of this project

- stay close to WASM for fast compilation and zero runtime dependencies.
- no heap memory management (GC) - at least until WASM supports it.
- favour the functional programming paradigm.
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

Wasmin is very simple to learn! It has very few concepts, but is still able to leverage the full
power of WASM, so while Wasmin programs look simple, they can do anything more complicated languages
can!

### Basics

There's only one way to define variables and functions, with the `let` keyword:

```pony
// variable
let my-var = 10;

// function with one arg of type i32, returns i32
echo: [i32] i32
let echo i = i + 1;
```

> Notice that function's type signatures are separated from a function's implementation, and
> must be declared before they are used.

The only difference between a variable and a function is the fact that functions take one or more arguments.

A variable definition, like a function, can even be made up of many expressions! Just group the expressions
together within `(` and `)`:

```pony
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

Expressions must be either separated with a `;` or grouped between parenthesis.

The 2 examples below are equivalent:

```pony
// using ;
let x = mul 2 3;
let y = add x 1;

// using ( )
let x = (mul 2 3)
let y = (add x 1)
```

Nested expressions are either grouped with parenthesis:

```pony
let y = (add 1 (mul 2 3))
```

Or passed over with the `>` operator, which uses the result of the previous expression as the
last argument of the next:

```pony
// this is equivalent to the previous example
let y = mul 2 3 > add 1;
```

> The `>` operator actually allows the programmer to use the WASM stack machine directly, so something like
> `2 > 3 > add > mul 2` gets translated to `(i64.const 2)(i64.const 3)(add)(i64.const 2)(mul)`.

Variables and functions may be exported:

```pony
// export the main function, which does not take any arguments
// and returns an i64
export main: i64;

let main = add 10 20;
```

### Type system

Wasmin uses all the basic types provided by WASM:

* `i32` - 32-bit integers.
* `i64` - 64-bit integers.
* `f32` - 32-bit floating-point.
* `f64` - 64-bit floating-point.

Whole numbers are `i64` by default, and fractional numbers are `f64` by default.

To make a number use the 32-bit types, you need to append the appropriate type name to the
number:

```pony
let an-i32-int = 100i32;
let a-f32-float = 0.314f32;
```

Strings can be declared as in most other languages:

```pony
let my-string = "hello world";
```

Records can be defined similarly to functions and variables, but instead of taking an expression
as the body, they take a record definition, which have the following form:

```pony
{ [field_name field_type,]... }
```

For example:

```pony
let Person = {name string, age i32}
```

An instance of a record can be created as follows:

```pony
let joe = {name "Joe", age 35.i32};
```

