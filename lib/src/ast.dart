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
  final String id;
  final bool isExported;

  const Declaration._(this.id, this.isExported);

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Declaration &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          isExported == other.isExported;

  @override
  int get hashCode => id.hashCode ^ isExported.hashCode;
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

  FunDeclaration(String id, this.type, [bool isExported = false])
      : super._(id, isExported);

  FunDeclaration asExported() {
    return isExported ? this : FunDeclaration(id, type, true);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other && other is FunDeclaration && type == other.type;

  @override
  int get hashCode => type.hashCode ^ super.hashCode;

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
  final ValueType varType;
  final bool isMutable;
  final bool isGlobal;

  VarDeclaration(String id, this.varType,
      {this.isMutable = false, bool isExported = false, this.isGlobal = false})
      : super._(id, isExported);

  VarDeclaration asExported() {
    return isExported
        ? this
        : VarDeclaration(id, varType, isMutable: isMutable, isExported: true);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is VarDeclaration &&
          varType == other.varType &&
          isGlobal == other.isGlobal &&
          isMutable == other.isMutable;

  @override
  int get hashCode =>
      super.hashCode ^
      varType.hashCode ^
      isMutable.hashCode ^
      isGlobal.hashCode;

  @override
  String toString() {
    return 'VarDeclaration{'
        'type: $varType, id: $id, isExported: $isExported, '
        'isMutable: $isMutable, isGlobal: $isGlobal}';
  }

  @override
  T match<T>(
      {T Function(FunDeclaration) onFun, T Function(VarDeclaration) onVar}) {
    return onVar(this);
  }
}
