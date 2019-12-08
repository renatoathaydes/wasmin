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

class ValueType {
  static const ValueType i32 = ValueType('i32');
  static const ValueType i64 = ValueType('i64');
  static const ValueType f32 = ValueType('f32');
  static const ValueType f64 = ValueType('f64');
  static const ValueType empty = ValueType('empty');
  static const ValueType anyFun = ValueType('anyfunc');

  final String name;

  const ValueType(this.name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ValueType &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'ValueType{name: $name}';
}

/// The no-op node can be used when a source code construct
/// performs no operation (e.g. whitespace).
class Noop extends AstNode {
  const Noop() : super._();
}

/// An Expression is an arrangement, or combination, of function calls,
/// constants and variables.
class Expression extends AstNode {
  final String op;
  final ValueType type;

  const Expression._create(this.op, this.type) : super._();

  factory Expression.constant(String value, ValueType type) {
    return _Const(value, type);
  }

  factory Expression.variable(String name, ValueType type) {
    return _Var(name, type);
  }

  factory Expression.funCall(
      String name, List<Expression> args, ValueType type) {
    return _FunCall(name, args, type);
  }

  T matchExpr<T>({
    T Function(String value, ValueType type) onConst,
    T Function(String value, ValueType type) onVariable,
    T Function(String name, List<Expression> args, ValueType type) onFunCall,
  }) {
    if (this is _Const) return onConst(op, type);
    if (this is _Var) return onVariable(op, type);
    if (this is _FunCall) {
      final f = this as _FunCall;
      return onFunCall(op, f.args, type);
    }
    throw 'unreachable';
  }

  @override
  String toString() => '($op ${type.name})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Expression &&
          runtimeType == other.runtimeType &&
          op == other.op &&
          type == other.type;

  @override
  int get hashCode => op.hashCode ^ type.hashCode;
}

class _Const extends Expression {
  const _Const(String value, ValueType type) : super._create(value, type);
}

class _Var extends Expression {
  const _Var(String name, ValueType type) : super._create(name, type);
}

class _FunCall extends Expression {
  final List<Expression> args;

  _FunCall(String name, this.args, ValueType type) : super._create(name, type);

  void foo() {}

  @override
  String toString() =>
      args.isEmpty ? super.toString() : '($op ${args.join(' ')} ${type.name})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is _FunCall &&
          const ListEquality<Expression>().equals(this.args, other.args);

  @override
  int get hashCode => super.hashCode ^ args.hashCode;
}

/// Let expressions are simple assignments of expressions to an identifier.
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
