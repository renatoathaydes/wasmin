@TestOn('vm')
import 'dart:async';

import 'package:test/test.dart';

import '../../bin/wasmin.dart' as wasmin;

void main() {
  test('example/example.wasmin', () async {
    final lines = <String>[];
    final exitCode = await runZoned(
        () => wasmin.run(['example/example.wasmin']),
        zoneSpecification:
            ZoneSpecification(print: (a, b, c, line) => lines.add(line)));
    expect(lines.join(' '), equalsIgnoringWhitespace(r'''
    (module
      (export "main" (func $main))
      (export "_start" (func $_start))
      (func $main (result i32)
        (local $a i32)
        (local $b i32)
        (local $result i32)
        (local.set $a 
          (i32.const 10)
        )
        (local.set $b 
          (i32.const 20)
        )
        (local.set $result
          (i32.add
            (local.get $a)
            (local.get $b)
          )
        )
        (call $do-add
          (local.get $result)
          (i32.const 1)
        )
      )
      (func $_start (result i32)
        (call $main
        )
      )
      (func $do-add (param $a i32) (param $b i32) (result i32)
        (i32.add
          (local.get $a)
          (local.get $b)
        )
      )
    )
    '''));
    expect(exitCode, equals(0));
  });

  test('example/factorial.wasmin', () async {
    final lines = <String>[];
    final exitCode = await runZoned(
        () => wasmin.run(['example/factorial.wasmin']),
        zoneSpecification:
            ZoneSpecification(print: (a, b, c, line) => lines.add(line)));
    expect(lines.join(' '), equalsIgnoringWhitespace(r'''
    (module
      (export "_start" (func $_start))
      (func $factorial (param $n i64) (result i64)
        (if (result i64)
          (i64.eq
            (local.get $n)
            (i64.const 1)
          )
          (i64.const 1)
          (i64.mul
            (local.get $n)
            (call $factorial
              (i64.sub
                (local.get $n)
                (i64.const 1)
              )
            )
          )
        )
      )
      (func $_start (result i64)
        (call $factorial
          (i64.const 20)
        )
      )
    )
    '''));
    expect(exitCode, equals(0));
  });
}
