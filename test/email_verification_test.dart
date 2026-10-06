import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/auth_service.dart';

class _Provider extends Fake implements UserInfo {
  @override
  final String providerId;
  _Provider(this.providerId);
}

class _User extends Fake implements User {
  @override
  final bool emailVerified;
  final List<String> providers;
  _User(this.emailVerified, this.providers);
  @override
  List<UserInfo> get providerData => providers.map(_Provider.new).toList();
}

void main() {
  test('Only unverified password accounts require verification', () {
    expect(AuthService.needsEmailVerification(null), false);
    expect(
      AuthService.needsEmailVerification(_User(false, ['password'])),
      true,
    );
    expect(
      AuthService.needsEmailVerification(_User(true, ['password'])),
      false,
    );
    expect(
      AuthService.needsEmailVerification(_User(false, ['google.com'])),
      false,
    );
    expect(
      AuthService.needsEmailVerification(
        _User(false, ['password', 'google.com']),
      ),
      false,
    );
  });
}
