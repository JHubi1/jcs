import 'dart:convert';

import 'jcs_encoder.dart';

/// An instance of the default implementation of the [JcsCodec].
///
/// This instance provides a convenient access to the most common JCS use cases.
///
/// Examples:
/// ```dart
/// var encoded = jcs.encode([1, 2, { "a": null }]);
/// var decoded = jcs.decode('["foo",{"bar":499}]');
/// ```
/// The top-level [jcsEncode] function may be used instead if a local variable
/// shadows the [jcs] constant.
const jcs = JcsCodec();

/// Converts [object] to a canonical JCS string.
///
/// If value contains objects that are not directly encodable to a JCS string
/// (a value that is not a number, boolean, string, null, list or a map with
/// string keys), the [toEncodable] function is used to convert it to an object
/// that must be directly encodable.
///
/// If [toEncodable] is omitted, it defaults to a function that returns the
/// result of calling `.toJson()` on the unencodable object.
///
/// Shorthand for `jcs.encode`. Useful if a local variable shadows the global
/// [jcs] constant.
///
/// Example:
/// ```dart
/// const data = {'value': 2, 'text': 'foo', 'extra': null, 'status': false};
/// final String jcsString = jcsEncode(data);
/// print(jcsString); // {"extra":null,"status":false,"text":"foo","value":2}
/// ```
///
/// Example of converting an otherwise unsupported object to a custom JCS
/// format:
///
/// ```dart
/// class CustomClass {
///   final String text;
///   final int value;
///   CustomClass({required this.text, required this.value});
///   CustomClass.fromJson(Map<String, dynamic> json)
///       : text = json['text'],
///         value = json['value'];
///
///   static Map<String, dynamic> toJson(CustomClass value) =>
///       {'text': value.text, 'value': value.value};
/// }
///
/// void main() {
///   final CustomClass cc = CustomClass(text: 'Dart', value: 123);
///   final jcsText = jcsEncode({'cc': cc},
///       toEncodable: (Object? value) => value is CustomClass
///           ? CustomClass.toJson(value)
///           : throw UnsupportedError('Cannot convert to JCS: $value'));
///   print(jcsText); // {"cc":{"text":"Dart","value":123}}
/// }
/// ```
String jcsEncode(
  Object? object, {
  Object? Function(Object? nonEncodable)? toEncodable,
}) => jcs.encode(object, toEncodable: toEncodable);

/// A [JcsCodec] encodes JSON objects to canonical JCS strings and decodes JCS
/// strings to JSON objects.
///
/// There is no dedicated JCS decoder. A canonical JCS string is valid JSON, so
/// decoding is delegated to the [JsonDecoder] of `dart:convert`. As a
/// consequence, decoding accepts any valid JSON text, not only canonical JCS,
/// and throws a [FormatException] if the input is not valid JSON text.
///
/// Examples:
/// ```dart
/// var encoded = jcs.encode([1, 2, { "a": null }]);
/// var decoded = jcs.decode('["foo",{"bar":499}]');
/// ```
final class JcsCodec extends Codec<Object?, String> {
  final Object? Function(Object? key, Object? value)? _reviver;
  final Object? Function(dynamic)? _toEncodable;

  /// Creates a `JcsCodec` with the given reviver and encoding function.
  ///
  /// The [_reviver] function is called during decoding. It is invoked once for
  /// each object or list property that has been parsed.
  /// The `key` argument is either the integer list index for a list property,
  /// the string map key for object properties, or `null` for the final result.
  ///
  /// If [_reviver] is omitted, it defaults to returning the value argument.
  ///
  /// The [_toEncodable] function is used during encoding. It is invoked for
  /// values that are not directly encodable to a string (a value that is not a
  /// number, boolean, string, null, list or a map with string keys). The
  /// function must return an object that is directly encodable. The elements of
  /// a returned list and values of a returned map do not need to be directly
  /// encodable, and if they aren't, `_toEncodable` will be used on them as
  /// well. Please notice that it is possible to cause an infinite recursive
  /// regress in this way, by effectively creating an infinite data structure
  /// through repeated call to `_toEncodable`.
  ///
  /// If [_toEncodable] is omitted, it defaults to a function that returns the
  /// result of calling `.toJson()` on the unencodable object.
  const JcsCodec([this._reviver, this._toEncodable]);

  /// Parses the string and returns the resulting JSON object.
  ///
  /// There is no dedicated JCS decoder; this delegates to the [JsonDecoder] of
  /// `dart:convert`. The input is therefore not required to be canonical, and a
  /// [FormatException] is thrown if it is not valid JSON text.
  ///
  /// The optional [reviver] function is called once for each object or list
  /// property that has been parsed during decoding. The `key` argument is
  /// either the integer list index for a list property, the string map key for
  /// object properties, or `null` for the final result.
  ///
  /// The default [reviver] (when not provided) is the identity function.
  @override
  dynamic decode(
    String source, {
    Object? Function(Object? key, Object? value)? reviver,
  }) {
    reviver ??= _reviver;
    if (reviver == null) return decoder.convert(source);
    return JsonDecoder(reviver).convert(source);
  }

  /// Converts [value] to a canonical JCS string.
  ///
  /// If value contains objects that are not directly encodable to a JCS string
  /// (a value that is not a number, boolean, string, null, list or a map with
  /// string keys), the [toEncodable] function is used to convert it to an
  /// object that must be directly encodable.
  ///
  /// If [toEncodable] is omitted, it defaults to a function that returns the
  /// result of calling `.toJson()` on the unencodable object.
  @override
  String encode(
    Object? value, {
    Object? Function(dynamic object)? toEncodable,
  }) {
    toEncodable ??= _toEncodable;
    if (toEncodable == null) return encoder.convert(value);
    return JcsEncoder(toEncodable).convert(value);
  }

  /// The decoder used by this codec.
  ///
  /// There is no JCS-specific decoder, so this is a plain [JsonDecoder] from
  /// `dart:convert`, constructed with the reviver of this codec, if any.
  @override
  JsonDecoder get decoder {
    if (_reviver == null) return const JsonDecoder();
    return JsonDecoder(_reviver);
  }

  @override
  JcsEncoder get encoder {
    if (_toEncodable == null) return const JcsEncoder();
    return JcsEncoder(_toEncodable);
  }
}
