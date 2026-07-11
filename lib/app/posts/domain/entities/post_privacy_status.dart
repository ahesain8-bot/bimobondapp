/// Post visibility — matches backend `PostPrivacyStatus`.
enum PostPrivacyStatus {
  public('PUBLIC'),
  friends('FRIENDS');

  const PostPrivacyStatus(this.value);

  final String value;

  static PostPrivacyStatus? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final normalized = raw.trim().toUpperCase();
    for (final status in PostPrivacyStatus.values) {
      if (status.value == normalized) return status;
    }
    return null;
  }
}
