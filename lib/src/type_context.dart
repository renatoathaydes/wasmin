import 'package:collection/collection.dart';

import 'ast.dart';
import 'type_check.dart';

mixin TypeContext {
  FunctionType typeOfFun(String funName, Iterable<Expression> args);

  FunDeclaration declarationOf(String funName);
}

mixin MutableTypeContext implements TypeContext {
  void addFun(FunDeclaration funDeclaration);
}

class WasmDefaultTypeContext with TypeContext {
  const WasmDefaultTypeContext();

  @override
  FunctionType typeOfFun(String funName, Iterable<Expression> args) {
    if (operators.contains(funName)) {
      final type = args.first.type;
      return FunctionType(type, [type, type]);
    }
    return null;
  }

  FunDeclaration declarationOf(String funName) {
    return null;
  }
}

class ParsingContext extends WasmDefaultTypeContext with MutableTypeContext {
  final _declaredFunctions = <String, FunDeclaration>{};

  @override
  FunctionType typeOfFun(String funName, Iterable<Expression> args) {
    var type = super.typeOfFun(funName, args);
    if (type !=null) return type;
    final decl = _declaredFunctions[funName];
    if (decl == null) return null;
    if (const IterableEquality<ValueType>().equals(decl.type.takes, args.map((a)=>a.type))) {
      return decl.type;
    }
    return null;
  }

  @override
  FunDeclaration declarationOf(String funName) {
    return _declaredFunctions[funName];
  }

  @override
  void addFun(FunDeclaration funDeclaration) {
    _declaredFunctions[funDeclaration.id] = funDeclaration;
  }
}
