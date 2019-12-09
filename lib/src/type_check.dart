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

Expression exprWithInferredType(ParsedGroup group, TypeContext context) {
  if (group.length == 1) {
    // groups of length 1 must be either a constant or a variable
    return group.match(
        onMember: (member) {
          final funType = context.typeOfFun(member, const []);
          if (funType != null) {
            return Expression.variable(member, funType.returns);
          }
          return Expression.constant(member, inferValueType(member, context));
        },
        onGroup: (gr) => exprWithInferredType(gr[0], context));
  }
  if (group.length > 1) {
    // groups of length > 1 must be a function call
    return group.match(onGroup: (members) {
      final opGroup = members[0];
      String op = opGroup.match(
        onGroup: (_) =>
            throw Exception('Expression must start with function or operator'),
        onMember: (member) => member,
      );
      if (operators.contains(op) && members.length != 3) {
        throw TypeCheckException("Operator '$op' expects 2 arguments, "
            "but was given ${members.length - 1}");
      }
      final exprArgs =
          members.skip(1).map((arg) => exprWithInferredType(arg, context));
      final type = context.typeOfFun(op, exprArgs);
      if (type == null) throw TypeCheckException("unknown function: '$op'");
      return Expression.funCall(
          op, exprArgs.toList(growable: false), type.returns);
    });
  }

  throw Exception('Empty expression');
}

ValueType inferValueType(String value, TypeContext context) {
  int i = int.tryParse(value);
  if (i != null) return ValueType.i64;
  double d = double.tryParse(value);
  if (d != null) return ValueType.f64;
  throw TypeCheckException("unknown variable: '$value'");
}
