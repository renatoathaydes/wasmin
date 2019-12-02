import 'package:test/test.dart';
import 'package:wasmin/wasmin.dart';

List<Expression> argsOfFunCall(Expression expression) {
  return expression.matchExpr(
      onConst: (_, type) => throw 'expression is a const',
      onVariable: (_, type) => throw 'expression is a variable',
      onFunCall: (_, args, type) => args);
}

enum _ExprKind { variable, constant }

Matcher isVariable = _IsExpr(_ExprKind.variable);
Matcher isConstant = _IsExpr(_ExprKind.constant);

class _IsExpr extends CustomMatcher {
  final _ExprKind kind;

  _IsExpr(this.kind)
      : super(
            "Expression of type $kind",
            'expression type',
            isA<Expression>().having(
                (e) => e.matchExpr(
                    onConst: (_, type) => kind == _ExprKind.constant,
                    onFunCall: (_, args, type) => false,
                    onVariable: (_, type) => kind == _ExprKind.variable),
                'is $kind',
                isTrue));
}
