import 'package:decimal/decimal.dart';

import 'ast.dart';
import 'expression.dart';
import 'type.dart';
import 'type_context.dart';

class TypeCheckException implements Exception {
  final String message;

  const TypeCheckException(this.message);

  @override
  String toString() => 'type checking failed: $message';
}

Expression singleMemberExpression(String member, ParsingContext context) {
  if (member == 'break') return Expression.breakExpr();
  final funTypes = context.typeOfFun(member, 0);
  if (funTypes.isNotEmpty) {
    return Expression.funCall(member, const [], funTypes.first.returns);
  }
  final decl = context.declarationOf(member);
  if (decl != null) {
    return decl.match(onVar: (let) {
      return Expression.variable(member, let.varType, let.isGlobal);
    }, onFun: (fun) {
      if (fun.type.takes.isEmpty) {
        return Expression.funCall(member, const [], fun.type.returns);
      } else {
        throw TypeCheckException(
            "function '${member}' expects arguments of types ${fun.type.takes},"
            ' but was called without any arguments');
      }
    });
  }
  return Expression.constant(member, inferValueType(member));
}

Expression assignmentExpression(AssignmentType assignmentType, String id,
    Expression value, ParsingContext context) {
  var decl = context.declarationOf(id);
  var declaredExplicitly = false;
  VarDeclaration varDeclaration;
  if (decl != null) {
    varDeclaration = decl.match(
        onFun: (_) => throw TypeCheckException(
            "'$id' is declared as a function, but implemented as "
            'a ${assignmentType}'),
        onVar: (v) => v);
    declaredExplicitly = true;
    value = _verifyType(varDeclaration, value);
  } else {
    varDeclaration = VarDeclaration(id, value.type,
        isMutable: assignmentType == AssignmentType.mut, isGlobal: true);
    context.add(varDeclaration);
  }

  switch (assignmentType) {
    case AssignmentType.let:
      return Expression.letWithDeclaration(varDeclaration, value);
    case AssignmentType.mut:
      return Expression.mut(id, value);
    case AssignmentType.reassign:
    default:
      if (declaredExplicitly) {
        return varDeclaration.match(onFun: (fun) {
          throw TypeCheckException("existing function '$id'"
              "cannot be re-assigned value with type '${value.type.name}'");
        }, onVar: (v) {
          if (!v.isMutable) {
            throw TypeCheckException(
                "immutable variable '$id' cannot be re-assigned");
          } else if (v.varType == value.type) {
            return Expression.reassign(id, value);
          } else {
            throw TypeCheckException(
                "variable '$id' of type '${v.varType.name}' "
                "cannot be assigned value with type '${value.type.name}'");
          }
        });
      } else {
        throw TypeCheckException(
            "unknown variable '$id' cannot be re-assigned");
      }
  }
}

Expression funCall(String id, List<Expression> args, ParsingContext context) {
  final types = context.typeOfFun(id, args.length);
  return _matchFunCallWithArgs(id, args, types);
}

Expression _matchFunCallWithArgs(
    String funName, List<Expression> args, Set<FunType> types) {
  assert(types.every((type) => type.takes.length == args.length));
  for (final type in types) {
    final takes = type.takes;
    var index = 0;
    final fixedArgs = args.map((actualArg) {
      final expected = takes[index++];
      if (expected != actualArg.type) {
        return tryConvertType(actualArg, expected);
      }
      return actualArg;
    }).toList(growable: false);

    if (fixedArgs.every((arg) => arg != null)) {
      return Expression.funCall(funName, fixedArgs, type.returns);
    }
  }

  // none of the function types match
  throw TypeCheckException("Cannot call function '$funName' with arguments"
      ' of types ${_typeNames(args.map((a) => a.type))}. '
      'The following types would be acceptable:\n'
      '${types.map((f) => _typeNames(f.takes)).join('\n  * ')}');
}

Expression ifExpression(
    ParsingContext context, Expression cond, Expression then,
    [Expression els]) {
  if (els != null) {
    if (then.type != els.type) {
      // try to convert the type of either branch so they match
      final fixedThen = tryConvertType(then, els.type);
      if (fixedThen == null) {
        final fixedElse = tryConvertType(els, then.type);
        if (fixedElse == null) {
          throw TypeCheckException('if branches have different types '
              '(then: ${then.type.name}, else: ${els.type.name})');
        } else {
          els = fixedElse;
        }
      } else {
        then = fixedThen;
      }
    }
  }
  return Expression.ifExpr(cond, then, els);
}

Expression _verifyType(VarDeclaration decl, Expression body) {
  if (decl.varType != body.type) {
    final convertedExpr = tryConvertType(body, decl.varType);
    if (convertedExpr != null) return convertedExpr;
    throw TypeCheckException(
        "'${decl.id}' type should be '${decl.varType.name}', but its "
        "implementation has type '${body.type.name}'");
  }
  return body;
}

ValueType inferValueType(String value) {
  final i = BigInt.tryParse(value);
  if (i != null) {
    if (i.bitLength > 64) {
      throw TypeCheckException(
          'Integer literal \'$value\' too big, requires ${i.bitLength} bits '
          'for storage, but WASM limits integer types to 64 bits');
    }
    if (i.bitLength <= 32) return ValueType.i32;
    return ValueType.i64;
  }
  final d = Decimal.tryParse(value);
  if (d != null) {
    return ValueType.f32;
  }
  throw TypeCheckException("unknown variable: '$value'");
}

Expression tryConvertType(Expression expr, ValueType type) {
  if (expr is Const) {
    if (type == ValueType.f64) {
      if (expr.type == ValueType.f32) {
        return Expression.constant(expr.value, type);
      }
    } else if (type == ValueType.i64) {
      if (expr.type == ValueType.i32) {
        return Expression.constant(expr.value, type);
      }
    }
  }
  return null;
}

String _typeNames(Iterable<ValueType> types) {
  return '[${types.map((type) => type.name).join(', ')}]';
}
