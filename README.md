# JSON Canonicalization Scheme (JCS)

[![Pub Version](https://img.shields.io/pub/v/jcs)](https://pub.dev/packages/jcs) [![Pub Points](https://img.shields.io/pub/points/jcs)](https://pub.dev/packages/jcs/score)

Dart implementation of [RFC 8785](https://www.rfc-editor.org/rfc/rfc8785.html), the JSON Canonicalization Scheme.

## Comparing

The native JSON functions in `dart:convert` already mostly fit into the specification, with just minor tweaks that were required to be done. These add the following features on top of already existing ones:

- Object properties are sorted by name (compared as UTF-16 code units)
- Numbers are serialized as ECMAScript does
  - `-0` becomes `0`, integral values have no trailing `.0`
- Unpaired surrogates are rejected

Through the native functions, the following aspects of the spec were already present:

- No insignificant whitespace
- Minimal string escaping
  - Only `"`, `\` and control characters, the latter as `\b`, `\t`, `\n`, `\f`, `\r` or lowercase `\u00xx`
  - Non-ASCII characters and `/` are written as is
- Non-finite numbers (`NaN`, infinities) are rejected

## Example

This package can be used identically to `dart:convert`'s JSON functions. Instead of the `json` or `Json` prefix, you just have to use `jcs`/`Jcs`:

```dart
jcsEncode(data);
jcs.encode(data); // the `JcsCodec` named `jcs` being equivalent to `json`
JcsCodec().encode(data); // `JcsCodec` may have arguments, see API docs
JcsCodec().encoder.convert(data);
jcs.encoder.convert(data);
JcsEncoder().convert(data);
```

`JcsCodec` can be used together with other converters for example. A common use case for JCS is to be used in a UTF-8 decoded representation; this can be achieved like this:

```dart
jcs.encoder.fuse(utf8.encoder).convert(data)
```
