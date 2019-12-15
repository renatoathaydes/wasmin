import 'package:test/test.dart';
import 'package:wasmin/src/text_sink.dart';
import 'package:wasmin/wasmin.dart';

void main() {
  WasmTextSink textSink;
  String Function() readText;

  setUp(() {
    StringSink sink = StringBuffer();
    textSink = WasmTextSink(sink);
    readText = () => sink.toString();
  });

  test('Can write constant', () {
    textSink.add(Expression.constant('10', ValueType.i32));
    expect(readText(), equals('(i32.const 10)'));
  });

  test('Can write variable use', () {
    textSink.add(Expression.variable('foo', ValueType.i32));
    expect(readText(), equals(r'(local.get $foo)'));
  });

  test('Can write simple function call', () {
    textSink.add(Expression.funCall(
        'add',
        [
          Expression.constant('10', ValueType.i64),
          Expression.constant('20', ValueType.i64)
        ],
        ValueType.i64));

    expect(readText(),
        equals('(i64.add\n  (i64.const 10)\n  (i64.const 20)\n)\n'));
  });

  test('Can write no-args function call', () {
    textSink.add(Expression.funCall('report', const [], ValueType.i64));

    expect(readText(), equals(r'(call $report)' '\n'));
  });

  test('Can write simple let declaration', () {
    textSink.add(LetDeclaration('variable', ValueType.i64));

    expect(readText(), equals(r'(local $variable i64)' '\n'));
  });

  test('Can write simple let expression', () {
    textSink.add(
        LetExpression('variable', Expression.constant('10', ValueType.i64)));

    expect(readText(), equals(r'(local.set $variable (i64.const 10))' '\n'));
  });

  test('Can write many let expressions', () {
    textSink.add(LetExpression('a1', Expression.constant('10', ValueType.i64)));
    textSink
        .add(LetExpression('b2', Expression.constant('0.22', ValueType.f32)));
    textSink.add(LetExpression('c3', Expression.constant('55', ValueType.i64)));

    expect(
        readText(),
        equals(r'(local.set $a1 (i64.const 10))'
            '\n'
            r'(local.set $b2 (f32.const 0.22))'
            '\n'
            r'(local.set $c3 (i64.const 55))'
            '\n'));
  });

  test('Can write expression of variables', () {
    textSink.add(Expression.funCall(
        'add',
        [
          Expression.variable('a', ValueType.i64),
          Expression.variable('b', ValueType.i64)
        ],
        ValueType.i64));

    expect(readText(),
        equals('(i64.add\n  (local.get \$a)\n  (local.get \$b)\n)\n'));
  });

  test('Can write group of expressions', () {
    textSink.add(Expression.group([
      Expression.let('x', Expression.constant('2', ValueType.i64)),
      Expression.let('y', Expression.constant('4', ValueType.i64)),
      Expression.funCall(
          'add',
          [
            Expression.variable('x', ValueType.i64),
            Expression.variable('y', ValueType.i64),
          ],
          ValueType.i64)
    ]));

    expect(
        readText(),
        equals(r'(local $x i64)'
            '\n'
            r'(local $y i64)'
            '\n'
            r'(local.set $x (i64.const 2))'
            '\n'
            r'(local.set $y (i64.const 4))'
            '\n'
            '(i64.add\n  (local.get \$x)\n  (local.get \$y)\n)\n'));
  });

  test('Can write simple function implementation', () {
    textSink.add(Fun(FunDeclaration('do-it', FunType(ValueType.i32, const [])),
        const [], Expression.constant('12', ValueType.i32)));

    expect(
        readText(),
        equals(r'(func $do-it (result i32)'
            '\n'
            r'  (i32.const 12)'
            '\n)'));
  });
}
