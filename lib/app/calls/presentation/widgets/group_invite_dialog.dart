import 'package:bimobondapp/app/calls/presentation/bloc/call_bloc.dart';
import 'package:bimobondapp/app/calls/presentation/bloc/call_event.dart';
import 'package:bimobondapp/core/utils/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class GroupInviteDialog extends StatefulWidget {
  final String callId;
  final List<Map<String, dynamic>> availableMembers;

  const GroupInviteDialog({
    super.key,
    required this.callId,
    this.availableMembers = const [],
  });

  @override
  State<GroupInviteDialog> createState() => _GroupInviteDialogState();
}

class _GroupInviteDialogState extends State<GroupInviteDialog> {
  final Set<String> _selectedUserIds = {};
  final TextEditingController _customUserIdController =
      TextEditingController();

  @override
  void dispose() {
    _customUserIdController.dispose();
    super.dispose();
  }

  void _onInvite() {
    final ids = List<String>.from(_selectedUserIds);
    final customId = _customUserIdController.text.trim();
    if (customId.isNotEmpty && !ids.contains(customId)) {
      ids.add(customId);
    }

    if (ids.isEmpty) return;

    context.read<CallBloc>().add(
          InviteToCallEvent(
            callId: widget.callId,
            inviteeIds: ids,
          ),
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Invite to Call',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(LucideIcons.x, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.availableMembers.isNotEmpty) ...[
              const Text(
                'Select chat members:',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.availableMembers.length,
                  itemBuilder: (context, index) {
                    final member = widget.availableMembers[index];
                    final userId = member['id']?.toString() ?? '';
                    final username = member['username']?.toString() ?? 'User';
                    final isSelected = _selectedUserIds.contains(userId);

                    return CheckboxListTile(
                      activeColor: AppColors.primary,
                      title: Text(
                        username,
                        style: const TextStyle(color: Colors.white),
                      ),
                      value: isSelected,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedUserIds.add(userId);
                          } else {
                            _selectedUserIds.remove(userId);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _customUserIdController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter User ID to invite',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(LucideIcons.userPlus, color: Colors.white54),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _onInvite,
                child: const Text(
                  'Send Invite',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
