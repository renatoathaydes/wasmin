import 'package:collection/collection.dart';

import 'ast.dart';
import 'parse/iterator.dart';
import 'type.dart';

/// An Expression is an arrangement, or combination, of function calls,
/// constants and variables.
abstract class Expression {
  final String _id;
  final ValueType type;

  /// Get the nested variable declarations within this Expression.
  ///
  /// Any Expression that contains a block of code may contain declarations.
  List<VarDeclaration> get declarations => const [];

  const Expression._create(this._id, this.type);

  factory Expression.constant(String value, ValueType type) {
    return Const(value, type);
  }

  factory Expression.variable(String name, ValueType type,
      [bool isGlobal = false]) {
    return Var(name, type, isGlobal);
  }

  factory Expression.funCall(
      String name, List<Expression> args, ValueType type) {
    return FunCall(name, args, type);
  }

  factory Expression.let(String name, Expression body) {
    return AssignExpression(AssignmentType.let, name, body);
  }

  factory Expression.letWithDeclaration(
      VarDeclaration declaration, Expression body) {
    return AssignExpression.withDeclaration(
        AssignmentType.let, declaration, body);
  }

  factory Expression.mut(String name, Expression body) {
    return AssignExpression(AssignmentType.mut, name, body);
  }

  factory Expression.reassign(String name, Expression body) {
    return AssignExpression(AssignmentType.reassign, name, body);
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

  factory Expression.empty() {
    return const Const('', ValueType.empty);
  }

  T matchExpr<T>({
    T Function(Const) onConst,
    T Function(Var) onVariable,
    T Function(FunCall) onFunCall,
    T Function(AssignExpression) onAssign,
    T Function(IfExpression) onIf,
    T Function(LoopExpression) onLoop,
    T Function() onBreak,
    T Function(Group) onGroup,
    T Function(CompilerError) onError,
  });

  CompilerError findError() {
    return matchExpr(
        onConst: (_) => null,
        onVariable: (_) => null,
        onFunCall: (_) => null,
        onAssign: (_) => null,
        onIf: (_) => null,
        onLoop: (_) => null,
        onBreak: () => null,
        onGroup: (g) => g.body
            .map((e) => e.findError())
            .firstWhere((e) => e != null, orElse: () => null),
        onError: (e) => e);
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
    T Function(AssignExpression) onAssign,
    T Function(IfExpression) onIf,
    T Function(LoopExpression) onLoop,
    T Function() onBreak,
    T Function(Group) onGroup,
    T Function(CompilerError) onError,
  }) {
    return onConst(this);
  }
}

class Var extends Expression {
  final String name;
  final bool isGlobal;

  const Var(this.name, ValueType type, this.isGlobal)
      : super._create(name, type);

  @override
  String toString() => 'Var{name: $name, type: $type, global: $isGlobal}';

  @override
  T matchExpr<T>({
    T Function(Const) onConst,
    T Function(Var) onVariable,
    T Function(FunCall) onFunCall,
    T Function(AssignExpression) onAssign,
    T Function(IfExpression) onIf,
    T Function(LoopExpression) onLoop,
    T Function() onBreak,
    T Function(Group) onGroup,
    T Function(CompilerError) onError,
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
    T Function(AssignExpression) onAssign,
    T Function(IfExpression) onIf,
    T Function(LoopExpression) onLoop,
    T Function() onBreak,
    T Function(Group) onGroup,
    T Function(CompilerError) onError,
  }) {
    return onFunCall(this);
  }
}

class AssignExpression extends Expression {
  final VarDeclaration declaration;
  final AssignmentType assignmentType;

  String get id => _id;

  final Expression body;

  ValueType get varType => body.type;

  @override
  List<VarDeclaration> get declarations =>
      [if (assignmentType != AssignmentType.reassign) _toDeclaration()];

  AssignExpression(this.assignmentType, String id, this.body)
      : declaration = null,
        super._create(id, ValueType.empty);

  AssignExpression.withDeclaration(
      this.assignmentType, VarDeclaration declaration, this.body)
      : declaration = declaration,
        super._create(declaration.id, ValueType.empty);

  VarDeclaration _toDeclaration() {
    if (assignmentType == AssignmentType.reassign) return null;
    if (declaration != null) return declaration;
    return VarDeclaration(id, varType,
        isMutable: assignmentType == AssignmentType.mut);
  }

  @override
  String toString() => '($assignmentType $_id = $body)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is AssignExpression &&
          assignmentType == other.assignmentType &&
          body == other.body;

  @override
  int get hashCode => super.hashCode ^ body.hashCode;

  @override
  T matchExpr<T>({
    T Function(Const) onConst,
    T Function(Var) onVariable,
    T Function(FunCall) onFunCall,
    T Function(AssignExpression) onAssign,
    T Function(IfExpression) onIf,
    T Function(LoopExpression) onLoop,
    T Function() onBreak,
    T Function(Group) onGroup,
    T Function(CompilerError) onError,
  }) {
    return onAssign(this);
  }
}

class IfExpression extends Expression {
  final Expression cond;
  final Expression then;
  final Expression els;

  // TODO each assignment needs a unique identifier outside its scope
  @override
  List<VarDeclaration> get declarations => [
        ...cond.declarations,
        ...then.declarations,
        ...(els?.declarations ?? const [])
      ];

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
    T Function(AssignExpression) onAssign,
    T Function(IfExpression) onIf,
    T Function(LoopExpression) onLoop,
    T Function() onBreak,
    T Function(Group) onGroup,
    T Function(CompilerError) onError,
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
    T Function(AssignExpression) onAssign,
    T Function(IfExpression) onIf,
    T Function(LoopExpression) onLoop,
    T Function() onBreak,
    T Function(Group) onGroup,
    T Function(CompilerError) onError,
  }) {
    return onBreak();
  }
}

class Group extends Expression {
  final List<Expression> body;

  @override
  List<VarDeclaration> get declarations =>
      body.expand((g) => g.declarations).toList();

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
    T Function(AssignExpression) onAssign,
    T Function(IfExpression) onIf,
    T Function(LoopExpression) onLoop,
    T Function() onBreak,
    T Function(Group) onGroup,
    T Function(CompilerError) onError,
  }) {
    return onGroup(this);
  }
}

class LoopExpression extends Expression {
  final Expression body;

  @override
  List<VarDeclaration> get declarations => body.declarations;

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
    T Function(AssignExpression) onAssign,
    T Function(IfExpression) onIf,
    T Function(LoopExpression) onLoop,
    T Function() onBreak,
    T Function(Group) onGroup,
    T Function(CompilerError) onError,
  }) {
    return onLoop(this);
  }
}

class CompilerError extends Expression {
  final ParserPosition position;
  final String message;

  const CompilerError(this.position, this.message)
      : super._create('compiler-error', ValueType.empty);

  @override
  String toString() {
    return 'CompilerError{position: $position, message: $message}';
  }

  @override
  T matchExpr<T>({
    T Function(Const) onConst,
    T Function(Var) onVariable,
    T Function(FunCall) onFunCall,
    T Function(AssignExpression) onAssign,
    T Function(IfExpression) onIf,
    T Function(LoopExpression) onLoop,
    T Function() onBreak,
    T Function(Group) onGroup,
    T Function(CompilerError) onError,
  }) {
    return onError(this);
  }
}
