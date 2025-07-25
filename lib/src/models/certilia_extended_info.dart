import 'package:flutter/foundation.dart';

/// Extended user information from Certilia API
@immutable
class CertiliaExtendedInfo {
  /// User information object containing all available fields
  final Map<String, dynamic> userInfo;
  
  /// List of available field names in the user info
  final List<String> availableFields;
  
  /// Token expiry time (if available)
  final DateTime? tokenExpiry;

  const CertiliaExtendedInfo({
    required this.userInfo,
    required this.availableFields,
    this.tokenExpiry,
  });

  /// Creates a [CertiliaExtendedInfo] from a JSON object
  factory CertiliaExtendedInfo.fromJson(Map<String, dynamic> json) {
    return CertiliaExtendedInfo(
      userInfo: json['userInfo'] as Map<String, dynamic>,
      availableFields: List<String>.from(json['availableFields'] ?? []),
      tokenExpiry: json['tokenExpiry'] != null 
          ? DateTime.parse(json['tokenExpiry']) 
          : null,
    );
  }

  /// Helper getters for common fields
  String? get sub => userInfo['sub'] as String?;
  String? get firstName => userInfo['given_name'] as String?;
  String? get lastName => userInfo['family_name'] as String?;
  String? get fullName => userInfo['name'] as String?;
  String? get email => userInfo['email'] as String?;
  String? get oib => userInfo['oib'] as String?;
  String? get dateOfBirth => userInfo['birthdate'] as String?;
  String? get gender => userInfo['gender'] as String?;
  String? get nationality => userInfo['nationality'] as String?;
  String? get placeOfBirth => userInfo['place_of_birth'] as String?;
  String? get countryOfBirth => userInfo['country_of_birth'] as String?;
  String? get documentNumber => userInfo['document_number'] as String?;
  String? get documentType => userInfo['document_type'] as String?;
  String? get issuingAuthority => userInfo['issuing_authority'] as String?;
  String? get dateOfIssue => userInfo['date_of_issue'] as String?;
  String? get dateOfExpiry => userInfo['date_of_expiry'] as String?;
  
  /// Address fields
  String? get address => userInfo['address'] as String?;
  String? get city => userInfo['city'] as String?;
  String? get postalCode => userInfo['postal_code'] as String?;
  String? get country => userInfo['country'] as String?;
  
  /// Get any field by key
  dynamic getField(String key) => userInfo[key];
  
  /// Check if a field exists
  bool hasField(String key) => userInfo.containsKey(key);

  @override
  String toString() {
    return 'CertiliaExtendedInfo(fields: ${availableFields.length}, tokenExpiry: $tokenExpiry)';
  }
}