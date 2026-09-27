/// Returns a safe HTTPS avatar URL from the OAuth user metadata.
///
/// Google may expose the same profile photo under `picture` or `avatar_url`,
/// depending on the provider/session version.
String? profileAvatarUrl(Map<String, dynamic>? metadata) {
  if (metadata == null) return null;
  for (final key in const ['picture', 'avatar_url']) {
    final value = metadata[key];
    if (value is! String || value.length > 2048) continue;
    final uri = Uri.tryParse(value);
    if (uri?.scheme == 'https' && uri!.host.isNotEmpty) return value;
  }
  return null;
}
