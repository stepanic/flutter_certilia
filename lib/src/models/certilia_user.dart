import 'package:flutter/foundation.dart';

/// Represents a Certilia user with their identity information
@immutable
class CertiliaUser {
  /// Unique identifier for the user
  final String sub;

  /// User's first name
  final String? firstName;

  /// User's last name
  final String? lastName;

  /// User's OIB (Croatian tax number)
  final String? oib;

  /// User's date of birth
  final DateTime? dateOfBirth;

  /// User's email address (if available)
  final String? email;

  /// Raw JSON response from the server
  final Map<String, dynamic> raw;

  /// Creates a new [CertiliaUser]
  const CertiliaUser({
    required this.sub,
    this.firstName,
    this.lastName,
    this.oib,
    this.dateOfBirth,
    this.email,
    required this.raw,
  });

  /// Creates a [CertiliaUser] from a JSON map
  factory CertiliaUser.fromJson(Map<String, dynamic> json) {
    return CertiliaUser(
      sub: json['sub'] as String,
      firstName: json['given_name'] as String? ?? json['firstName'] as String?,
      lastName: json['family_name'] as String? ?? json['lastName'] as String?,
      oib: json['oib'] as String?,
      dateOfBirth: _parseDate(json['birthdate'] as String?),
      email: json['email'] as String?,
      raw: Map<String, dynamic>.from(json),
    );
  }

  /// Parses a date string in YYYY-MM-DD format
  static DateTime? _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        return DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
      }
    } catch (_) {}
    return null;
  }

  /// Converts this user to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'sub': sub,
      if (firstName != null) 'given_name': firstName,
      if (lastName != null) 'family_name': lastName,
      if (oib != null) 'oib': oib,
      if (dateOfBirth != null)
        'birthdate':
            '${dateOfBirth!.year.toString().padLeft(4, '0')}-${dateOfBirth!.month.toString().padLeft(2, '0')}-${dateOfBirth!.day.toString().padLeft(2, '0')}',
      if (email != null) 'email': email,
      ...raw,
    };
  }

  /// Gets the user's full name
  String? get fullName {
    if (firstName == null && lastName == null) return null;
    return [firstName, lastName].where((s) => s != null).join(' ');
  }

  /// Creates a copy of this user with the given fields replaced
  CertiliaUser copyWith({
    String? sub,
    String? firstName,
    String? lastName,
    String? oib,
    DateTime? dateOfBirth,
    String? email,
    Map<String, dynamic>? raw,
  }) {
    return CertiliaUser(
      sub: sub ?? this.sub,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      oib: oib ?? this.oib,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      email: email ?? this.email,
      raw: raw ?? this.raw,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CertiliaUser &&
          runtimeType == other.runtimeType &&
          sub == other.sub &&
          firstName == other.firstName &&
          lastName == other.lastName &&
          oib == other.oib &&
          dateOfBirth == other.dateOfBirth &&
          email == other.email &&
          mapEquals(raw, other.raw);

  @override
  int get hashCode =>
      sub.hashCode ^
      firstName.hashCode ^
      lastName.hashCode ^
      oib.hashCode ^
      dateOfBirth.hashCode ^
      email.hashCode ^
      raw.hashCode;

  @override
  String toString() {
    return 'CertiliaUser('
        'sub: $sub, '
        'firstName: $firstName, '
        'lastName: $lastName, '
        'oib: $oib, '
        'dateOfBirth: $dateOfBirth, '
        'email: $email)';
  }
}