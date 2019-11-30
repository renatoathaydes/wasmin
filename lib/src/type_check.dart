import 'ast.dart';

Expression exprWithInferredType(String op, List<String> args) {
  if (args.isEmpty) {
    // must be literal or local
    int i = int.tryParse(op);
    if (i != null) return Expression(op, args, ValueType.i64);
    double d = double.tryParse(op);
    if (d != null) return Expression(op, args, ValueType.f64);
    throw 'Cannot type literal or local: $op';
  }
  throw 'Cannot type complex expression: $op $args';
}
