import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:jcs/jcs.dart';
import 'package:test/test.dart';

const encoder = JcsEncoder();

String enc(Object? value) => encoder.convert(value);

/// Builds the double with the given IEEE 754 bit pattern (16 hex digits).
double doubleFromHex(String hex) {
  final data = ByteData(8)
    ..setUint32(0, int.parse(hex.substring(0, 8), radix: 16))
    ..setUint32(4, int.parse(hex.substring(8), radix: 16));
  return data.getFloat64(0);
}

final throwsUnsupported = throwsA(isA<JsonUnsupportedObjectError>());
final throwsCyclic = throwsA(isA<JsonCyclicError>());

class _WithToJson {
  final int value;
  _WithToJson(this.value);

  Map<String, Object?> toJson() => {'value': value};
}

class _WithoutToJson {}

void main() {
  group('literals', () {
    test('null', () => expect(enc(null), 'null'));
    test('true', () => expect(enc(true), 'true'));
    test('false', () => expect(enc(false), 'false'));
  });

  group('numbers', () {
    // RFC 8785, Appendix B.
    const vectors = {
      '0000000000000000': '0',
      '8000000000000000': '0',
      '0000000000000001': '5e-324',
      '8000000000000001': '-5e-324',
      '7fefffffffffffff': '1.7976931348623157e+308',
      'ffefffffffffffff': '-1.7976931348623157e+308',
      '4340000000000000': '9007199254740992',
      'c340000000000000': '-9007199254740992',
      '4430000000000000': '295147905179352830000',
      '44b52d02c7e14af5': '9.999999999999997e+22',
      '44b52d02c7e14af6': '1e+23',
      '44b52d02c7e14af7': '1.0000000000000001e+23',
      '444b1ae4d6e2ef4e': '999999999999999700000',
      '444b1ae4d6e2ef4f': '999999999999999900000',
      '444b1ae4d6e2ef50': '1e+21',
      '3eb0c6f7a0b5ed8c': '9.999999999999997e-7',
      '3eb0c6f7a0b5ed8d': '0.000001',
      '41b3de4355555553': '333333333.3333332',
      '41b3de4355555554': '333333333.33333325',
      '41b3de4355555555': '333333333.3333333',
      '41b3de4355555556': '333333333.3333334',
      '41b3de4355555557': '333333333.33333343',
      'becbf647612f3696': '-0.0000033333333333333333',
      '43143ff3c1cb0959': '1424953923781206.2',
    };
    for (final MapEntry(key: hex, value: expected) in vectors.entries) {
      test('RFC 8785 Appendix B vector $hex', () {
        expect(enc(doubleFromHex(hex)), expected);
      });
    }

    test('integers', () {
      expect(enc(0), '0');
      expect(enc(1), '1');
      expect(enc(-1), '-1');
      expect(enc(10), '10');
      expect(enc(100), '100');
      expect(enc(1234567890), '1234567890');
      expect(enc(-1234567890), '-1234567890');
    });

    test('integers beyond 2^53 are converted to doubles', () {
      expect(enc(9007199254740993), '9007199254740992');
      expect(enc(9223372036854775807), '9223372036854776000');
      expect(enc(-9223372036854775808), '-9223372036854776000');
      expect(enc(123456789012345678), '123456789012345680');
    });

    test('integral doubles carry no fraction', () {
      expect(enc(1.0), '1');
      expect(enc(-1.0), '-1');
      expect(enc(100.0), '100');
      expect(enc(1e10), '10000000000');
    });

    test('negative zero is written as 0', () {
      expect(enc(-0.0), '0');
      expect(enc([-0.0]), '[0]');
    });

    test('fractions', () {
      expect(enc(0.5), '0.5');
      expect(enc(-0.5), '-0.5');
      expect(enc(1.5), '1.5');
      expect(enc(4.50), '4.5');
      expect(enc(0.1), '0.1');
      expect(enc(0.002), '0.002');
      expect(enc(123456.789), '123456.789');
      expect(enc(3.141592653589793), '3.141592653589793');
      expect(enc(1.0000000000000002), '1.0000000000000002');
    });

    test('fixed notation thresholds for small numbers', () {
      expect(enc(0.00001), '0.00001');
      expect(enc(1e-6), '0.000001');
      expect(enc(1.5e-6), '0.0000015');
      expect(enc(1e-7), '1e-7');
      expect(enc(1.5e-7), '1.5e-7');
      expect(enc(-1e-7), '-1e-7');
      expect(enc(1e-27), '1e-27');
    });

    test('fixed notation thresholds for large numbers', () {
      expect(enc(1e20), '100000000000000000000');
      expect(enc(1.5e20), '150000000000000000000');
      expect(enc(1e21), '1e+21');
      expect(enc(1.5e21), '1.5e+21');
      expect(enc(-1e21), '-1e+21');
      expect(enc(1e30), '1e+30');
      expect(enc(1e300), '1e+300');
      expect(enc(1.5e300), '1.5e+300');
    });

    test('extreme values', () {
      expect(enc(double.maxFinite), '1.7976931348623157e+308');
      expect(enc(-double.maxFinite), '-1.7976931348623157e+308');
      expect(enc(double.minPositive), '5e-324');
      expect(enc(-double.minPositive), '-5e-324');
    });

    test('shortest round-trip digits', () {
      expect(enc(333333333.33333329), '333333333.3333333');
      expect(enc(0.1 + 0.2), '0.30000000000000004');
    });

    test('non-finite numbers are rejected', () {
      expect(() => enc(double.nan), throwsUnsupported);
      expect(() => enc(double.infinity), throwsUnsupported);
      expect(() => enc(double.negativeInfinity), throwsUnsupported);
      expect(() => enc([1, double.nan]), throwsUnsupported);
      expect(() => enc({'a': double.infinity}), throwsUnsupported);
    });

    test('every finite double round-trips through the output', () {
      for (final value in [
        0.1,
        1 / 3,
        2 / 3,
        1e-5,
        123456789.123456789,
        5e-324,
        1.7976931348623157e+308,
        4.35,
        1e22,
        1e23,
        9.999999999999999e22,
      ]) {
        expect(double.parse(enc(value)), value, reason: '$value');
      }
    });
  });

  group('strings', () {
    test('empty string', () => expect(enc(''), '""'));

    test('plain ASCII is unchanged', () {
      expect(
        enc("abc XYZ 019 !#\$%&'()*+,-./:;<=>?@[]^_`{|}~"),
        "\"abc XYZ 019 !#\$%&'()*+,-./:;<=>?@[]^_`{|}~\"",
      );
    });

    test('quote and backslash are escaped', () {
      expect(enc('"'), r'"\""');
      expect(enc(r'\'), r'"\\"');
      expect(enc(r'a"b\c'), r'"a\"b\\c"');
      expect(enc(r'\\'), r'"\\\\"');
    });

    test('solidus is not escaped', () => expect(enc('a/b'), '"a/b"'));

    test('short escapes', () {
      expect(enc('\b'), r'"\b"');
      expect(enc('\t'), r'"\t"');
      expect(enc('\n'), r'"\n"');
      expect(enc('\f'), r'"\f"');
      expect(enc('\r'), r'"\r"');
    });

    test('all control characters are escaped with lowercase hex', () {
      const short = {
        0x08: r'\b',
        0x09: r'\t',
        0x0a: r'\n',
        0x0c: r'\f',
        0x0d: r'\r',
      };
      for (var c = 0; c < 0x20; c++) {
        final expected =
            short[c] ?? '\\u00${c.toRadixString(16).padLeft(2, '0')}';
        expect(enc(String.fromCharCode(c)), '"$expected"', reason: 'U+$c');
      }
      expect(enc('\u001f'), r'"\u001f"');
      expect(enc('\u000b'), r'"\u000b"');
      expect(enc('\u0000'), r'"\u0000"');
    });

    test('escapes are applied in the middle of text', () {
      expect(enc('a\nb\tc"d'), r'"a\nb\tc\"d"');
      expect(enc('\nabc'), r'"\nabc"');
      expect(enc('abc\n'), r'"abc\n"');
      expect(enc('\n\n'), r'"\n\n"');
    });

    test('DEL and characters above U+007F are written as-is', () {
      expect(enc('\u007f'), '"\u007f"');
      expect(enc('\u0080'), '"\u0080"');
      expect(enc('\u00e9'), '"\u00e9"');
      expect(enc('\u20ac'), '"\u20ac"');
      expect(enc('\u2028\u2029'), '"\u2028\u2029"');
      expect(enc('\ufffd'), '"\ufffd"');
      expect(enc('\uffff'), '"\uffff"');
    });

    test('characters outside the BMP are written as-is', () {
      expect(enc('\u{1f600}'), '"\u{1f600}"');
      expect(enc('a\u{1f600}\u{1f600}b'), '"a\u{1f600}\u{1f600}b"');
      expect(enc('\u{10000}\u{10ffff}'), '"\u{10000}\u{10ffff}"');
    });

    test('unicode is not normalized', () {
      expect(enc('e\u0301'), '"e\u0301"');
      expect(enc('\u00e9'), '"\u00e9"');
    });

    test('RFC 8785 section 3.2.2 string sample', () {
      const input = '\u20ac\$\u000f\u000aA\'\u0042\u0022\u005c\\"/';
      expect(enc(input), r'''"€$\u000f\nA'B\"\\\\\"/"''');
    });

    test('unpaired surrogates are rejected', () {
      for (final s in [
        '\ud800',
        '\udbff',
        '\udc00',
        '\udfff',
        'a\ud800b',
        'a\udc00b',
        '\udc00\ud800',
        '\ud800\ud800',
        '\udc00\udc00',
        '\ud800\ud800\udc00',
        '\ud800\udc00\udc00',
        'ok\u{1f600}\ud800',
      ]) {
        expect(() => enc(s), throwsUnsupported, reason: s.codeUnits.toString());
      }
    });

    test('unpaired surrogates are rejected in nested values', () {
      expect(() => enc(['\ud800']), throwsUnsupported);
      expect(() => enc({'a': '\udc00'}), throwsUnsupported);
      expect(
        () => enc({
          'a': [
            'x',
            {'b': '\ud800'},
          ],
        }),
        throwsUnsupported,
      );
    });

    test('unpaired surrogates are rejected in keys', () {
      expect(() => enc({'\ud800': 1}), throwsUnsupported);
      expect(() => enc({'\udc00': 1, 'a': 2}), throwsUnsupported);
      expect(
        () => enc([
          {'a\ud800': 1},
        ]),
        throwsUnsupported,
      );
    });

    test('rejected strings do not leak partial output into replacements', () {
      final result = JcsEncoder((o) => 'replaced').convert({'\ud800': 1});
      expect(result, '"replaced"');
    });
  });

  group('lists', () {
    test('empty', () => expect(enc([]), '[]'));
    test('single element', () => expect(enc([1]), '[1]'));
    test('no whitespace', () => expect(enc([1, 2, 3]), '[1,2,3]'));
    test('keeps order', () => expect(enc([3, 1, 2]), '[3,1,2]'));
    test(
      'nested',
      () => expect(
        enc([
          [],
          [[]],
          [
            1,
            [2],
          ],
        ]),
        '[[],[[]],[1,[2]]]',
      ),
    );
    test('mixed types', () {
      expect(
        enc([null, true, false, 0, 'a', [], {}]),
        '[null,true,false,0,"a",[],{}]',
      );
    });
    test('typed lists', () {
      expect(enc(<int>[1, 2]), '[1,2]');
      expect(enc(<String>['a']), '["a"]');
      expect(enc(const <Object?>[null]), '[null]');
    });
    test('growable and fixed-length lists', () {
      expect(enc(List.filled(3, 0)), '[0,0,0]');
      expect(enc(List<int>.generate(3, (i) => i, growable: false)), '[0,1,2]');
    });
  });

  group('maps', () {
    test('empty', () => expect(enc({}), '{}'));
    test('single entry', () => expect(enc({'a': 1}), '{"a":1}'));
    test('no whitespace', () {
      expect(
        enc({
          'a': 1,
          'b': [1, 2],
          'c': {'d': null},
        }),
        '{"a":1,"b":[1,2],"c":{"d":null}}',
      );
    });
    test('empty key', () => expect(enc({'': 1}), '{"":1}'));
    test('keys are escaped', () {
      expect(enc({'a"b': 1}), r'{"a\"b":1}');
      expect(enc({'a\nb': 1}), r'{"a\nb":1}');
      expect(enc({r'a\b': 1}), r'{"a\\b":1}');
      expect(enc({'\u0001': 1}), r'{"\u0001":1}');
    });
    test('typed maps', () {
      expect(enc(<String, int>{'b': 1, 'a': 2}), '{"a":2,"b":1}');
      expect(
        enc(<String, Object?>{'b': null, 'a': true}),
        '{"a":true,"b":null}',
      );
    });
    test('map implementations', () {
      expect(
        enc(LinkedHashMap<String, int>.of({'b': 1, 'a': 2})),
        '{"a":2,"b":1}',
      );
      expect(
        enc(SplayTreeMap<String, int>.of({'b': 1, 'a': 2})),
        '{"a":2,"b":1}',
      );
      expect(enc(HashMap<String, int>.of({'b': 1, 'a': 2})), '{"a":2,"b":1}');
      expect(enc(const {'b': 1, 'a': 2}), '{"a":2,"b":1}');
    });
    test('does not modify the input', () {
      final map = {'b': 1, 'a': 2};
      enc(map);
      expect(map.keys.toList(), ['b', 'a']);
    });
  });

  group('property sorting', () {
    test('insertion order does not matter', () {
      expect(enc({'a': 1, 'b': 2, 'c': 3}), enc({'c': 3, 'a': 1, 'b': 2}));
      expect(enc({'b': 2, 'c': 3, 'a': 1}), '{"a":1,"b":2,"c":3}');
    });

    test('nested objects are sorted recursively', () {
      expect(
        enc({
          'z': {'b': 1, 'a': 2},
          'a': [
            {'y': 1, 'x': 2},
          ],
        }),
        '{"a":[{"x":2,"y":1}],"z":{"a":2,"b":1}}',
      );
    });

    test('prefix sorts before longer key', () {
      expect(enc({'aa': 1, 'a': 2, 'aaa': 3}), '{"a":2,"aa":1,"aaa":3}');
      expect(enc({'': 1, 'a': 2}), '{"":1,"a":2}');
    });

    test('uppercase before lowercase', () {
      expect(
        enc({'a': 1, 'B': 2, 'A': 3, 'b': 4}),
        '{"A":3,"B":2,"a":1,"b":4}',
      );
    });

    test('keys are compared as strings, not numbers', () {
      expect(
        enc({'10': 1, '9': 2, '1': 3, '2': 4}),
        '{"1":3,"10":1,"2":4,"9":2}',
      );
    });

    test('sorted by UTF-16 code units, not by code points', () {
      // U+1F600 is D83D DE00 in UTF-16 and sorts before U+FB33 and U+E000,
      // although its code point is larger.
      expect(
        enc({'\ufb33': 1, '\u{1f600}': 2, '\ue000': 3, '\ud7ff': 4}),
        '{"\ud7ff":4,"\u{1f600}":2,"\ue000":3,"\ufb33":1}',
      );
    });

    test('RFC 8785 section 3.2.3 sorting sample', () {
      final input = {
        '\u20ac': 'Euro Sign',
        '\r': 'Carriage Return',
        '\ufb33': 'Hebrew Letter Dalet With Dagesh',
        '1': 'One',
        '\u{1f600}': 'Emoji: Grinning Face',
        '\u0080': 'Control',
        '\u00f6': 'Latin Small Letter O With Diaeresis',
      };
      expect(enc(input).codeUnits, isNotEmpty);
      expect((jsonDecode(enc(input)) as Map).keys.toList(), [
        '\r',
        '1',
        '\u0080',
        '\u00f6',
        '\u20ac',
        '\u{1f600}',
        '\ufb33',
      ]);
      expect(
        enc(input),
        '{"\\r":"Carriage Return","1":"One","\u0080":"Control",'
        '"\u00f6":"Latin Small Letter O With Diaeresis",'
        '"\u20ac":"Euro Sign","\u{1f600}":"Emoji: Grinning Face",'
        '"\ufb33":"Hebrew Letter Dalet With Dagesh"}',
      );
    });
  });

  group('RFC 8785 section 3.2.4 sample', () {
    test('canonicalizes the sample', () {
      const input = r'''
{
  "numbers": [333333333.33333329, 1E30, 4.50,
              2e-3, 0.000000000000000000000000001],
  "string": "\u20ac$\u000F\u000aA'\u0042\u0022\u005c\\\"\/",
  "literals": [null, true, false]
}''';
      expect(
        enc(jsonDecode(input)),
        r'''{"literals":[null,true,false],"numbers":[333333333.3333333,1e+30,4.5,0.002,1e-27],"string":"€$\u000f\nA'B\"\\\\\"/"}''',
      );
    });
  });

  group('idempotence and validity', () {
    const canonical = [
      '{}',
      '[]',
      '[1,2,3]',
      '{"a":1,"b":[true,false,null],"c":{"d":"e"}}',
      '{"literals":[null,true,false],"numbers":[333333333.3333333,1e+30,4.5,0.002,1e-27]}',
      r'{"s":"a\"b\\c\n\u0001"}',
    ];
    for (final input in canonical) {
      test('canonical input is a fixed point: $input', () {
        expect(enc(jsonDecode(input)), input);
      });
    }

    test('output is valid JSON that decodes to the original', () {
      final value = {
        'z': [1, 2.5, -3, 1e30, 1e-7, null, true, false],
        'a': {'nested': 'text\n"quoted"\\', 'e': '\u20ac\u{1f600}'},
        '': [],
        'o': {},
      };
      expect(jsonDecode(enc(value)), value);
    });

    test('encoding twice yields the same result', () {
      final value = {
        'b': [3, 2, 1],
        'a': 'x',
      };
      final once = enc(value);
      expect(enc(jsonDecode(once)), once);
    });

    test('equal data in different order gives equal output', () {
      expect(
        enc(jsonDecode('{"b":1,"a":{"d":1,"c":2}}')),
        enc(jsonDecode('{"a":{"c":2,"d":1},"b":1}')),
      );
    });

    test('whitespace in the input is dropped', () {
      expect(
        enc(jsonDecode(' { "a" : [ 1 , 2 ] ,\n"b":\t"x" } ')),
        '{"a":[1,2],"b":"x"}',
      );
    });
  });

  group('unsupported keys', () {
    test('non-string keys are rejected', () {
      expect(() => enc({1: 2}), throwsUnsupported);
      expect(() => enc({1: 2, 3: 4}), throwsUnsupported);
      expect(() => enc({'a': 1, 2: 3}), throwsUnsupported);
      expect(() => enc({null: 1, 'a': 2}), throwsUnsupported);
      expect(() => enc({#a: 1}), throwsUnsupported);
      expect(() => enc(<Object?, Object?>{true: 1}), throwsUnsupported);
    });

    test('non-string keys are rejected when nested', () {
      expect(
        () => enc([
          {1: 2, 3: 4},
        ]),
        throwsUnsupported,
      );
      expect(
        () => enc({
          'a': {1: 2},
        }),
        throwsUnsupported,
      );
    });

    test('rejection happens before any output is written', () {
      final error = _catch(() => enc({'a': 1, 'b': 2, 3: 4}));
      expect(error, isA<JsonUnsupportedObjectError>());
      expect((error as JsonUnsupportedObjectError).partialResult, isEmpty);
    });
  });

  group('toEncodable', () {
    test('default calls toJson()', () {
      expect(enc(_WithToJson(1)), '{"value":1}');
      expect(
        enc([_WithToJson(1), _WithToJson(2)]),
        '[{"value":1},{"value":2}]',
      );
      expect(enc({'x': _WithToJson(3)}), '{"x":{"value":3}}');
    });

    test('default fails on objects without toJson()', () {
      expect(() => enc(_WithoutToJson()), throwsUnsupported);
      expect(() => enc([_WithoutToJson()]), throwsUnsupported);
      expect(() => enc(DateTime(2020)), throwsUnsupported);
      expect(() => enc(#symbol), throwsUnsupported);
    });

    test('unsupported error carries object and cause', () {
      final object = _WithoutToJson();
      final error = _catch(() => enc(object));
      expect(error, isA<JsonUnsupportedObjectError>());
      error as JsonUnsupportedObjectError;
      expect(error.unsupportedObject, same(object));
      expect(error.cause, isA<NoSuchMethodError>());
    });

    test('custom function replaces objects', () {
      final custom = JcsEncoder(
        (o) => o is DateTime ? o.toUtc().toIso8601String() : o,
      );
      expect(
        custom.convert(DateTime.utc(2020, 1, 2, 3, 4, 5)),
        '"2020-01-02T03:04:05.000Z"',
      );
      expect(
        custom.convert({'when': DateTime.utc(2020)}),
        '{"when":"2020-01-01T00:00:00.000Z"}',
      );
    });

    test('replacement may contain further objects', () {
      final custom = JcsEncoder((o) {
        if (o is _WithoutToJson) return {'inner': _WithToJson(1)};
        if (o is _WithToJson) return [o.value];
        return o;
      });
      expect(custom.convert(_WithoutToJson()), '{"inner":[1]}');
    });

    test('replacement map is sorted', () {
      final custom = JcsEncoder((o) => {'b': 1, 'a': 2});
      expect(custom.convert(_WithoutToJson()), '{"a":2,"b":1}');
    });

    test('is not called for directly encodable values', () {
      var calls = 0;
      final custom = JcsEncoder((o) {
        calls++;
        return o;
      });
      final result = custom.convert([
        1,
        'a',
        null,
        true,
        1.5,
        {'a': []},
      ]);
      expect(result, '[1,"a",null,true,1.5,{"a":[]}]');
      expect(calls, 0);
    });

    test('is called once per unsupported object', () {
      var calls = 0;
      final custom = JcsEncoder((o) {
        calls++;
        return 1;
      });
      expect(custom.convert([_WithoutToJson(), _WithoutToJson()]), '[1,1]');
      expect(calls, 2);
    });

    test('exception thrown by function is wrapped', () {
      final custom = JcsEncoder((o) => throw StateError('boom'));
      final error = _catch(() => custom.convert(_WithoutToJson()));
      expect(error, isA<JsonUnsupportedObjectError>());
      expect((error as JsonUnsupportedObjectError).cause, isA<StateError>());
    });

    test('unsupported replacement is rejected', () {
      final custom = JcsEncoder((o) => _WithoutToJson());
      expect(() => custom.convert(_WithoutToJson()), throwsUnsupported);
    });

    test('non-finite replacement is rejected', () {
      final custom = JcsEncoder((o) => double.nan);
      expect(() => custom.convert(_WithoutToJson()), throwsUnsupported);
    });

    test('function may turn non-finite numbers into something else', () {
      final custom = JcsEncoder((o) => o is double ? o.toString() : o);
      expect(
        custom.convert([double.nan, double.infinity]),
        '["NaN","Infinity"]',
      );
    });
  });

  group('cycles', () {
    test('self-containing list', () {
      final list = <Object?>[];
      list.add(list);
      expect(() => enc(list), throwsCyclic);
    });

    test('self-containing map', () {
      final map = <String, Object?>{};
      map['self'] = map;
      expect(() => enc(map), throwsCyclic);
    });

    test('indirect cycle', () {
      final a = <String, Object?>{};
      final b = <Object?>[a];
      a['b'] = b;
      expect(() => enc(a), throwsCyclic);
      expect(() => enc(b), throwsCyclic);
    });

    test('cycle through a replaced object', () {
      final list = <Object?>[];
      final custom = JcsEncoder((o) => list);
      list.add(_WithoutToJson());
      expect(() => custom.convert(list), throwsCyclic);
    });

    test('shared, non-cyclic references are fine', () {
      final shared = [1, 2];
      expect(
        enc([
          shared,
          shared,
          {'a': shared},
        ]),
        '[[1,2],[1,2],{"a":[1,2]}]',
      );
    });

    test('the encoder can be reused after a failure', () {
      final list = <Object?>[];
      list.add(list);
      expect(() => enc(list), throwsCyclic);
      expect(enc([1]), '[1]');
    });
  });

  group('deep structures', () {
    test('deeply nested lists', () {
      Object? value = 1;
      for (var i = 0; i < 500; i++) {
        value = [value];
      }
      expect(enc(value), '${'[' * 500}1${']' * 500}');
    });

    test('large flat structures', () {
      final map = {for (var i = 0; i < 1000; i++) 'k${1000 - i}': i};
      final result = jsonDecode(enc(map)) as Map;
      final keys = result.keys.cast<String>().toList();
      expect(keys, ([...map.keys]..sort()));
      expect(result.length, 1000);
    });
  });

  group('converter', () {
    test('is a Converter<Object?, String>', () {
      expect(encoder, isA<Converter<Object?, String>>());
    });

    test('can be used with fuse', () {
      final bytes = encoder.fuse(utf8.encoder).convert({'a': '\u20ac'});
      expect(utf8.decode(bytes), '{"a":"\u20ac"}');
    });

    test('const instances are canonicalized', () {
      expect(identical(const JcsEncoder(), const JcsEncoder()), isTrue);
    });
  });
}

Object _catch(void Function() body) {
  try {
    body();
  } catch (e) {
    return e;
  }
  fail('Expected an exception to be thrown.');
}
