import 'package:flutter_test/flutter_test.dart';

import 'package:bimobondapp/features/live/presentation/bloc/live_room/live_room_event.dart';
import 'package:bimobondapp/features/live_viewer/presentation/bloc/live_viewer/live_viewer_event.dart';

void main() {
  test('host P2 enrich is a dedicated event (does not block publish handler)', () {
    const event = LiveRoomEnrichSessionRequested();
    expect(event, isA<LiveRoomEvent>());
  });

  test('viewer P2 HUD enrich carries session generation for race guards', () {
    const event = LiveViewerHudEnrichRequested(
      liveId: 'live-1',
      sessionGeneration: 3,
    );
    expect(event.liveId, 'live-1');
    expect(event.sessionGeneration, 3);
    expect(
      event,
      equals(
        const LiveViewerHudEnrichRequested(
          liveId: 'live-1',
          sessionGeneration: 3,
        ),
      ),
    );
    expect(
      event,
      isNot(
        equals(
          const LiveViewerHudEnrichRequested(
            liveId: 'live-1',
            sessionGeneration: 4,
          ),
        ),
      ),
    );
  });
}
