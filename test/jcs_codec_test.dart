import 'dart:convert';

import 'package:jcs/jcs.dart';
import 'package:test/test.dart';

class _Custom {
  final String text;
  final int value;
  _Custom(this.text, this.value);

  Map<String, Object?> toJson() => {'text': text, 'value': value};
}

class _NoJson {}

void main() {
  group('jcs constant', () {
    test('is a JcsCodec', () => expect(jcs, isA<JcsCodec>()));

    test('encodes', () {
      expect(
        jcs.encode([
          1,
          2,
          {'a': null},
        ]),
        '[1,2,{"a":null}]',
      );
      expect(jcs.encode({'b': 1, 'a': 2}), '{"a":2,"b":1}');
    });

    test('const instances are canonicalized', () {
      expect(identical(const JcsCodec(), const JcsCodec()), isTrue);
      expect(identical(jcs, const JcsCodec()), isTrue);
    });
  });

  group('jcsEncode', () {
    test('matches jcs.encode', () {
      const value = {'value': 2, 'text': 'foo', 'extra': null, 'status': false};
      expect(jcsEncode(value), jcs.encode(value));
      expect(
        jcsEncode(value),
        '{"extra":null,"status":false,"text":"foo","value":2}',
      );
    });

    test('with toEncodable', () {
      final text = jcsEncode(
        {'cc': _NoJson()},
        toEncodable: (value) => value is _NoJson
            ? {'text': 'Dart', 'value': 123}
            : throw UnsupportedError('Cannot convert to JCS: $value'),
      );
      expect(text, '{"cc":{"text":"Dart","value":123}}');
    });
  });

  group('JcsCodec.encode', () {
    test('uses toJson() by default', () {
      expect(jcs.encode(_Custom('Dart', 123)), '{"text":"Dart","value":123}');
      expect(jcs.encode([_Custom('a', 1)]), '[{"text":"a","value":1}]');
    });

    test('throws for unsupported objects', () {
      expect(
        () => jcs.encode(_NoJson()),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
    });

    test('throws for non-finite numbers', () {
      expect(
        () => jcs.encode(double.nan),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
    });

    test('constructor toEncodable is used', () {
      const codec = JcsCodec(null, _constructorEncodable);
      expect(codec.encode(_NoJson()), '"constructor"');
    });

    test('argument toEncodable overrides constructor toEncodable', () {
      const codec = JcsCodec(null, _constructorEncodable);
      expect(
        codec.encode(_NoJson(), toEncodable: (o) => 'argument'),
        '"argument"',
      );
    });

    test('toEncodable is not used for directly encodable values', () {
      const codec = JcsCodec(null, _constructorEncodable);
      expect(codec.encode([1, 'a', null]), '[1,"a",null]');
    });
  });

  group('JcsCodec.encoder', () {
    test('is a JcsEncoder', () {
      expect(jcs.encoder, isA<JcsEncoder>());
      expect(jcs.encoder.convert({'b': 1, 'a': 2}), '{"a":2,"b":1}');
    });

    test('uses the constructor toEncodable', () {
      const codec = JcsCodec(null, _constructorEncodable);
      expect(codec.encoder.convert(_NoJson()), '"constructor"');
    });
  });

  group('JcsCodec.decode', () {
    test('decodes an object', () {
      const source = '{"extra":null,"status":false,"text":"foo","value":1}';
      final data = jcs.decode(source);
      expect(data['text'], 'foo');
      expect(data['value'], 1);
      expect(data['status'], false);
      expect(data['extra'], null);
    });

    test('decodes a list', () {
      final list =
          jcs.decode(
                '[{"status":true,"text":"foo","value":1},'
                '{"status":false,"text":"bar","value":2}]',
              )
              as List<dynamic>;
      expect(list, hasLength(2));
      expect(list[0], {'status': true, 'text': 'foo', 'value': 1});
      expect(list[1]['text'], 'bar');
    });

    test('parses all JSON value types', () {
      expect(jcs.decode('null'), isNull);
      expect(jcs.decode('true'), true);
      expect(jcs.decode('false'), false);
      expect(jcs.decode('1'), 1);
      expect(jcs.decode('-1.5'), -1.5);
      expect(jcs.decode('"s"'), 's');
      expect(jcs.decode('[]'), isEmpty);
      expect(jcs.decode('{}'), isEmpty);
    });

    test('parses escapes', () {
      expect(jcs.decode(r'"\u20ac\n\"\\\/"'), '\u20ac\n"\\/');
      expect(jcs.decode(r'"\ud83d\ude00"'), '\u{1f600}');
    });

    test('accepts non-canonical JSON', () {
      expect(jcs.decode(' { "b" : 1 , "a" : [ 1.0 , 1e2 ] } '), {
        'b': 1,
        'a': [1.0, 100.0],
      });
    });

    test('throws FormatException for invalid input', () {
      for (final source in [
        '',
        '{',
        '[1,]',
        '{"a":1,}',
        "{'a':1}",
        '{a:1}',
        'undefined',
        'NaN',
        'Infinity',
        '01',
        '1.',
        '"unterminated',
        '[1 2]',
        '{"a" 1}',
        '1 2',
      ]) {
        expect(() => jcs.decode(source), throwsFormatException, reason: source);
      }
    });

    test('canonical output decodes back to the original', () {
      final value = {
        'a': [1, 2.5, 'x', null, true],
        'b': {'c': '\u20ac'},
      };
      expect(jcs.decode(jcs.encode(value)), value);
    });

    test('constructor reviver is used', () {
      const codec = JcsCodec(_incrementInts);
      expect(codec.decode('[1,2]'), [2, 3]);
    });

    test('argument reviver overrides constructor reviver', () {
      const codec = JcsCodec(_incrementInts);
      expect(codec.decode('[1,2]', reviver: (k, v) => v is int ? v * 100 : v), [
        100,
        200,
      ]);
    });

    test('reviver receives keys and indices', () {
      final keys = <Object?>[];
      jcs.decode(
        '{"a":[true],"b":null}',
        reviver: (key, value) {
          keys.add(key);
          return value;
        },
      );
      expect(keys, [0, 'a', 'b', null]);
    });
  });

  group('JcsCodec.decoder', () {
    test('is a JsonDecoder', () {
      expect(jcs.decoder, isA<JsonDecoder>());
      expect(jcs.decoder.convert('[1]'), [1]);
    });

    test('uses the constructor reviver', () {
      const codec = JcsCodec(_incrementInts);
      expect(codec.decoder.convert('[1]'), [2]);
    });

    test('fuse with utf8', () {
      final fused = jcs.fuse(utf8);
      final bytes = fused.encode({'a': '\u20ac'});
      expect(utf8.decode(bytes), '{"a":"\u20ac"}');
      expect(fused.decode(bytes), {'a': '\u20ac'});
    });
  });
}

Object? _constructorEncodable(dynamic o) => 'constructor';

Object? _incrementInts(Object? key, Object? value) =>
    value is int ? value + 1 : value;
