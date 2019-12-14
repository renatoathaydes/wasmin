import 'package:collection/collection.dart';

import 'type.dart';

/// An Expression is an arrangement, or combination, of function calls,
/// constants and variables.
class Expression {
  final String _id;
  final ValueType type;

  const Expression._create(this._id, this.type);

  factory Expression.constant(String value, ValueType type) {
    return Const(value, type);
  }

  factory Expression.variable(String name, ValueType type) {
    return Var(name, type);
  }

  factory Expression.funCall(
      String name, List<Expression> args, ValueType type) {
    return FunCall(name, args, type);
  }

  factory Expression.let(String name, Expression body) {
    return LetExpression(name, body);
  }

  factory Expression.group(Iterable<Expression> body) {
    return Group(body.toList(growable: false));
  }

  T matchExpr<T>({
    T Function(Const) onConst,
    T Function(Var) onVariable,
    T Function(FunCall) onFunCall,
    T Function(LetExpression) onLet,
    T Function(Group) onGroup,
  }) {
    if (this is Const) return onConst(this as Const);
    if (this is Var) return onVariable(this as Var);
    if (this is FunCall) return onFunCall(this as FunCall);
    if (this is LetExpression) return onLet(this as LetExpression);
    throw 'unreachable';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Expression &&
          runtimeType == other.runtimeType &&
          _id == other._id &&
          type == other.type;

  @override
  int get hashCode => type.hashCode;
}

mixin AssignmentExpression on Expression {
  String get keyword;

  String get id;

  Expression get body;
}

class Const extends Expression {
  final String value;

  const Const(this.value, ValueType type) : super._create(value, type);

  @override
  String toString() => 'Const{value: $value, type: ${type.name}}';
}

class Var extends Expression {
  final String name;

  const Var(this.name, ValueType type) : super._create(name, type);

  @override
  String toString() => 'Var{name: $name, type: $type}';
}

class FunCall extends Expression {
  final List<Expression> args;
  final String name;

  const FunCall(this.name, this.args, ValueType type)
      : super._create(name, type);

  @override
  String toString() =>
      args.isEmpty ? super.toString() : '($_id ${args.join(' ')} ${type.name})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is FunCall &&
          const ListEquality<Expression>().equals(args, other.args);

  @override
  int get hashCode => super.hashCode ^ args.hashCode;
}

class LetExpression extends Expression with AssignmentExpression {
  @override
  String get keyword => 'let';

  @override
  final Expression body;

  @override
  String get id => _id;

  LetExpression(String name, this.body) : super._create(name, ValueType.empty);

  @override
  String toString() => '(let $_id = $body)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other && other is LetExpression && body == other.body;

  @override
  int get hashCode => super.hashCode ^ body.hashCode;
}

class Group extends Expression {
  final List<Expression> body;

  Group(this.body) : super._create('', body.last.type);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is Group &&
          runtimeType == other.runtimeType &&
          const IterableEquality<Expression>().equals(body, other.body);

  @override
  int get hashCode => super.hashCode ^ body.hashCode;

  @override
  String toString() => 'Group{$body}';
}
