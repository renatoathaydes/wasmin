import 'package:wasmin/src/ast.dart';

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
      onErrors: (errors) {
        // TODO emit error expressions
        throw Exception(errors.join('\n'));
      },
      onAssignment: (keyword, id, value) =>
          _assignmentExpression(keyword, id, value, context),
      onMember: (member) => _singleMemberExpression(member, context),
      onIf: (cond, then, [els]) => _ifExpression(cond, then, els, context),
      onLoop: (loop) => _loopExpression(loop, context),
      onGroup: (members) {
        if (members.isEmpty) {
          throw TypeCheckException(
              'Empty expression cannot be used as a value');
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
  final funType = context.typeOfFun(member, const []);
  if (funType != null) {
    return Expression.funCall(member, const [], funType.returns);
  }
  final varType = context
      .declarationOf(member)
      ?.match(onVar: (let) => let.varType, onFun: (fun) => null);
  if (varType != null) return Expression.variable(member, varType);
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
    throw TypeCheckException('Empty expression cannot be used as a value');
  }
  if (members.length == 1) {
    return members.first.match(
      onGroup: (g) => _resultExpression(g, context),
      onLoop: (loop) => _loopExpression(loop, context),
      onAssignment: (keyword, id, body) =>
          _assignmentExpression(keyword, id, body, context),
      onMember: (m) => _singleMemberExpression(m, context),
      onIf: (cond, then, [els]) => _ifExpression(cond, then, els, context),
      onErrors: (errors) => throw TypeCheckException(errors.join('\n')),
    );
  }

  // result expressions with more than one member must be function calls
  final funName = members.first.match(
    onGroup: (group) => throw TypeCheckException(
        'Expected function identifier, found expression instead: $group'),
    onLoop: (loop) => throw TypeCheckException(
        'Expected function identifier, found loop instead: $loop'),
    onAssignment: (k, i, v) => throw TypeCheckException(
        'Expected function identifier, found assignment instead: $i'),
    onMember: (member) => member,
    onIf: (cond, then, [els]) => throw TypeCheckException(
        'Expected function identifier, found if-expression instead'),
    onErrors: (errors) => throw TypeCheckException(errors.join('\n')),
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
  final type = context.typeOfFun(funName, args);
  if (type == null) throw TypeCheckException("unknown function: '$funName'");
  return Expression.funCall(
      funName, args.toList(growable: false), type.returns);
}

IfExpression _ifExpression(ParsedExpression cond, ParsedExpression then,
    ParsedExpression els, ParsingContext context) {
  final condExpr = exprWithInferredType(cond, context);
  final thenExpr = exprWithInferredType(then, context.createChild());
  final elseExpr =
      els == null ? null : exprWithInferredType(els, context.createChild());
  if (elseExpr != null) {
    if (thenExpr.type != elseExpr.type) {
      throw TypeCheckException('if branches have different types '
          '(then: ${thenExpr.type.name}, else: ${elseExpr.type.name})');
    }
  }
  return IfExpression(condExpr, thenExpr, elseExpr);
}

ValueType inferValueType(String value) {
  final i = int.tryParse(value);
  if (i != null) return ValueType.i64;
  final d = double.tryParse(value);
  if (d != null) return ValueType.f64;
  throw TypeCheckException("unknown variable: '$value'");
}
