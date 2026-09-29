// Lenient readers for PayWay JSON: values documented as strings are read with
// toString() so a number (e.g. an account or mid) does not break parsing.

/// Reads [value] as a string, `''` when absent.
String stringFromJson(Object? value) => value?.toString() ?? '';

/// Reads [value] as a string, `null` when absent.
String? nullableStringFromJson(Object? value) => value?.toString();

/// Reads [value] as a trimmed string, `''` when absent.
String trimmedStringFromJson(Object? value) => stringFromJson(value).trim();

/// `code: label` maps; PHP encodes an empty associative array as `[]`
Map<String, String> paymentMethodsFromJson(Object? value) {
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), v.toString()));
  }
  return const {};
}
