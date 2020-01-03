@TestOn('browser')
import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:wasm_interop/wasm_interop.dart';

void main() async {
  group('simple', () {
    test('exports constant', () async {
      final wasm = await http.get('simple.wasmin.wasm');
      final instance = await Instance.fromBytesAsync(wasm.bodyBytes);
      expect(instance.globals['large_number'].rawValue, equals(43));
    });

    test('exports function', () async {
      final wasm = await http.get('simple.wasmin.wasm');
      final instance = await Instance.fromBytesAsync(wasm.bodyBytes);
      expect(instance.functions['add-number'](32), equals(42));
    });
  });
}

extension on Object {
  dynamic get rawValue {
    if (this is Global) {
      return (this as Global).value;
    }
    return this;
  }
}
