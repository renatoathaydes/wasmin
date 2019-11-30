# Wasmin

A programming language that is a thin layer over pure WebAssembly (WASM).

Because it compiles down to WASM, it can run anywhere: browsers, native, JVM.

Because the compiler is written in Dart, Wasmin code can be compiled from anything:
 Flutter mobile apps, web apps, native applications.

## Goals of this project

- stay close to WASM for fast compilation and zero runtime dependencies.
- no heap memory management (GC) - at least until WASM supports it.
- favour the functional programming paradigm.
- 
  
## This is work in progress

Checklist:

- [x] primitive values.
- [x] let declarations.
- [ ] math operators.
- [ ] functions.
- [ ] if/else blocks.
- [ ] loops.
- [ ] constant globals.
- [ ] string values.
- [ ] function pointers.
- [ ] parenthesis grouping.
- [ ] data pointers.
- [ ] single-line comments.
- [ ] multi-line comments.
- [ ] import external functions.
- [ ] export symbols.
