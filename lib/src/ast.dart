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

extension on ValueType {
  String name() {
    switch (this) {
      case ValueType.i32:
        return 'i32';
      case ValueType.i64:
        return 'i64';
      case ValueType.f32:
        return 'f32';
      case ValueType.f64:
        return 'f64';
    }
    throw 'Uncovered: $this';
  }
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
