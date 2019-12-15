import 'package:wasmin/src/parse/parse.dart';
import 'package:wasmin/src/type.dart';

import 'ast.dart';
import 'expression.dart';
import 'type_check.dart';

class WasmTextSink {
  var _indent = '';
  final StringSink _textSink;

  WasmTextSink(this._textSink);

  Future<void> call(Future<WasminUnit> programUnit) async {
    final unit = await programUnit;
    // write declarations first to the top of the file
    for (final declaration in unit.declarations) {
      declaration.match(onFun: _funDeclaration, onLet: _assignment);
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
    if (node is Assignment) {
      return _assignment(node);
    }
    if (node is Fun) {
      return _fun(node);
    }
    throw 'Cannot write $node';
  }

  void _funDeclaration(FunDeclaration fun) {
    if (fun.isExported) {
      _textSink.writeln('$_indent(export "${fun.id}" (func \$${fun.id})');
    }
  }

  void _assignment(Assignment assignment) {
    _textSink.writeln(
        '$_indent(local \$${assignment.id} ${assignment.varType.name})');
  }

  void _fun(Fun fun) {
    final decl = fun.declaration;
    _textSink.write('$_indent(func \$${decl.id}');
    final argTypes = decl.type.takes;
    if (argTypes.length != fun.args.length) {
      throw Exception(
          'Invalid function instance: declaration has ${argTypes.length} types, '
          'but the implementation contains ${fun.args.length} parameters');
    }
    var i = 0;
    for (final param in fun.args) {
      final type = argTypes[i];
      _textSink.write(' (param \$${param} ${type.name})');
      i++;
    }
    if (decl.type.returns != ValueType.empty) {
      _textSink.write(' (result ${decl.type.returns.name})');
    }
    _textSink.writeln();
    _increaseIndent();
    _writeExpression(fun.body);
    _decreaseIndent();
    _textSink.write('\n)');
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
    _textSink.write('$_indent(${constant.type.name}.const ${constant.value})');
  }

  void _variable(Var variable) {
    _textSink.write('$_indent(local.get \$${variable.name})');
  }

  void _funCall(FunCall funCall) {
    final prefix =
        operators.contains(funCall.name) ? '${funCall.type.name}.' : r'call $';
    _textSink.write('$_indent($prefix${funCall.name}');
    if (funCall.args.isNotEmpty) {
      _textSink.writeln();
      _increaseIndent();
      for (final arg in funCall.args) {
        _writeExpression(arg);
        _textSink.writeln();
      }
      _decreaseIndent();
    }
    _textSink.writeln(')');
  }

  void _let(LetExpression let) {
    _textSink.write('$_indent(local.set \$${let.id} ');
    _writeExpression(let.body);
    _textSink.writeln(')');
  }

  void _group(Group group) {
    final newVarAssignments = group.body.whereType<LetExpression>();

    // first, write all new assignments declarations
    newVarAssignments.forEach(_assignment);

    // then, write the expressions themselves
    group.body.forEach(_writeExpression);
  }

  void _increaseIndent() {
    _indent = _indent + '  ';
  }

  void _decreaseIndent() {
    _indent = _indent.substring(0, _indent.length - 2);
  }
}
