import 'package:collection/collection.dart';

import 'type.dart';

/// An Expression is an arrangement, or combination, of function calls,
/// constants and variables.
abstract class Expression {
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

  factory Expression.ifExpr(Expression cond, Expression then,
      [Expression els]) {
    return IfExpression(cond, then, els);
  }

  factory Expression.loopExpr(Expression body) {
    return LoopExpression(body);
  }

  factory Expression.breakExpr() {
    return const _Break();
  }

  factory Expression.group(Iterable<Expression> body) {
    return Group(body.toList(growable: false));
  }

  T matchExpr<T>({
    T Function(Const) onConst,
    T Function(Var) onVariable,
    T Function(FunCall) onFunCall,
    T Function(LetExpression) onLet,
    T Function(IfExpression) onIf,
    T Function(LoopExpression) onLoop,
    T Function() onBreak,
    T Function(Group) onGroup,
  });

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

mixin Assignment {
  String get keyword;

  String get id;

  ValueType get varType;
}

class Const extends Expression {
  final String value;

  const Const(this.value, ValueType type) : super._create(value, type);

  @override
  String toString() => 'Const{value: $value, type: ${type.name}}';

  @override
  T matchExpr<T>({
    T Function(Const) onConst,
    T Function(Var) onVariable,
    T Function(FunCall) onFunCall,
    T Function(LetExpression) onLet,
    T Function(IfExpression) onIf,
    T Function(LoopExpression) onLoop,
    T Function() onBreak,
    T Function(Group) onGroup,
  }) {
    return onConst(this);
  }
}

class Var extends Expression {
  final String name;

  const Var(this.name, ValueType type) : super._create(name, type);

  @override
  String toString() => 'Var{name: $name, type: $type}';

  @override
  T matchExpr<T>({
    T Function(Const) onConst,
    T Function(Var) onVariable,
    T Function(FunCall) onFunCall,
    T Function(LetExpression) onLet,
    T Function(IfExpression) onIf,
    T Function(LoopExpression) onLoop,
    T Function() onBreak,
    T Function(Group) onGroup,
  }) {
    return onVariable(this);
  }
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

  @override
  T matchExpr<T>({
    T Function(Const) onConst,
    T Function(Var) onVariable,
    T Function(FunCall) onFunCall,
    T Function(LetExpression) onLet,
    T Function(IfExpression) onIf,
    T Function(LoopExpression) onLoop,
    T Function() onBreak,
    T Function(Group) onGroup,
  }) {
    return onFunCall(this);
  }
}

class LetExpression extends Expression with Assignment {
  @override
  String get keyword => 'let';

  @override
  String get id => _id;

  final Expression body;

  @override
  ValueType get varType => body.type;

  LetExpression(String id, this.body) : super._create(id, ValueType.empty);

  @override
  String toString() => '(let $_id = $body)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other && other is LetExpression && body == other.body;

  @override
  int get hashCode => super.hashCode ^ body.hashCode;

  @override
  T matchExpr<T>({
    T Function(Const) onConst,
    T Function(Var) onVariable,
    T Function(FunCall) onFunCall,
    T Function(LetExpression) onLet,
    T Function(IfExpression) onIf,
    T Function(LoopExpression) onLoop,
    T Function() onBreak,
    T Function(Group) onGroup,
  }) {
    return onLet(this);
  }
}

class IfExpression extends Expression {
  final Expression cond;
  final Expression then;
  final Expression els;

  IfExpression(this.cond, this.then, [this.els])
      : super._create('', els?.type ?? ValueType.empty);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is IfExpression &&
          runtimeType == other.runtimeType &&
          cond == other.cond &&
          then == other.then &&
          els == other.els;

  @override
  int get hashCode =>
      super.hashCode ^ cond.hashCode ^ then.hashCode ^ els.hashCode;

  @override
  String toString() => '(if $cond $then${els != null ? ' $els' : ''})';

  @override
  T matchExpr<T>({
    T Function(Const) onConst,
    T Function(Var) onVariable,
    T Function(FunCall) onFunCall,
    T Function(LetExpression) onLet,
    T Function(IfExpression) onIf,
    T Function(LoopExpression) onLoop,
    T Function() onBreak,
    T Function(Group) onGroup,
  }) {
    return onIf(this);
  }
}

class _Break extends Expression {
  const _Break() : super._create('break', ValueType.empty);

  @override
  T matchExpr<T>({
    T Function(Const) onConst,
    T Function(Var) onVariable,
    T Function(FunCall) onFunCall,
    T Function(LetExpression) onLet,
    T Function(IfExpression) onIf,
    T Function(LoopExpression) onLoop,
    T Function() onBreak,
    T Function(Group) onGroup,
  }) {
    return onBreak();
  }
}

class Group extends Expression {
  final List<Expression> body;

  Group(this.body)
      : super._create('', body.isEmpty ? ValueType.empty : body.last.type);

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

  @override
  T matchExpr<T>({
    T Function(Const) onConst,
    T Function(Var) onVariable,
    T Function(FunCall) onFunCall,
    T Function(LetExpression) onLet,
    T Function(IfExpression) onIf,
    T Function(LoopExpression) onLoop,
    T Function() onBreak,
    T Function(Group) onGroup,
  }) {
    return onGroup(this);
  }
}

class LoopExpression extends Expression {
  final Expression body;

  LoopExpression(this.body) : super._create('loop', ValueType.empty);

  @override
  String toString() => '(loop $body)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other && other is LoopExpression && body == other.body;

  @override
  int get hashCode => super.hashCode ^ body.hashCode;

  @override
  T matchExpr<T>({
    T Function(Const) onConst,
    T Function(Var) onVariable,
    T Function(FunCall) onFunCall,
    T Function(LetExpression) onLet,
    T Function(IfExpression) onIf,
    T Function(LoopExpression) onLoop,
    T Function() onBreak,
    T Function(Group) onGroup,
  }) {
    return onLoop(this);
  }
}
