import 'dart:convert';

/// This class converts JSON objects to their canonical string form as defined
/// by the JSON Canonicalization Scheme (JCS, [RFC 8785](https://www.rfc-editor.org/rfc/rfc8785.html)).
///
/// The output contains no insignificant whitespace, and the properties of every
/// object are sorted by their names, compared as sequences of UTF-16 code
/// units.
///
/// Numbers are written as ECMAScript would serialize them: all numbers are
/// treated as doubles, `-0` is written as `0`, and the shortest round-tripping
/// representation is used.
///
/// Strings are written with only the minimal escaping: `"` and `\` are
/// backslash-escaped, the control characters below U+0020 are written as `\b`,
/// `\t`, `\n`, `\f`, `\r` or as `\u00xx` with lowercase hexadecimal digits. All
/// other characters, including `/` and non-ASCII characters, are written as is.
/// Strings (and map keys) containing unpaired surrogates are not valid I-JSON
/// and cannot be serialized, so they are treated as non-encodable.
///
/// Example:
///
/// ```dart
/// const JcsEncoder encoder = JcsEncoder();
/// const data = {'value': '2', 'text': 'foo'};
///
/// final String jcsString = encoder.convert(data);
/// print(jcsString); // {"text":"foo","value":"2"}
/// ```
final class JcsEncoder extends Converter<Object?, String> {
  /// Function called on non-encodable objects to return a replacement encodable
  /// object that will be encoded in the original's place.
  final Object? Function(dynamic)? _toEncodable;

  /// Creates a JCS encoder.
  ///
  /// The JCS encoder handles numbers, strings, booleans, null, lists and maps
  /// with string keys directly.
  ///
  /// Any other object is attempted converted by [_toEncodable] to an object
  /// that is of one of the convertible types.
  ///
  /// If [_toEncodable] is omitted, it defaults to calling `.toJson()` on the
  /// object.
  const JcsEncoder([this._toEncodable]);

  /// Converts [object] to a canonical JCS [String].
  ///
  /// Directly serializable values are [num], [String], [bool], and [Null], as
  /// well as some [List] and [Map] values. For [List], the elements must all be
  /// serializable. For [Map], the keys must be [String] and the values must be
  /// serializable. The properties of a [Map] are written in sorted order.
  ///
  /// If a value of any other type is attempted to be serialized, the
  /// `toEncodable` function provided in the constructor is called with the
  /// value as argument. The result, which must be a directly serializable
  /// value, is serialized instead of the original value.
  ///
  /// Non-finite numbers ([double.nan] and infinities) cannot be represented in
  /// JSON and are not directly serializable either.
  ///
  /// If the conversion throws, or returns a value that is not directly
  /// serializable, a [JsonUnsupportedObjectError] exception is thrown.
  /// If the call throws, the error is caught and stored in the
  /// [JsonUnsupportedObjectError]'s `cause` field.
  ///
  /// If a [List] or [Map] contains a reference to itself, directly or through
  /// other lists or maps, it cannot be serialized and a [JsonCyclicError] is
  /// thrown.
  ///
  /// [object] should not change during serialization.
  @override
  String convert(Object? object) =>
      _JsonStringStringifier.stringify(object, _toEncodable);
}

dynamic _defaultToEncodable(dynamic object) => object.toJson();

/// JSON encoder that traverses an object structure and writes JSON source.
///
/// This is an abstract implementation that doesn't decide on the output format,
/// but writes the JSON through abstract methods like [writeString].
abstract class _JsonStringifier {
  // Character code constants.
  static const int backspace = 0x08;
  static const int tab = 0x09;
  static const int newline = 0x0a;
  static const int carriageReturn = 0x0d;
  static const int formFeed = 0x0c;
  static const int quote = 0x22;
  static const int char_0 = 0x30;
  static const int backslash = 0x5c;
  static const int charB = 0x62;
  static const int charF = 0x66;
  static const int charN = 0x6e;
  static const int charR = 0x72;
  static const int charT = 0x74;
  static const int charU = 0x75;
  static const int surrogateMin = 0xd800;
  static const int surrogateMask = 0xfc00;
  static const int surrogateLead = 0xd800;
  static const int surrogateTrail = 0xdc00;

  /// List of objects currently being traversed. Used to detect cycles.
  final List _seen = [];

  /// Function called for each un-encodable object encountered.
  final dynamic Function(dynamic) _toEncodable;

  _JsonStringifier(dynamic Function(dynamic o)? toEncodable)
    : _toEncodable = toEncodable ?? _defaultToEncodable;

  String? get _partialResult;

  /// Append a string to the JSON output.
  void writeString(String characters);

  /// Append part of a string to the JSON output.
  void writeStringSlice(String characters, int start, int end);

  /// Append a single character, given by its code point, to the JSON output.
  void writeCharCode(int charCode);

  // ('0' + x) or ('a' + x - 10)
  static int hexDigit(int x) => x < 10 ? 48 + x : 87 + x;

  /// Write, and suitably escape, a string's content as a JSON string literal.
  void writeStringContent(String s) {
    var offset = 0;
    final length = s.length;
    for (var i = 0; i < length; i++) {
      final charCode = s.codeUnitAt(i);
      if (charCode > backslash) continue;
      if (charCode < 32) {
        if (i > offset) writeStringSlice(s, offset, i);
        offset = i + 1;
        writeCharCode(backslash);
        switch (charCode) {
          case backspace:
            writeCharCode(charB);
          case tab:
            writeCharCode(charT);
          case newline:
            writeCharCode(charN);
          case formFeed:
            writeCharCode(charF);
          case carriageReturn:
            writeCharCode(charR);
          default:
            writeCharCode(charU);
            writeCharCode(char_0);
            writeCharCode(char_0);
            writeCharCode(hexDigit((charCode >> 4) & 0xf));
            writeCharCode(hexDigit(charCode & 0xf));
        }
      } else if (charCode == quote || charCode == backslash) {
        if (i > offset) writeStringSlice(s, offset, i);
        offset = i + 1;
        writeCharCode(backslash);
        writeCharCode(charCode);
      }
    }
    if (offset == 0) {
      writeString(s);
    } else if (offset < length) {
      writeStringSlice(s, offset, length);
    }
  }

  /// Check if an encountered object is already being traversed.
  ///
  /// Records the object if it isn't already seen. Should have a matching call
  /// to [_removeSeen] when the object is no longer being traversed.
  void _checkCycle(Object? object) {
    for (var i = 0; i < _seen.length; i++) {
      if (identical(object, _seen[i])) {
        throw JsonCyclicError(object);
      }
    }
    _seen.add(object);
  }

  /// Whether [s] is well-formed UTF-16, i.e. contains no unpaired surrogates.
  bool _checkValidString(String s) {
    final length = s.length;
    for (var i = 0; i < length; i++) {
      final charCode = s.codeUnitAt(i);
      if (charCode < surrogateMin) continue;
      final type = charCode & surrogateMask;
      if (type == surrogateLead) {
        if (i + 1 < length &&
            (s.codeUnitAt(i + 1) & surrogateMask) == surrogateTrail) {
          i++;
        } else {
          return false;
        }
      } else if (type == surrogateTrail) {
        return false;
      }
    }
    return true;
  }

  /// Remove [object] from the list of currently traversed objects.
  ///
  /// Should be called in the opposite order of the matching [_checkCycle]
  /// calls.
  void _removeSeen(Object? object) {
    assert(_seen.isNotEmpty, "No objects are currently being traversed.");
    assert(
      identical(_seen.last, object),
      "The last seen object is not the one being removed.",
    );
    _seen.removeLast();
  }

  /// Write an object.
  ///
  /// If [object] isn't directly encodable, the [_toEncodable] function gets one
  /// chance to return a replacement which is encodable.
  void writeObject(Object? object) {
    // Tries stringifying object directly. If it's not a simple value, List or
    // Map, call toJson() to get a custom representation and try serializing
    // that.
    if (writeJsonValue(object)) return;
    _checkCycle(object);
    try {
      final customJson = _toEncodable(object);
      if (!writeJsonValue(customJson)) {
        throw JsonUnsupportedObjectError(object, partialResult: _partialResult);
      }
      _removeSeen(object);
    } catch (e) {
      if (e is JsonUnsupportedObjectError) rethrow;
      throw JsonUnsupportedObjectError(
        object,
        cause: e,
        partialResult: _partialResult,
      );
    }
  }

  /// Serialize a [num], [String], [bool], [Null], [List] or [Map] value.
  ///
  /// Returns true if the value is one of these types, and false if not.
  /// If a value is both a [List] and a [Map], it's serialized as a [List].
  bool writeJsonValue(Object? object) {
    if (object is num) {
      return writeNumber(object);
    } else if (identical(object, true)) {
      writeString('true');
      return true;
    } else if (identical(object, false)) {
      writeString('false');
      return true;
    } else if (object == null) {
      writeString('null');
      return true;
    } else if (object is String) {
      if (!_checkValidString(object)) return false;
      writeString('"');
      writeStringContent(object);
      writeString('"');
      return true;
    } else if (object is List) {
      _checkCycle(object);
      writeList(object);
      _removeSeen(object);
      return true;
    } else if (object is Map) {
      _checkCycle(object);
      // writeMap can fail if keys are not all strings.
      final success = writeMap(object);
      _removeSeen(object);
      return success;
    } else {
      return false;
    }
  }

  /// Write a number to the JSON output, as per ECMA-262 7.1.12.1 (including
  /// note 2).
  ///
  /// This is necessary to comply with specs.
  bool writeNumber(num number) {
    // ECMAScript only has doubles. Converting first also avoids overflowing
    // when negating the minimum 64-bit integer.
    final value = number.toDouble();
    if (!value.isFinite) return false;
    if (value == 0) {
      writeString("0");
      return true;
    } else if (value < 0) {
      writeCharCode(0x2d); // '-'
      return writeNumber(-value);
    }

    final representation = value.toString();
    final exponentIndex = representation.indexOf("e");
    final mantissa = exponentIndex == -1
        ? representation
        : representation.substring(0, exponentIndex);
    final exponent = exponentIndex == -1
        ? 0
        : int.parse(representation.substring(exponentIndex + 1));
    final decimalIndex = mantissa.indexOf(".");
    final decimalPosition = decimalIndex == -1 ? mantissa.length : decimalIndex;
    var digits = mantissa.replaceAll(".", "");
    var firstNonZero = 0;
    while (digits.codeUnitAt(firstNonZero) == char_0) {
      firstNonZero++;
    }

    final n = decimalPosition + exponent - firstNonZero;
    digits = digits.substring(firstNonZero);
    while (digits.length > 1 && digits.endsWith("0")) {
      digits = digits.substring(0, digits.length - 1);
    }
    final k = digits.length;

    if (k <= n && n <= 21) {
      writeString(digits.padRight(n, "0"));
    } else if (n > 0 && n <= 21) {
      writeString("${digits.substring(0, n)}.${digits.substring(n)}");
    } else if (n > -6 && n <= 0) {
      writeString("0.${List.filled(-n, "0").join()}$digits");
    } else {
      final scientificExponent = n - 1;
      final exponentSign = scientificExponent >= 0 ? "+" : "-";
      final significand = k == 1
          ? digits
          : "${digits[0]}.${digits.substring(1)}";
      writeString("${significand}e$exponentSign${scientificExponent.abs()}");
    }

    return true;
  }

  /// Serialize a [List].
  void writeList(List<Object?> list) {
    writeString('[');
    if (list.isNotEmpty) {
      writeObject(list[0]);
      for (var i = 1; i < list.length; i++) {
        writeString(',');
        writeObject(list[i]);
      }
    }
    writeString(']');
  }

  /// Serialize a [Map].
  bool writeMap(Map<Object?, Object?> map) {
    if (map.isEmpty) {
      writeString("{}");
      return true;
    }
    final keyValueList = List<Object?>.filled(map.length * 2, null);
    var i = 0;
    if (map.keys.any((key) => key is! String || !_checkValidString(key))) {
      return false;
    }
    for (var entry
        in (map.entries.toList()..sort((a, b) {
          final keyA = (a.key! as String).codeUnits;
          final keyB = (b.key! as String).codeUnits;
          for (var i = 0; i < keyA.length && i < keyB.length; i++) {
            if (keyA[i] != keyB[i]) return keyA[i] - keyB[i];
          }
          return keyA.length - keyB.length;
        }))) {
      keyValueList[i++] = entry.key;
      keyValueList[i++] = entry.value;
    }
    writeString('{');
    var separator = '"';
    for (var i = 0; i < keyValueList.length; i += 2) {
      writeString(separator);
      separator = ',"';
      writeStringContent(keyValueList[i]! as String);
      writeString('":');
      writeObject(keyValueList[i + 1]);
    }
    writeString('}');
    return true;
  }
}

/// A specialization of [_JsonStringifier] that writes its JSON to a string.
class _JsonStringStringifier extends _JsonStringifier {
  final StringSink _sink;

  _JsonStringStringifier(
    this._sink,
    dynamic Function(dynamic object)? _toEncodable,
  ) : super(_toEncodable);

  /// Convert object to a string.
  ///
  /// The [toEncodable] function is used to convert non-encodable objects to
  /// encodable ones.
  static String stringify(
    Object? object,
    dynamic Function(dynamic object)? toEncodable,
  ) {
    final output = StringBuffer();
    printOn(object, output, toEncodable);
    return output.toString();
  }

  /// Convert object to a string, and write the result to the [output] sink.
  ///
  /// The result is written piecemeally to the sink.
  static void printOn(
    Object? object,
    StringSink output,
    dynamic Function(dynamic o)? toEncodable,
  ) => _JsonStringStringifier(output, toEncodable).writeObject(object);

  @override
  String? get _partialResult => _sink is StringBuffer ? _sink.toString() : null;

  @override
  void writeString(String string) => _sink.write(string);

  @override
  void writeStringSlice(String string, int start, int end) =>
      _sink.write(string.substring(start, end));

  @override
  void writeCharCode(int charCode) => _sink.writeCharCode(charCode);
}
