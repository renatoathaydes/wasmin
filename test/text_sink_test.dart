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

  test('Can write simple math expression', () {
    textSink.add(Expression.funCall(
        'add',
        [
          Expression.constant('10', ValueType.i64),
          Expression.constant('20', ValueType.i64)
        ],
        ValueType.i64));

    expect(
        readText(),
        equals(r'(i64.add (i64.const 10) (i64.const 20))'
            '\n'));
  });

  test('Can write simple let expression', () {
    textSink.add(
        LetExpression('variable', Expression.constant('10', ValueType.i64)));

    expect(
        readText(),
        equals(
            //r'(local $variable i64)'
            //'\n'
            r'(local.set $variable (i64.const 10))'
            '\n'));
  });

  test('Can write many let expressions', () {
    textSink.add(LetExpression('a1', Expression.constant('10', ValueType.i64)));
    textSink
        .add(LetExpression('b2', Expression.constant('0.22', ValueType.f32)));
    textSink.add(LetExpression('c3', Expression.constant('55', ValueType.i64)));

    expect(
        readText(),
        // FIXME variables should be declared at the beginning of a function
        equals(
            // r'(local $a1 i64)'
            // '\n'
            // r'(local $b2 f32)'
            // '\n'
            // r'(local $c3 i64)'
            // '\n'
            r'(local.set $a1 (i64.const 10))'
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

    expect(
        readText(),
        equals(r'(i64.add (local.get $a) (local.get $b))'
            '\n'));
  });
}
