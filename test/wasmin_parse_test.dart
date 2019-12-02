import 'package:test/test.dart';
import 'package:wasmin/wasmin.dart';

import 'test_helper.dart';

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
            .having((let) => let.expr, 'expr', isConstant));
    expect(
        nodes[1],
        isA<Let>()
            .having((let) => let.id, 'id', equals('y'))
            .having((let) => let.type, 'type', equals(ValueType.i64))
            .having((let) => let.expr.op, 'expr.op', equals('10'))
            .having((let) => let.expr, 'expr', isConstant));
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
                (let) => argsOfFunCall(let.expr),
                'expr.args',
                equals([
                  Expression.constant('10', ValueType.i64),
                  Expression.constant('20', ValueType.i64),
                ])));
  });

  test('can parse function call using local variable', () async {
    final nodes = await compileWasmin(
        'source', ['let my-value = 100;let res=mul my-value 10']).toList();

    expect(nodes.length, equals(2));
    expect(
        nodes[0],
        isA<Let>()
            .having((let) => let.id, 'id', equals('my-value'))
            .having((let) => let.type, 'type', equals(ValueType.i64))
            .having((let) => let.expr.op, 'expr.op', equals('100'))
            .having((let) => let.expr, 'expr', isConstant));
    expect(
        nodes[1],
        isA<Let>()
            .having((let) => let.id, 'id', equals('res'))
            .having((let) => let.type, 'type', equals(ValueType.i64))
            .having((let) => let.expr.op, 'op', equals('mul'))
            .having(
                (let) => argsOfFunCall(let.expr),
                'args',
                equals([
                  Expression.variable('my-value', ValueType.i64),
                  Expression.constant('10', ValueType.i64),
                ])));
  });
}
