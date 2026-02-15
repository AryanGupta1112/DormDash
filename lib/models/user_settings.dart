/// ----------------------------
/// UserSettings model
/// ----------------------------
class UserSettings {
  final bool pushEnabled;
  final String defaultPayment; // upi | cash | netbank
  final String displayName;

  const UserSettings({
    required this.pushEnabled,
    required this.defaultPayment,
    required this.displayName,
  });

  factory UserSettings.initial() =>
      const UserSettings(pushEnabled: true, defaultPayment: 'upi', displayName: '');

  Map<String, dynamic> toMap() => {
    'pushEnabled': pushEnabled,
    'defaultPayment': defaultPayment,
    'displayName': displayName,
  };

  factory UserSettings.fromMap(Map<String, dynamic>? m) {
    if (m == null) return UserSettings.initial();
    return UserSettings(
      pushEnabled: (m['pushEnabled'] as bool?) ?? true,
      defaultPayment: (m['defaultPayment'] as String?) ?? 'upi',
      displayName: (m['displayName'] as String?) ?? '',
    );
  }
}
