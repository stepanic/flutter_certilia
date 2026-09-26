/// Whether [value] is a valid Croatian OIB: 11 digits, the last of which is
/// the ISO 7064 MOD 11,10 check digit of the first ten.
bool isValidOib(String value) {
  if (!RegExp(r'^\d{11}$').hasMatch(value)) return false;
  var a = 10;
  for (var i = 0; i < 10; i++) {
    a = (a + value.codeUnitAt(i) - 48) % 10;
    if (a == 0) a = 10;
    a = (a * 2) % 11;
  }
  final check = (11 - a) % 10;
  return check == value.codeUnitAt(10) - 48;
}

/// The OIB in [claims]: an explicit `oib` or `pin` claim, otherwise `sub`
/// when it is a valid OIB. Certilia's portal clients use the OIB as the
/// subject (their subject claim is `pin`) and do not send `pin` itself.
String? oibFromClaims(Map<String, dynamic> claims) {
  final explicit = claims['oib'] ?? claims['pin'];
  if (explicit is String && explicit.isNotEmpty) return explicit;
  final sub = claims['sub'];
  return sub is String && isValidOib(sub) ? sub : null;
}
