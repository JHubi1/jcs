import 'dart:convert';

import 'package:jcs/jcs.dart';

final example = jsonDecode(r"""
{
  "numbers": [333333333.33333329, 1E30, 4.50,
              2e-3, 0.000000000000000000000000001],
  "string": "\u20ac$\u000F\u000aA'\u0042\u0022\u005c\\\"\/",
  "literals": [null, true, false]
}""");

final exampleOrder = jsonDecode(r"""
{
  "\u20ac": "Euro Sign",
  "\r": "Carriage Return",
  "\ufb33": "Hebrew Letter Dalet With Dagesh",
  "1": "One",
  "\ud83d\ude00": "Emoji: Grinning Face",
  "\u0080": "Control",
  "\u00f6": "Latin Small Letter O With Diaeresis"
}""");

void main() {
  print("Normal:\t${jsonEncode(example)}");
  print("JCS:\t${jcsEncode(example)}");

  print("-" * 10);
  print(
    "Normal Bytes:\t${json.encoder.fuse(utf8.encoder).convert(example).map((b) => b.toRadixString(16).padLeft(2, "0")).join(" ")}",
  );
  print(
    "JCS Bytes:\t${jcs.encoder.fuse(utf8.encoder).convert(example).map((b) => b.toRadixString(16).padLeft(2, "0")).join(" ")}",
  );

  print("-" * 10);
  print("Normal Order:\t${jsonEncode(exampleOrder)}");
  print("JCS Order:\t${jcsEncode(exampleOrder)}");
}
