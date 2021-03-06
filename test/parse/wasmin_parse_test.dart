import 'package:test/test.dart';
import 'package:wasmin/wasmin.dart';

void main() {
  test('can parse simple let expressions', () async {
    final unit = await compileWasmin('source', ['let x = 0;', 'let y = 10']);

    expect(unit.declarations.length, isZero);
    expect(unit.implementations.length, equals(2));

    final nodes = unit.implementations;

    expect(
        nodes[0],
        isA<Let>()
            .having((let) => let.declaration.id, 'id', equals('x'))
            .having((let) => let.type, 'type', equals(ValueType.i32))
            .having((let) => let.body, 'body',
                equals(Expression.constant('0', ValueType.i32))));
    expect(
        nodes[1],
        isA<Let>()
            .having((let) => let.declaration.id, 'id', equals('y'))
            .having((let) => let.type, 'type', equals(ValueType.i32))
            .having((let) => let.body, 'body',
                equals(Expression.constant('10', ValueType.i32))));
  });

  test('can parse let expression with function call', () async {
    final unit = await compileWasmin('source', ['let my-value = mul 10 20']);

    expect(unit.declarations.length, isZero);
    expect(unit.implementations.length, equals(1));

    final nodes = unit.implementations;

    expect(
        nodes[0],
        isA<Let>()
            .having((let) => let.declaration.id, 'id', equals('my-value'))
            .having((let) => let.type, 'type', equals(ValueType.i32))
            .having(
                (let) => let.body,
                'expr.op',
                equals(Expression.funCall(
                    'mul',
                    [
                      Expression.constant('10', ValueType.i32),
                      Expression.constant('20', ValueType.i32),
                    ],
                    ValueType.i32))));
  });

  test('can parse let declaration followed by its implementation', () async {
    final unit =
        await compileWasmin('source', ['def my-value i64;let my-value = 20']);

    expect(unit.declarations.length, equals(1));
    expect(unit.implementations.length, equals(1));

    final letDecl = VarDeclaration('my-value', ValueType.i64, isGlobal: true);
    expect(unit.declarations[0], equals(letDecl));
    expect(unit.implementations[0],
        equals(Let(letDecl, Const('20', ValueType.i64))));
  });

  test('can parse fun declaration followed by its implementation', () async {
    final unit = await compileWasmin(
        'source', ['def foo[f64] f64 ; fun foo n = add n 1.0']);

    expect(unit.declarations.length, equals(1));
    expect(unit.implementations.length, equals(1));

    final funDecl =
        FunDeclaration('foo', FunType(ValueType.f64, [ValueType.f64]));
    expect(unit.declarations[0], equals(funDecl));
    expect(
        unit.implementations[0],
        equals(Fun(
            funDecl,
            const ['n'],
            Expression.funCall(
                'add',
                [
                  Expression.variable('n', ValueType.f64),
                  Expression.constant('1.0', ValueType.f64)
                ],
                ValueType.f64))));
  });

  // FIXME top-level let expression not implemented yet
  /*
  test('can parse function call using local variable', () async {
    final unit = await compileWasmin(
        'source', ['let my-value', ' = 100;let res=mul my-value', ' 10']);

    expect(nodes.length, equals(2));
    expect(
        nodes[0],
        isA<Let>()
            .having((let) => let.declaration.name, 'id', equals('my-value'))
            .having((let) => let.type, 'type', equals(ValueType.i64))
            .having((let) => let.body, 'expr.op',
                equals(Expression.constant('100', ValueType.i64))));
    expect(
        nodes[1],
        isA<Let>()
            .having((let) => let.declaration.name, 'id', equals('res'))
            .having((let) => let.type, 'type', equals(ValueType.i64))
            .having(
                (let) => let.body,
                'op',
                equals(Expression.funCall(
                    'mul',
                    [
                      Expression.variable('my-value', ValueType.i64),
                      Expression.constant('10', ValueType.i64)
                    ],
                    ValueType.i64))));
  });

   */
}
