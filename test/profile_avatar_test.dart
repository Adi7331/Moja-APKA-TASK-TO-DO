import 'package:dzien_po_dniu/profile_avatar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prefers the Google profile picture and accepts only HTTPS URLs', () {
    expect(
      profileAvatarUrl({
        'picture': 'https://lh3.googleusercontent.com/photo',
        'avatar_url': 'https://example.com/other-photo',
      }),
      'https://lh3.googleusercontent.com/photo',
    );
    expect(profileAvatarUrl({'picture': 'http://example.com/photo'}), isNull);
  });
}
