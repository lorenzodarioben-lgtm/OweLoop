import 'package:flutter_test/flutter_test.dart';
import 'package:oweloop/core/authentication/auth_redirects.dart';

void main() {
  test('uses a product-owned callback without credentials or tokens', () {
    expect(AuthRedirects.callback.toString(), 'oweloop://auth/callback');
    expect(AuthRedirects.callback.hasQuery, isFalse);
    expect(AuthRedirects.callback.hasFragment, isFalse);
  });
}
