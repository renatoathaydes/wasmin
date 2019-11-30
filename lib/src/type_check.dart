import 'ast.dart';

const operators = {
  'add', 'sub', 'mul', 'div_s', 'div_u', 'rem_s', 'rem_u', //
  'and', 'or', 'xor', 'shl', 'shr_u', 'shr_s', 'rot_l', 'rot_r', 'eq', 'ne', //
  'lt_s', 'lt_u', 'le_s', 'le_u', 'gt_s', 'gt_u', 'ge_s', 'gs_u', 'clz', //
  'ct_z', 'popcnt', 'eqz', //
};

class TypeCheckException implements Exception {
  final String message;

  const TypeCheckException(this.message);
}

Expression exprWithInferredType(String op, List<String> args) {
  if (args.isEmpty) {
    // must be literal or local variable
    // TODO handle local variable
    final valueType = inferValueType(op);
    if (valueType != null) return Expression.constant(op, valueType);
    throw 'Cannot type literal or local: $op';
  } else {
    if (operators.contains(op)) {
      return _operatorExpression(op, args);
    }
  }
  throw 'Cannot type complex expression: $op $args';
}

Expression _operatorExpression(String op, List<String> args) {
  // operators can only work on 2 arguments
  // TODO allow arguments to be grouped with brackets
  if (args.length != 2) {
    throw TypeCheckException(
        "Operator '$op' expects 2 arguments, but was given ${args.length}");
  }

  // take type of first argument
  final valueType = inferValueType(args[0]);
  if (valueType == null) throw 'Cannot type literal or local: ${args[0]}';

  final exprArgs = args
      .map((arg) => Expression.constant(arg, valueType))
      .toList(growable: false);

  return Expression(op, exprArgs, valueType);
}

ValueType inferValueType(String value) {
  int i = int.tryParse(value);
  if (i != null) return ValueType.i64;
  double d = double.tryParse(value);
  if (d != null) return ValueType.f64;
  return null;
}
