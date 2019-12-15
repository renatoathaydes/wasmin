import 'package:collection/collection.dart';

import 'ast.dart';
import 'expression.dart';
import 'type.dart';
import 'type_check.dart';

mixin TypeContext {
  FunType typeOfFun(String funName, Iterable<Expression> args);

  Declaration declarationOf(String id);
}

mixin MutableTypeContext implements TypeContext {
  void add(Declaration declaration);
}

class WasmDefaultTypeContext with TypeContext {
  const WasmDefaultTypeContext();

  @override
  FunType typeOfFun(String funName, Iterable<Expression> args) {
    if (operators.contains(funName)) {
      final type = args.first.type;
      return FunType(type, [type, type]);
    }
    return null;
  }

  @override
  Declaration declarationOf(String id) => null;
}

class ParsingContext with MutableTypeContext {
  final _declarations = <String, Declaration>{};
  final TypeContext _parent;

  ParsingContext([this._parent = const WasmDefaultTypeContext()]);

  @override
  FunType typeOfFun(String funName, Iterable<Expression> args) {
    final decl = _declarations[funName];
    if (decl is FunDeclaration) {
      if (const IterableEquality<ValueType>()
          .equals(decl.type.takes, args.map((a) => a.type))) {
        return decl.type;
      }
    }
    return _parent.typeOfFun(funName, args);
  }

  @override
  Declaration declarationOf(String id) {
    return _declarations[id] ?? _parent.declarationOf(id);
  }

  @override
  void add(Declaration declaration) {
    _declarations[declaration.match(
        onLet: (let) => let.id, onFun: (fun) => fun.id)] = declaration;
  }

  ParsingContext createChild() => ParsingContext(this);
}
