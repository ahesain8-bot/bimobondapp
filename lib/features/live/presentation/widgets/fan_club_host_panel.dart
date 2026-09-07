import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/fan_club.dart';

/// Host-side club management: enable, rename, set the BASIC price, and add an
/// emote with its minimum tier.
///
/// The price the host types is sent as `priceCoins` on
/// `PATCH /creators/:id/fan-club`; the app does not compute the PLUS/PREMIUM
/// multiples, the server owns those.
class FanClubHostPanel extends StatefulWidget {
  const FanClubHostPanel({
    required this.club,
    required this.busy,
    required this.onSave,
    required this.onAddEmote,
    super.key,
  });

  final FanClub club;
  final bool busy;
  final void Function({bool? enabled, String? name, int? priceCoins}) onSave;
  final void Function({
    required String code,
    required String imageUrl,
    String? minTier,
  })
  onAddEmote;

  @override
  State<FanClubHostPanel> createState() => _FanClubHostPanelState();
}

class _FanClubHostPanelState extends State<FanClubHostPanel> {
  late final TextEditingController _name = TextEditingController(
    text: widget.club.name,
  );
  late final TextEditingController _price = TextEditingController(
    text: widget.club.priceCoins?.toString() ?? '',
  );
  late bool _enabled = widget.club.enabled;

  @override
  void didUpdateWidget(covariant FanClubHostPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only follow the server when the host is not mid-edit on that field.
    if (oldWidget.club.name != widget.club.name &&
        _name.text == oldWidget.club.name) {
      _name.text = widget.club.name;
    }
    final oldPrice = oldWidget.club.priceCoins?.toString() ?? '';
    if (oldWidget.club.priceCoins != widget.club.priceCoins &&
        _price.text == oldPrice) {
      _price.text = widget.club.priceCoins?.toString() ?? '';
    }
    if (oldWidget.club.enabled != widget.club.enabled) {
      _enabled = widget.club.enabled;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.liveFanClubHostSettings,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _enabled,
            title: Text(
              l.liveFanClubHostEnabled,
              style: const TextStyle(fontSize: 13, color: Colors.black),
            ),
            onChanged: widget.busy
                ? null
                : (value) => setState(() => _enabled = value),
          ),
          TextField(
            controller: _name,
            maxLength: 40,
            decoration: InputDecoration(
              labelText: l.liveFanClubHostName,
              counterText: '',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _price,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: l.liveFanClubHostPrice),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: widget.busy ? null : _save,
            child: Text(l.liveFanClubSave),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: widget.busy ? null : _openAddEmote,
            icon: const Icon(Icons.add_reaction_outlined, size: 18),
            label: Text(l.liveFanClubAddEmote),
          ),
        ],
      ),
    );
  }

  void _save() {
    final name = _name.text.trim();
    final rawPrice = _price.text.trim();
    final price = rawPrice.isEmpty ? null : int.tryParse(rawPrice);
    widget.onSave(
      enabled: _enabled == widget.club.enabled ? null : _enabled,
      name: name.isEmpty || name == widget.club.name ? null : name,
      priceCoins: price == widget.club.priceCoins ? null : price,
    );
  }

  Future<void> _openAddEmote() async {
    final l = AppLocalizations.of(context)!;
    final code = TextEditingController();
    final image = TextEditingController();
    var minTier = FanClubTierSlug.basic;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, update) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l.liveFanClubAddEmote,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: code,
                  maxLength: 24,
                  decoration: InputDecoration(
                    labelText: l.liveFanClubEmoteCode,
                    counterText: '',
                  ),
                ),
                TextField(
                  controller: image,
                  decoration: InputDecoration(
                    labelText: l.liveFanClubEmoteImage,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(l.liveFanClubEmoteMinTier),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        children: [
                          for (final slug in FanClubTierSlug.ordered)
                            ChoiceChip(
                              label: Text(slug),
                              selected: minTier == slug,
                              onSelected: (_) => update(() => minTier = slug),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  child: Text(l.liveFanClubSave),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final emoteCode = code.text.trim();
    final emoteImage = image.text.trim();
    code.dispose();
    image.dispose();
    if (saved != true || emoteCode.isEmpty || emoteImage.isEmpty) return;
    widget.onAddEmote(
      code: emoteCode,
      imageUrl: emoteImage,
      minTier: minTier,
    );
  }
}
