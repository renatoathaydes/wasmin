abstract class AstNode {
  const AstNode._();

  T match<T>(T Function(Let) onLet) {
    if (this is Let) {
      return onLet(this as Let);
    }
    throw 'unreachable';
  }
}

enum ValueType { i32, i64, f32, f64 }

extension ValueTypeMethods on ValueType {
  T match<T>({
    T Function() i32,
    T Function() i64,
    T Function() f32,
    T Function() f64,
  }) {
    switch (this) {
      case ValueType.i32:
        return i32();
      case ValueType.i64:
        return i64();
      case ValueType.f32:
        return f32();
      case ValueType.f64:
        return f64();
    }
    throw 'Uncovered: $this';
  }

  String name() => match(
      i32: () => 'i32', i64: () => 'i64', f32: () => 'f32', f64: () => 'f64');
}

class Expression {
  final String op;
  final List<String> args;
  final ValueType type;

  const Expression(this.op, this.args, this.type);

  @override
  String toString() => args.isEmpty
      ? '($op ${type.name()})'
      : '($op ${args.join(' ')} ${type.name()})';
}

class Let extends AstNode {
  final String id;
  final Expression expr;

  const Let(this.id, this.expr) : super._();

  String get type => expr.type.name();

  @override
  String toString() => '(let $id $expr)';
}
