import 'package:wasmin/wasmin.dart';

import 'expression.dart';
import 'type.dart';

/// Top-level node in a Wasmin program.
mixin WasminNode {
  T matchNode<T>({
    T Function(Implementation) onImpl,
    T Function(Declaration) onDeclaration,
    T Function(WasminError) onError,
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
    T Function(WasminError) onError,
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
    T Function(LetDeclaration) onLet,
  });

  @override
  T matchNode<T>({
    T Function(Implementation) onImpl,
    T Function(Declaration) onDeclaration,
    T Function(WasminError) onError,
  }) {
    return onDeclaration(this);
  }
}

/// An instance of this type is emitted when a Wasmin program is found to
/// contain errors.
class WasminError with WasminNode {
  final List<String> errors;

  const WasminError(this.errors);

  @override
  T matchNode<T>({
    T Function(Implementation) onImpl,
    T Function(Declaration) onDeclaration,
    T Function(WasminError) onError,
  }) {
    return onError(this);
  }
}

/// Top-level Let expression.
class Let extends Implementation {
  final Expression body;
  final LetDeclaration declaration;

  const Let(this.declaration, this.body) : super._();

  ValueType get type => body.type;

  String get id => declaration.name;

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
  final Expression body;
  final FunDeclaration declaration;

  Fun(this.declaration, this.body) : super._();

  @override
  String toString() => 'Fun{id=${declaration.id}, body=$body}';

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

  const FunDeclaration(this.id, this.type, [bool isExported = false])
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
      {T Function(FunDeclaration) onFun, T Function(LetDeclaration) onLet}) {
    return onFun(this);
  }
}

class LetDeclaration extends Declaration {
  final String name;
  final ValueType type;

  const LetDeclaration(this.name, this.type, [bool isExported = false])
      : super._(isExported);

  LetDeclaration asExported() {
    return isExported ? this : LetDeclaration(name, type, true);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LetDeclaration &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          name == other.name &&
          isExported == other.isExported;

  @override
  int get hashCode => name.hashCode ^ type.hashCode ^ isExported.hashCode;

  @override
  String toString() {
    return 'LetDeclaration{type: $type, name: $name, isExported: $isExported}';
  }

  @override
  T match<T>(
      {T Function(FunDeclaration) onFun, T Function(LetDeclaration) onLet}) {
    return onLet(this);
  }
}
