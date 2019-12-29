import 'expression.dart';
import 'type.dart';

/// Top-level node in a Wasmin program.
mixin WasminNode {
  T matchNode<T>({
    T Function(Implementation) onImpl,
    T Function(Declaration) onDeclaration,
  });
}

/// Top-level Wasmin program implementation unit.
abstract class Implementation with WasminNode {
  const Implementation._();

  T match<T>({
    T Function(Let) onLet,
    T Function(Fun) onFun,
  });

  @override
  T matchNode<T>({
    T Function(Implementation) onImpl,
    T Function(Declaration) onDeclaration,
  }) {
    return onImpl(this);
  }
}

/// Wasmin program declaration unit.
abstract class Declaration with WasminNode {
  final bool isExported;

  const Declaration._(this.isExported);

  T match<T>({
    T Function(FunDeclaration) onFun,
    T Function(VarDeclaration) onVar,
  });

  @override
  T matchNode<T>({
    T Function(Implementation) onImpl,
    T Function(Declaration) onDeclaration,
  }) {
    return onDeclaration(this);
  }
}

/// Top-level Let expression.
class Let extends Implementation {
  final Expression body;
  final VarDeclaration declaration;

  const Let(this.declaration, this.body) : super._();

  ValueType get type => body.type;

  String get id => declaration.id;

  @override
  String toString() => 'Let{${declaration} $body}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Let &&
          runtimeType == other.runtimeType &&
          declaration == other.declaration &&
          body == other.body;

  @override
  int get hashCode => declaration.hashCode ^ body.hashCode;

  @override
  T match<T>({T Function(Let) onLet, T Function(Fun) onFun}) {
    return onLet(this);
  }
}

/// Fun represents a function implementation.
class Fun extends Implementation {
  final FunDeclaration declaration;
  final List<String> args;
  final Expression body;

  Fun(this.declaration, this.args, this.body) : super._();

  @override
  String toString() => 'Fun{id=${declaration.id}, args=$args, body=$body}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Fun &&
          runtimeType == other.runtimeType &&
          declaration == other.declaration &&
          body == other.body;

  @override
  int get hashCode => declaration.hashCode ^ body.hashCode;

  @override
  T match<T>({T Function(Let) onLet, T Function(Fun) onFun}) {
    return onFun(this);
  }
}

class FunDeclaration extends Declaration {
  final FunType type;
  final String id;

  FunDeclaration(this.id, this.type, [bool isExported = false])
      : super._(isExported);

  FunDeclaration asExported() {
    return isExported ? this : FunDeclaration(id, type, true);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FunDeclaration &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          id == other.id &&
          isExported == other.isExported;

  @override
  int get hashCode => type.hashCode ^ id.hashCode ^ isExported.hashCode;

  @override
  String toString() {
    return 'FunDeclaration{type: $type, id: $id, isExported: $isExported}';
  }

  @override
  T match<T>(
      {T Function(FunDeclaration) onFun, T Function(VarDeclaration) onVar}) {
    return onFun(this);
  }
}

enum AssignmentType { let, mut, reassign }

class VarDeclaration extends Declaration {
  final String id;
  final ValueType varType;
  final bool isMutable;

  VarDeclaration(this.id, this.varType,
      {this.isMutable = false, bool isExported = false})
      : super._(isExported);

  VarDeclaration asExported() {
    return isExported
        ? this
        : VarDeclaration(id, varType, isMutable: isMutable, isExported: true);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VarDeclaration &&
          runtimeType == other.runtimeType &&
          varType == other.varType &&
          id == other.id &&
          isMutable == other.isMutable &&
          isExported == other.isExported;

  @override
  int get hashCode =>
      id.hashCode ^ varType.hashCode ^ isMutable.hashCode ^ isExported.hashCode;

  @override
  String toString() {
    return 'VarDeclaration{'
        'type: $varType, name: $id, isExported: $isExported}';
  }

  @override
  T match<T>(
      {T Function(FunDeclaration) onFun, T Function(VarDeclaration) onVar}) {
    return onVar(this);
  }
}
