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
      onGroup: (members) {
        // there may be any number of assignments before the result expression starts
        final assignments = members
            .takeWhile((m) => m.isAssignment)
            .map((m) => m.match(
                  onAssignment: (k, id, v) =>
                      _assignmentExpression(k, id, v, context),
                  onIf: (c, t, [e]) => _ifExpression(c, t, e, context),
                ))
            .toList(growable: false);

        if (assignments.isNotEmpty) {
          final result =
              _resultExpression(members.skip(assignments.length), context);
          return Expression.group([...assignments, result]);
        }
        return _resultExpression(members, context);
      });
}

Expression _singleMemberExpression(String member, ParsingContext context) {
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
    final value = exprWithInferredType(body, context.createChild());
    context.add(LetDeclaration(id, value.type));
    return LetExpression(id, value);
  } else {
    throw Exception("Unsupported keyword for assignment: '$keyword'");
  }
}

Expression _resultExpression(
    Iterable<ParsedExpression> members, ParsingContext context) {
  if (members.isEmpty) {
    throw Exception('Empty expression cannot be used as a value');
  }
  if (members.length == 1) {
    // groups of length 1 must be a constant, a no-args fun call or a variable
    return members.first.match(
      onGroup: (group) => _resultExpression(group, context),
      onAssignment: (k, i, v) =>
          throw Exception('Assignment not allowed at this position'),
      onMember: (m) => _singleMemberExpression(m, context),
      onIf: (cond, then, [els]) => _ifExpression(cond, then, els, context),
      onErrors: (errors) => throw Exception(errors.join('\n')),
    );
  }

  // expressions with more than one member must be function calls
  final funName = members.first.match(
    onGroup: (group) => throw Exception(
        'Expected function identifier, found expression instead: $group'),
    onAssignment: (k, i, v) => throw Exception(
        'Expected function identifier, found assignment instead: $i'),
    onMember: (member) => member,
    onIf: (cond, then, [els]) => throw Exception(
        'Expected function identifier, founct if expression instead'),
    onErrors: (errors) => throw Exception(errors.join('\n')),
  );

  final args = members.skip(1).map((e) => exprWithInferredType(e, context));

  // TODO support more operators
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
