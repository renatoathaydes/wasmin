import 'package:test/test.dart';
import 'package:wasmin/src/ast.dart';
import 'package:wasmin/src/text_sink.dart';

void main() {
  TextSink textSink;
  String Function() readText;

  setUp(() {
    StringSink sink = StringBuffer();
    textSink = TextSink(sink);
    readText = () {
      textSink.close();
      return sink.toString();
    };
  });

  test('Can write simple math expression', () {
    textSink.add(Expression(
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
    textSink.add(Let('variable', Expression.constant('10', ValueType.i64)));

    expect(
        readText(),
        equals(r'(local $variable i64)'
            '\n'
            r'(local.set $variable (i64.const 10))'
            '\n'));
  });

  test('Can write many let expressions', () {
    textSink.add(Let('a1', Expression.constant('10', ValueType.i64)));
    textSink.add(Let('b2', Expression.constant('0.22', ValueType.f32)));
    textSink.add(Let('c3', Expression.constant('55', ValueType.i64)));

    expect(
        readText(),
        equals(r'(local $a1 i64)'
            '\n'
            r'(local $b2 f32)'
            '\n'
            r'(local $c3 i64)'
            '\n'
            r'(local.set $a1 (i64.const 10))'
            '\n'
            r'(local.set $b2 (f32.const 0.22))'
            '\n'
            r'(local.set $c3 (i64.const 55))'
            '\n'));
  });
}
