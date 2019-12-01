import 'package:test/test.dart';
import 'package:wasmin/wasmin.dart';

void main() {
  test('can parse simple let expressions', () async {
    final nodes =
        await compileWasmin('source', ['let x = 0;', 'let y = 10']).toList();

    expect(nodes.length, equals(2));
    expect(
        nodes[0],
        isA<Let>()
            .having((let) => let.id, 'id', equals('x'))
            .having((let) => let.type, 'type', equals(ValueType.i64))
            .having((let) => let.expr.op, 'expr.op', equals('0'))
            .having((let) => let.expr.args, 'expr.args', isEmpty));
    expect(
        nodes[1],
        isA<Let>()
            .having((let) => let.id, 'id', equals('y'))
            .having((let) => let.type, 'type', equals(ValueType.i64))
            .having((let) => let.expr.op, 'expr.op', equals('10'))
            .having((let) => let.expr.args, 'expr.args', isEmpty));
  });

  test('can parse let expression with function call', () async {
    final nodes =
        await compileWasmin('source', ['let my-value = mul 10 20']).toList();

    expect(nodes.length, equals(1));
    expect(
        nodes[0],
        isA<Let>()
            .having((let) => let.id, 'id', equals('my-value'))
            .having((let) => let.type, 'type', equals(ValueType.i64))
            .having((let) => let.expr.op, 'expr.op', equals('mul'))
            .having(
                (let) => let.expr.args,
                'expr.args',
                equals([
                  Expression.constant('10', ValueType.i64),
                  Expression.constant('20', ValueType.i64),
                ])));
  });
}
