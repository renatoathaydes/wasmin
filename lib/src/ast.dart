import 'package:collection/collection.dart';

abstract class AstNode {
  const AstNode._();

  T match<T>(T Function(Let) onLet, T Function(Expression) onExpression) {
    if (this is Let) {
      return onLet(this as Let);
    }
    if (this is Expression) {
      return onExpression(this as Expression);
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
    if (this == null) return null;
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

class Noop extends AstNode {
  const Noop() : super._();
}

class Expression extends AstNode {
  final String op;
  final List<Expression> args;
  final ValueType type;

  const Expression(this.op, this.args, this.type) : super._();

  const Expression.constant(String name, ValueType type)
      : this(name, const [], type);

  @override
  String toString() => args.isEmpty
      ? '($op ${type.name()})'
      : '($op ${args.join(' ')} ${type.name()})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Expression &&
          runtimeType == other.runtimeType &&
          op == other.op &&
          const ListEquality<Expression>().equals(args, other.args) &&
          type == other.type;

  @override
  int get hashCode => op.hashCode ^ args.hashCode ^ type.hashCode;
}

class Let extends AstNode {
  final String id;
  final Expression expr;

  const Let(this.id, this.expr) : super._();

  ValueType get type => expr.type;

  @override
  String toString() => '(let $id $expr)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Let &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          expr == other.expr;

  @override
  int get hashCode => id.hashCode ^ expr.hashCode;
}
