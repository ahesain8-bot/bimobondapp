import 'dart:convert';

import 'package:livekit_client/livekit_client.dart';

/// Matches a backend user id to the identity carried by a LiveKit token.
///
/// Production tokens normally use the backend id directly, but older tokens
/// used a prefixed identity or placed the user id in participant attributes.
/// A strict equality check made those valid guest camera tracks invisible.
bool liveKitParticipantMatches(
  RemoteParticipant participant,
  String expectedUserId,
) {
  final expected = expectedUserId.trim().toLowerCase();
  if (expected.isEmpty) return false;

  final identity = participant.identity.trim().toLowerCase();
  if (identity == expected ||
      identity.endsWith(':$expected') ||
      identity.endsWith('/$expected') ||
      identity.endsWith('|$expected')) {
    return true;
  }

  const identityKeys = {'userid', 'user_id', 'sub', 'uid'};
  for (final entry in participant.attributes.entries) {
    if (identityKeys.contains(entry.key.toLowerCase()) &&
        entry.value.trim().toLowerCase() == expected) {
      return true;
    }
  }

  final metadata = participant.metadata;
  if (metadata == null || metadata.isEmpty) return false;
  try {
    final decoded = jsonDecode(metadata);
    if (decoded is Map) {
      for (final entry in decoded.entries) {
        if (identityKeys.contains(entry.key.toString().toLowerCase()) &&
            entry.value?.toString().trim().toLowerCase() == expected) {
          return true;
        }
      }
    }
  } catch (_) {
    // Participant metadata is opaque and is not guaranteed to be JSON.
  }
  return false;
}
