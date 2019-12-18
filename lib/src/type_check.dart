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
          throw Exception('Empty expression cannot be used as a value');
        }

        // the first single-member in a group may be a function call
        // or loop/break
        final intermediateExpressions =
            members.takeWhile((m) => !m.isSingleMember).toList();
        var resultExpressionParts =
            members.skip(intermediateExpressions.length).toList();

        if (intermediateExpressions.isEmpty) {
          return _resultExpression(resultExpressionParts, context);
        }
        if (resultExpressionParts.isEmpty) {
          if (intermediateExpressions.length == 1) {
            return _resultExpression(intermediateExpressions, context);
          } else {
            resultExpressionParts = [intermediateExpressions.removeLast()];
          }
        }

        return Expression.group([
          ...intermediateExpressions
              .map((e) => _intermediateExpression(e, context)),
          _resultExpression(resultExpressionParts, context)
        ]);
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
      ?.match(onLet: (let) => let.varType, onFun: (fun) => null);
  if (varType != null) return Expression.variable(member, varType);
  return Expression.constant(member, inferValueType(member));
}

Expression _assignmentExpression(
    String keyword, String id, ParsedExpression body, ParsingContext context) {
  if (keyword == 'let') {
    final value = exprWithInferredType(body, context);
    context.add(LetDeclaration(id, value.type));
    return LetExpression(id, value);
  } else {
    throw Exception("Unsupported keyword for assignment: '$keyword'");
  }
}

Expression _loopExpression(ParsedExpression body, ParsingContext context) {
  return LoopExpression(exprWithInferredType(body, context.createChild()));
}

Expression _intermediateExpression(
    ParsedExpression member, ParsingContext context) {
  return member.match(
    onGroup: (g) => g.length == 1
        ? exprWithInferredType(g[0], context)
        : Expression.group(g.map((m) => exprWithInferredType(m, context))),
    onLoop: (loop) => _loopExpression(loop, context),
    onMember: (m) => _singleMemberExpression(m, context),
    onIf: (cond, then, [els]) => _ifExpression(cond, then, els, context),
    onAssignment: (keyword, id, body) =>
        _assignmentExpression(keyword, id, body, context),
    onErrors: (errors) => throw Exception(errors.join('\n')),
  );
}

Expression _resultExpression(
    Iterable<ParsedExpression> members, ParsingContext context) {
  if (members.isEmpty) {
    throw Exception('Empty expression cannot be used as a value');
  }
  if (members.length == 1) {
    return members.first.match(
      onGroup: (g) => _resultExpression(g, context),
      onLoop: (loop) => throw Exception('loop cannot be used as a value'),
      onAssignment: (k, i, v) =>
          throw Exception('assignment cannot be used as a value'),
      onMember: (m) => _singleMemberExpression(m, context),
      // TODO verify that this is a non-empty value if expression
      onIf: (cond, then, [els]) => _ifExpression(cond, then, els, context),
      onErrors: (errors) => throw Exception(errors.join('\n')),
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
    onErrors: (errors) => throw Exception(errors.join('\n')),
  );

  final args = members.skip(1).map((e) => exprWithInferredType(e, context));

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
