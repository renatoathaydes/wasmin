import 'package:decimal/decimal.dart';

import 'ast.dart';
import 'expression.dart';
import 'parse/expression.dart';
import 'type.dart';
import 'type_context.dart';

const operators = {
  'add', 'sub', 'mul', 'div_s', 'div_u', 'rem_s', 'rem_u', //
  'and', 'or', 'xor', 'shl', 'shr_u', 'shr_s', 'rot_l', 'rot_r', 'eq', 'ne', //
  'lt_s', 'lt_u', 'le_s', 'le_u', 'gt_s', 'gt_u', 'ge_s', 'gs_u', 'clz', //
  'ct_z', 'popcnt', 'eqz', //
  'convert_i32_u', 'convert_i64_u', 'convert_f32_u', 'convert_f64_u', //
  'convert_i32_s', 'convert_i64_s', 'convert_f32_s', 'convert_f64_s', //
};

class TypeCheckException implements Exception {
  final String message;

  const TypeCheckException(this.message);

  @override
  String toString() => 'type checking failed: $message';
}

Expression exprWithInferredType(
    ParsedExpression parsedExpr, ParsingContext context) {
  return parsedExpr.match(
      onError: (error) => error,
      onAssignment: (keyword, id, value) =>
          _assignmentExpression(keyword, id, value, context),
      onMember: (member) => _singleMemberExpression(member, context),
      onIf: (cond, then, [els]) => _ifExpression(cond, then, els, context),
      onLoop: (loop) => _loopExpression(loop, context),
      onGroup: (members) {
        if (members.isEmpty) {
          return _resultExpression(members, context);
        }
        final evalTermIndex = members.indexWhere((e) => e.isSingleMember);
        if (evalTermIndex < 0) {
          // there's no eval term in the group, evaluate each member individually
          return _group(members.map((e) => exprWithInferredType(e, context)));
        }

        // split the members into intermediate expressions and the trailing
        // evaluation term, which is the result of the expression
        final intermediateExpressions = members
            .sublist(0, evalTermIndex)
            .map((e) => exprWithInferredType(e, context))
            .toList(growable: false);
        final result =
            _resultExpression(members.sublist(evalTermIndex), context);
        return _group([...intermediateExpressions, result]);
      });
}

Expression _singleMemberExpression(String member, ParsingContext context) {
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

Expression _group(Iterable<Expression> expressions) {
  if (expressions.length == 1) return expressions.first;
  return Expression.group(expressions);
}

Expression _assignmentExpression(
    String keyword, String id, ParsedExpression body, ParsingContext context) {
  final value = exprWithInferredType(body, context);
  if (keyword == 'let') {
    context.add(VarDeclaration(id, value.type));
    return Expression.let(id, value);
  } else if (keyword == 'mut') {
    context.add(VarDeclaration(id, value.type, isMutable: true));
    return Expression.mut(id, value);
  } else if (keyword.isEmpty) {
    // this is a re-assignment
    final decl = context.declarationOf(id);
    if (decl != null) {
      return decl.match(onFun: (fun) {
        throw TypeCheckException("existing function '$id'"
            "cannot be re-assigned value with type '${value.type.name}'");
      }, onVar: (let) {
        if (!let.isMutable) {
          throw TypeCheckException(
              "immutable variable '$id' cannot be re-assigned");
        } else if (let.varType == value.type) {
          return Expression.reassign(id, value);
        } else {
          throw TypeCheckException(
              "variable '$id' of type '${let.varType.name}' "
              "cannot be assigned value with type '${value.type.name}'");
        }
      });
    } else {
      throw TypeCheckException("unknown variable '$id' cannot be re-assigned");
    }
  } else {
    throw TypeCheckException("Unsupported keyword for assignment: '$keyword'");
  }
}

Expression _loopExpression(ParsedExpression body, ParsingContext context) {
  return LoopExpression(exprWithInferredType(body, context.createChild()));
}

Expression _resultExpression(
    Iterable<ParsedExpression> members, ParsingContext context) {
  if (members.isEmpty) {
    return Expression.group(const []);
  }
  if (members.length == 1) {
    return members.first.match(
      onGroup: (g) => _resultExpression(g, context),
      onLoop: (loop) => _loopExpression(loop, context),
      onAssignment: (keyword, id, body) =>
          _assignmentExpression(keyword, id, body, context),
      onMember: (m) => _singleMemberExpression(m, context),
      onIf: (cond, then, [els]) => _ifExpression(cond, then, els, context),
      onError: (error) => error,
    );
  }

  // result expressions with more than one member must be function calls
  final funName = members.first.match(
    onGroup: (group) => throw Exception(
        'Expected function identifier, found expression instead: $group'),
    onLoop: (loop) => throw Exception(
        'Expected function identifier, found loop instead: $loop'),
    onAssignment: (k, i, v) => throw Exception(
        'Expected function identifier, found assignment instead: $i'),
    onMember: (member) => member,
    onIf: (cond, then, [els]) => throw Exception(
        'Expected function identifier, found if-expression instead'),
    onError: (error) => throw Exception(error.message),
  );

  final args = members
      .skip(1)
      .map((e) => exprWithInferredType(e, context))
      .toList(growable: false);

  // TODO support more operators, move these to the context
  if (operators.contains(funName) && args.length != 2) {
    throw TypeCheckException("Operator '$funName' expects 2 arguments, "
        'but was given ${args.length}');
  }
  final types = context.typeOfFun(funName, args.length);
  if (types.isEmpty) throw TypeCheckException("unknown function: '$funName'");
  return _matchFunCallWithArgs(funName, args, types);
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

IfExpression _ifExpression(ParsedExpression cond, ParsedExpression then,
    ParsedExpression els, ParsingContext context) {
  final condExpr = exprWithInferredType(cond, context);
  var thenExpr = exprWithInferredType(then, context.createChild());
  var elseExpr =
      els == null ? null : exprWithInferredType(els, context.createChild());
  if (elseExpr != null) {
    if (thenExpr.type != elseExpr.type) {
      // try to convert the type of either branch so they match
      final fixedThen = tryConvertType(thenExpr, elseExpr.type);
      if (fixedThen == null) {
        final fixedElse = tryConvertType(elseExpr, thenExpr.type);
        if (fixedElse == null) {
          throw TypeCheckException('if branches have different types '
              '(then: ${thenExpr.type.name}, else: ${elseExpr.type.name})');
        } else {
          elseExpr = fixedElse;
        }
      } else {
        thenExpr = fixedThen;
      }
    }
  }
  return IfExpression(condExpr, thenExpr, elseExpr);
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
