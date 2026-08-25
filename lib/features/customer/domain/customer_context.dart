class CustomerContextPayload {
  const CustomerContextPayload({required this.customer});

  final CustomerContext customer;

  factory CustomerContextPayload.fromJson(Map<String, dynamic> json) {
    return CustomerContextPayload(
      customer: CustomerContext.fromJson(
        Map<String, dynamic>.from(
          json['customer'] as Map? ?? const <String, dynamic>{},
        ),
      ),
    );
  }
}

class CustomerContext {
  const CustomerContext({
    required this.user,
    required this.profile,
    required this.customer,
  });

  final CustomerUser user;
  final CustomerProfile profile;
  final CustomerRecord customer;

  factory CustomerContext.fromJson(Map<String, dynamic> json) {
    return CustomerContext(
      user: CustomerUser.fromJson(
        Map<String, dynamic>.from(
          json['user'] as Map? ?? const <String, dynamic>{},
        ),
      ),
      profile: CustomerProfile.fromJson(
        Map<String, dynamic>.from(
          json['profile'] as Map? ?? const <String, dynamic>{},
        ),
      ),
      customer: CustomerRecord.fromJson(
        Map<String, dynamic>.from(
          json['customer'] as Map? ?? const <String, dynamic>{},
        ),
      ),
    );
  }
}

class CustomerUser {
  const CustomerUser({required this.id, required this.email});

  final String id;
  final String email;

  factory CustomerUser.fromJson(Map<String, dynamic> json) {
    return CustomerUser(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
    );
  }
}

class CustomerProfile {
  const CustomerProfile({
    required this.id,
    required this.fullName,
    required this.email,
  });

  final String id;
  final String? fullName;
  final String? email;

  factory CustomerProfile.fromJson(Map<String, dynamic> json) {
    return CustomerProfile(
      id: json['id'] as String? ?? '',
      fullName: json['fullName'] as String?,
      email: json['email'] as String?,
    );
  }
}

class CustomerRecord {
  const CustomerRecord({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.marketingOptIn,
  });

  final String id;
  final String? fullName;
  final String? email;
  final String? phone;
  final bool marketingOptIn;

  factory CustomerRecord.fromJson(Map<String, dynamic> json) {
    return CustomerRecord(
      id: json['id'] as String? ?? '',
      fullName: json['fullName'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      marketingOptIn: json['marketingOptIn'] as bool? ?? false,
    );
  }
}
