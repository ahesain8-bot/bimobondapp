import 'package:flutter/material.dart';

/// Width ÷ height of the shared video box when more than one person is on
/// stage, matched to the TikTok reference: the two feeds sit side by side in a
/// landscape-ish box under the header rather than filling the screen.
const double kStageAspect = 1.35;

/// The most of the space below the header the stage may claim, so the chat
/// feed and the bottom bars always keep room on a short screen.
const double kStageMaxHeightFactor = 0.52;

/// Gap between stage tiles.
const double kStageTileGap = 2;

/// Corner radius of a stage tile.
const double kStageTileRadius = 6;

class StageTiles extends StatelessWidget {
  const StageTiles({super.key, required this.tiles});

  /// Host first, then one per guest.
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    // Local override only: the host holds the first tile on the LEFT, the way
    // the reference lays it out. Left to itself the Row mirrors in Arabic and
    // the two feeds swap sides.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: tiles.length <= 3
          ? _TileRow(tiles: tiles)
          : Column(
              children: [
                Expanded(child: _TileRow(tiles: _topRow)),
                const SizedBox(height: kStageTileGap),
                Expanded(child: _TileRow(tiles: _bottomRow)),
              ],
            ),
    );
  }

  /// Splits 4+ tiles so the wider row comes first — a 5-up reads as 3 over 2,
  /// never as 2 over 3 with a stretched pair underneath.
  List<Widget> get _topRow => tiles.take((tiles.length / 2).ceil()).toList();

  List<Widget> get _bottomRow => tiles.skip((tiles.length / 2).ceil()).toList();
}

class _TileRow extends StatelessWidget {
  const _TileRow({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: kStageTileGap),
          Expanded(child: tiles[i]),
        ],
      ],
    );
  }
}
