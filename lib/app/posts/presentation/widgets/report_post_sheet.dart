import 'package:flutter/material.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';

class ReportPostResult {
  const ReportPostResult({required this.reason, this.details});
  final String reason;
  final String? details;
}

class ReportPostBottomSheet extends StatefulWidget {
  const ReportPostBottomSheet({super.key});

  static Future<ReportPostResult?> show(BuildContext context) {
    final theme = Theme.of(context);
    return showModalBottomSheet<ReportPostResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const ReportPostBottomSheet(),
    );
  }

  @override
  State<ReportPostBottomSheet> createState() => _ReportPostBottomSheetState();
}

class _ReportPostBottomSheetState extends State<ReportPostBottomSheet> {
  static const List<String> reportReasonCodes = [
    'SPAM',
    'HARASSMENT',
    'HATE_SPEECH',
    'VIOLENCE',
    'NUDITY',
    'FALSE_INFO',
    'SCAM',
    'COPYRIGHT',
    'OTHER',
  ];

  String? _selectedReason;
  final TextEditingController _detailsController = TextEditingController();

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  String _labelForReason(AppLocalizations l10n, String code) {
    switch (code) {
      case 'SPAM':
        return l10n.postReportReasonSpam;
      case 'HARASSMENT':
        return l10n.postReportReasonHarassment;
      case 'HATE_SPEECH':
        return l10n.postReportReasonHateSpeech;
      case 'VIOLENCE':
        return l10n.postReportReasonViolence;
      case 'NUDITY':
        return l10n.postReportReasonNudity;
      case 'FALSE_INFO':
        return l10n.postReportReasonFalseInfo;
      case 'SCAM':
        return l10n.postReportReasonScam;
      case 'COPYRIGHT':
        return l10n.postReportReasonCopyright;
      case 'OTHER':
      default:
        return l10n.postReportReasonOther;
    }
  }

  void _submit() {
    if (_selectedReason == null) return;
    final detailsText = _detailsController.text.trim();
    Navigator.pop(
      context,
      ReportPostResult(
        reason: _selectedReason!,
        details: detailsText.isNotEmpty ? detailsText : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Text(
                  l10n.postReportTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  l10n.postReportMessage,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final code in reportReasonCodes)
                        ListTile(
                          title: Text(
                            _labelForReason(l10n, code),
                            style: theme.textTheme.bodyLarge,
                          ),
                          trailing: _selectedReason == code
                              ? Icon(
                                  Icons.check_circle_rounded,
                                  color: theme.colorScheme.primary,
                                )
                              : Icon(
                                  Icons.circle_outlined,
                                  color: theme.colorScheme.outline,
                                ),
                          onTap: () {
                            setState(() {
                              _selectedReason = code;
                            });
                          },
                        ),
                      if (_selectedReason == 'OTHER') ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          child: TextField(
                            controller: _detailsController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: l10n.postReportReasonOther,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.all(12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: _selectedReason != null ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(l10n.postOptionReport),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
