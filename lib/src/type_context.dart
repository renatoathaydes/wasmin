import 'ast.dart';
import 'type_check.dart';

mixin TypeContext {
  FunctionType typeOfFun(String funName, Iterable<Expression> args);
}

mixin MutableTypeContext implements TypeContext {
  void addFun(String name, FunctionType type);
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
}

class ParsingContext extends WasmDefaultTypeContext with MutableTypeContext {
  final _declaredFunctions = <String, FunctionType>{};

  @override
  FunctionType typeOfFun(String funName, Iterable<Expression> args) {
    return super.typeOfFun(funName, args) ?? _declaredFunctions[funName];
  }

  @override
  void addFun(String name, FunctionType type) {
    _declaredFunctions[name] = type;
  }
}
