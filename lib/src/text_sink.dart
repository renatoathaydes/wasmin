import 'package:wasmin/src/parse/parse.dart';

import 'ast.dart';
import 'expression.dart';
import 'type_check.dart';

class WasmTextSink {
  final StringSink _textSink;

  WasmTextSink(this._textSink);

  Future<void> call(Future<WasminUnit> programUnit) async {
    final unit = await programUnit;
    // write declarations first to the top of the file
    for (final declaration in unit.declarations) {
      declaration.match(onFun: _funDeclaration, onLet: _letDeclaration);
    }

    // write all the implementation
    for (final impl in unit.implementations) {
      impl.match(onFun: _fun, onLet: _topLevelLet);
    }
  }

  /// Debug method to write any node without validating anything.
  void add(Object node) {
    if (node is Expression) {
      return _writeExpression(node);
    }
    throw 'Cannot write $node';
  }

  void _funDeclaration(FunDeclaration fun) {
    throw 'TODO: funDeclaration';
    //_textSink.writeln('(local \$${fun.id} ${fun.type.name})');
  }

  void _letDeclaration(LetDeclaration let) {
    throw 'TODO: letDeclaration';
  }

  void _fun(Fun fun) {
    throw 'TODO: fun implementation';
  }

  void _topLevelLet(Let let) {
    throw 'TODO: top-level Let';
  }

  void _writeExpression(Expression expr) {
    expr.matchExpr(
      onConst: _const,
      onVariable: _variable,
      onFunCall: _funCall,
      onLet: _let,
      onGroup: _group,
    );
  }

  void _const(Const constant) {
    _textSink.write('(${constant.type.name}.const ${constant.value})');
  }

  void _variable(Var variable) {
    _textSink.write('(local.get \$${variable.name})');
  }

  void _funCall(FunCall funCall) {
    final prefix =
        operators.contains(funCall.name) ? '${funCall.type.name}.' : r'call $';
    _textSink.write('($prefix${funCall.name} ');
    var index = 0;
    for (final arg in funCall.args) {
      _writeExpression(arg);
      index++;
      if (index < funCall.args.length) _textSink.write(' ');
    }
    _textSink.writeln(')');
  }

  void _let(LetExpression let) {
    // FIXME declaration must occur at beginning of function
    //_textSink.writeln('(local \$${let.id} ${let.body.type.name})');
    _textSink.write('(local.set \$${let.id} ');
    _writeExpression(let.body);
    _textSink.writeln(')');
  }

  void _group(Group group) {
    // TODO
  }
}
