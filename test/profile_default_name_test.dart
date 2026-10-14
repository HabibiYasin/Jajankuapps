import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/auth_service.dart';

void main() {
  test('Google accounts use the Google name', () {
    expect(
      AuthService.resolveProfileName(
        googleName: '  Budi Santoso  ',
        email: 'budi@gmail.com',
      ),
      'Budi Santoso',
    );
  });

  test('Email accounts use the local part for any provider', () {
    for (final domain in [
      'gmail.com',
      'yahoo.com',
      'outlook.com',
      'company.id',
    ]) {
      expect(
        AuthService.resolveProfileName(email: 'budi.santoso@$domain'),
        'budi.santoso',
      );
    }
  });

  test('Empty saved names fall back and edited names survive login', () {
    expect(
      AuthService.resolveProfileName(savedName: '  ', email: 'budi@yahoo.com'),
      'budi',
    );
    expect(
      AuthService.resolveProfileName(
        savedName: 'Nama Pilihan',
        googleName: 'Budi Santoso',
        email: 'budi@gmail.com',
      ),
      'Nama Pilihan',
    );
  });
}
