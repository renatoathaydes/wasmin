import 'package:wasmin/src/compile.dart';
import 'package:wasmin/wasmin.dart';

void main() async {
  // compile Wasmin to WASM
  await compile('example.wasmin', 'output.wasm');

  // compile Wasmin to WAT
  await compile('example.wasmin', 'output.wat', TargetFormat.wat);

  // compile only to the AST, then print the AST to stdout
  final astNodes = compileWasmin(
    'input-source-name',
    ['let x = 10;', 'let y = 20;'],
  );

  await astNodes.forEach((node) => print(node));
}
