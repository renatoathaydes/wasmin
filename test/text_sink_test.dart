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

    expect(
        readText(), equals('(i64.add\n  (i64.const 10)\n  (i64.const 20)\n)'));
  });

  test('Can write no-args function call', () {
    textSink.add(Expression.funCall('report', const [], ValueType.i64));

    expect(readText(), equals(r'(call $report)'));
  });

  test('Can write simple let declaration', () {
    textSink.add(LetDeclaration('variable', ValueType.i64));

    expect(readText(), equals(r'(local $variable i64)'));
  });

  test('Can write simple let expression', () {
    textSink.add(
        LetExpression('variable', Expression.constant('10', ValueType.i64)));

    expect(readText(), equals('(local.set \$variable\n  (i64.const 10)\n)'));
  });

  test('Can write many let expressions', () {
    textSink.add(LetExpression('a1', Expression.constant('10', ValueType.i64)));
    textSink
        .add(LetExpression('b2', Expression.constant('0.22', ValueType.f32)));
    textSink.add(LetExpression('c3', Expression.constant('55', ValueType.i64)));

    expect(
        readText(),
        equals('(local.set \$a1\n  (i64.const 10)\n)'
            '(local.set \$b2\n  (f32.const 0.22)\n)'
            '(local.set \$c3\n  (i64.const 55)\n)'));
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
        equals('(i64.add\n  (local.get \$a)\n  (local.get \$b)\n)'));
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
        equals('(local \$x i64)\n'
            '(local \$y i64)\n'
            '(local.set \$x\n  (i64.const 2)\n)\n'
            '(local.set \$y\n  (i64.const 4)\n)\n'
            '(i64.add\n  (local.get \$x)\n  (local.get \$y)\n)'));
  });

  test('Can write simple function implementation', () {
    textSink.add(Fun(FunDeclaration('do-it', FunType(ValueType.i32, const [])),
        const [], Expression.constant('12', ValueType.i32)));

    expect(
        readText(),
        equals('(func \$do-it (result i32)\n'
            '  (i32.const 12)\n'
            ')'));
  });

  test('Can write if statement without else', () {
    textSink.add(Expression.ifExpr(
      Expression.funCall(
          'gt_s',
          [
            Expression.variable('x', ValueType.i64),
            Expression.constant('10', ValueType.i64)
          ],
          ValueType.i64),
      Expression.funCall(
          'add',
          [
            Expression.variable('x', ValueType.i64),
            Expression.variable('x', ValueType.i64)
          ],
          ValueType.i64),
    ));

    expect(
        readText(),
        equals('(if\n'
            '  (i64.gt_s\n'
            '    (local.get \$x)\n'
            '    (i64.const 10)\n'
            '  )\n'
            '  (i64.add\n'
            '    (local.get \$x)\n'
            '    (local.get \$x)\n'
            '  )\n'
            ')'));
  });

  test('Can write if expression', () {
    textSink.add(Expression.ifExpr(
        Expression.funCall(
            'gt_s',
            [
              Expression.variable('x', ValueType.i64),
              Expression.constant('10', ValueType.i64)
            ],
            ValueType.i64),
        Expression.funCall(
            'add',
            [
              Expression.variable('x', ValueType.i64),
              Expression.variable('x', ValueType.i64)
            ],
            ValueType.i64),
        Expression.constant('0', ValueType.i64)));

    expect(
        readText(),
        equals('(if (result i64)\n'
            '  (i64.gt_s\n'
            '    (local.get \$x)\n'
            '    (i64.const 10)\n'
            '  )\n'
            '  (i64.add\n'
            '    (local.get \$x)\n'
            '    (local.get \$x)\n'
            '  )\n'
            '  (i64.const 0)\n'
            ')'));
  });

  test('can write simplest loop expression', () {
    textSink.add(Expression.loopExpr(Expression.constant('10', ValueType.i32)));
    expect(readText(), equals('(loop \$block0\n  (i32.const 10)\n)'));
  });

  test('can write usual loop expression', () {
    textSink.add(Expression.loopExpr(Expression.group([
      Expression.ifExpr(
          Expression.constant('1', ValueType.i32), Expression.breakExpr()),
      Expression.funCall(
          'add',
          [
            Expression.constant('10', ValueType.i32),
            Expression.constant('20', ValueType.i32),
          ],
          ValueType.i32),
    ])));
    expect(
        readText(),
        equals('(loop \$block0\n'
            '  (if\n'
            '    (i32.const 1)\n'
            '    (br \$block0)\n'
            '  )\n'
            '  (i32.add\n'
            '    (i32.const 10)\n'
            '    (i32.const 20)\n'
            '  )\n'
            ')'));
  });
}
