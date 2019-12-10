import 'package:collection/collection.dart';

import 'expression.dart';
import 'type.dart';

/// Top-level Wasmin program implementation unit.
abstract class Implementation {
  const Implementation._();

  T match<T>({T Function(Let) onLet, T Function(Fun) onFun}) {
    if (this is Let) {
      return onLet(this as Let);
    }
    if (this is Fun) {
      return onFun(this as Fun);
    }
    throw 'unreachable';
  }
}

/// Wasmin program declaration unit.
abstract class Declaration {
  final bool isExported;

  const Declaration._(this.isExported);

  T match<T>(
      {T Function(FunDeclaration) onFun, T Function(LetDeclaration) onLet}) {
    if (this is LetDeclaration) {
      return onLet(this as LetDeclaration);
    }
    if (this is FunDeclaration) {
      return onFun(this as FunDeclaration);
    }
    throw 'unreachable';
  }
}

/// The no-op node can be used when a source code construct
/// performs no operation (e.g. whitespace).
class Noop extends Implementation {
  const Noop() : super._();
}

/// Top-level Let expression.
class Let extends Implementation {
  final Expression body;
  final LetDeclaration declaration;

  const Let(this.declaration, this.body) : super._();

  ValueType get type => body.type;

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

}

/// Fun represents a function implementation.
class Fun extends Implementation {
  final List<Expression> body;
  final FunDeclaration declaration;

  static List<Expression> _nonEmpty(List<Expression> body) {
    if (body.isEmpty) {
      throw ArgumentError.value(
          body, 'body', 'Function body must not be empty');
    }
    return body;
  }

  Fun(this.declaration, List<Expression> body)
      : this.body = _nonEmpty(body),
        super._();

  @override
  String toString() => '(Fun ${declaration.id} (${body.join(' ')}))';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Fun &&
          runtimeType == other.runtimeType &&
          declaration == other.declaration &&
          const ListEquality<Expression>().equals(this.body, other.body);

  @override
  int get hashCode => declaration.hashCode ^ body.hashCode;
}

class FunDeclaration extends Declaration {
  final FunType type;
  final String id;

  const FunDeclaration(this.type, this.id, [bool isExported = false])
      : super._(isExported);

  FunDeclaration.variable(ValueType type, String id)
      : this(FunType(type, const []), id, false);

  FunDeclaration asExported() {
    return isExported ? this : FunDeclaration(type, id, true);
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
}
