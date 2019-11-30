import 'ast.dart';

const operators = {'+', '-', '*', '/'};

Expression exprWithInferredType(String op, List<String> args) {
  if (args.isEmpty) {
    // must be literal or local
    final valueType = inferValueType(op);
    if (valueType != null) return Expression(op, args, valueType);
    throw 'Cannot type literal or local: $op';
  } else {
    if (operators.contains(op)) {
      // take type of first argument
      final valueType = inferValueType(args[0]);
      if (valueType != null) return Expression(op, args, valueType);
    }
  }
  throw 'Cannot type complex expression: $op $args';
}

ValueType inferValueType(String value) {
  int i = int.tryParse(value);
  if (i != null) return ValueType.i64;
  double d = double.tryParse(value);
  if (d != null) return ValueType.f64;
  return null;
}
