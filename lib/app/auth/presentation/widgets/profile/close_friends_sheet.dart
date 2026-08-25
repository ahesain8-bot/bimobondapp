import 'package:bimobondapp/app/auth/data/datasources/profile_remote_data_source.dart';
import 'package:bimobondapp/app/social/domain/entities/social_list_query.dart';
import 'package:bimobondapp/app/social/domain/entities/social_user_entity.dart';
import 'package:bimobondapp/app/social/domain/usecases/social_user_list_usecases.dart';
import 'package:bimobondapp/app/social/presentation/di/social_injector.dart' as social_di;
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class CloseFriendsSheet extends StatefulWidget {
  const CloseFriendsSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CloseFriendsSheet(),
    );
  }

  @override
  State<CloseFriendsSheet> createState() => _CloseFriendsSheetState();
}

class _CloseFriendsSheetState extends State<CloseFriendsSheet> {
  final ProfileRemoteDataSource _remoteDS = ProfileRemoteDataSourceImpl();
  final TextEditingController _searchController = TextEditingController();

  int _selectedTab = 0; // 0: Close Friends, 1: Add Friends
  List<Map<String, dynamic>> _closeFriends = [];
  List<SocialUserEntity> _allFriends = [];
  bool _isLoading = true;
  bool _isLoadingFriends = false;
  String _searchQuery = '';
  final Set<String> _addingIds = {};

  @override
  void initState() {
    super.initState();
    _loadCloseFriends();
    _loadAllFriends();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCloseFriends() async {
    setState(() => _isLoading = true);
    final list = await _remoteDS.getCloseFriends();
    if (mounted) {
      setState(() {
        _closeFriends = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAllFriends() async {
    setState(() => _isLoadingFriends = true);
    try {
      final result = await social_di.sl<GetMyFriendsUseCase>()(
        const SocialListQuery(page: 1, limit: 100),
      );
      result.fold(
        (_) {},
        (pageData) {
          if (mounted) {
            setState(() {
              _allFriends = pageData.users;
              _isLoadingFriends = false;
            });
          }
        },
      );
    } catch (_) {
      if (mounted) setState(() => _isLoadingFriends = false);
    }
  }

  bool _isCloseFriend(String userId) {
    return _closeFriends.any((item) {
      final id = (item['memberId'] ??
              item['id'] ??
              item['userId'] ??
              (item['user'] is Map ? item['user']['id'] : null))
          ?.toString();
      return id == userId;
    });
  }

  Future<void> _addCloseFriend(String userId, String name) async {
    if (_addingIds.contains(userId)) return;
    setState(() => _addingIds.add(userId));
    try {
      await _remoteDS.addCloseFriend(userId);
      await _loadCloseFriends();
      if (mounted) {
        PopupDialogs.showSuccessDialog(context, 'Added $name to close friends');
      }
    } catch (e) {
      if (mounted) {
        PopupDialogs.showErrorDialog(context, 'Failed to add: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _addingIds.remove(userId));
      }
    }
  }

  Future<void> _removeCloseFriend(String memberId, String name) async {
    try {
      await _remoteDS.removeCloseFriend(memberId);
      if (mounted) {
        setState(() {
          _closeFriends.removeWhere((item) {
            final id = (item['memberId'] ??
                    item['id'] ??
                    item['userId'] ??
                    (item['user'] is Map ? item['user']['id'] : null))
                ?.toString();
            return id == memberId;
          });
        });
        PopupDialogs.showSuccessDialog(context, 'Removed $name from close friends');
      }
    } catch (e) {
      if (mounted) {
        PopupDialogs.showErrorDialog(context, 'Failed to remove: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final filteredCloseFriends = _closeFriends.where((item) {
      if (_searchQuery.isEmpty) return true;
      final user = item['user'] is Map ? item['user'] : item;
      final name = (user['fullName'] ?? user['username'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    final filteredAllFriends = _allFriends.where((user) {
      if (_searchQuery.isEmpty) return true;
      final name = (user.fullName ?? user.username ?? '').toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      padding: EdgeInsets.only(
        left: AppSizes.p20,
        right: AppSizes.p20,
        top: AppSizes.p16,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSizes.p20,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSizes.p16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.star_rounded, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 10),
              CustomText(
                l10n.closeFriendsTab,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.p12),
          // Tab Toggle
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedTab == 0 ? cs.surface : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${l10n.closeFriendsTab} (${_closeFriends.length})',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: _selectedTab == 0 ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedTab == 1 ? cs.surface : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_rounded, size: 16, color: Color(0xFF10B981)),
                          const SizedBox(width: 4),
                          Text(
                            l10n.addCloseFriendsTitle,
                            style: TextStyle(
                              fontWeight: _selectedTab == 1 ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.p12),
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            decoration: InputDecoration(
              hintText: _selectedTab == 0 ? l10n.searchCloseFriendsHint : 'Search friends to add...',
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              filled: true,
              fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: AppSizes.p12),
          Expanded(
            child: _selectedTab == 0
                ? (_isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredCloseFriends.isEmpty
                        ? Center(
                            child: CustomText(
                              _searchQuery.isEmpty
                                  ? l10n.noCloseFriendsYet
                                  : 'No matching friends found.',
                              variant: TextVariant.secondary,
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredCloseFriends.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = filteredCloseFriends[index];
                              final userMap = item['user'] is Map ? Map<String, dynamic>.from(item['user'] as Map) : item;
                              final memberId = (item['memberId'] ?? item['id'] ?? item['userId'] ?? userMap['id'])?.toString() ?? '';
                              final name = (userMap['fullName'] ?? userMap['username'] ?? 'Friend').toString();
                              final username = (userMap['username'] ?? '').toString();
                              final avatarUrl = userMap['avatarUrl']?.toString();

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  radius: 20,
                                  backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                                      ? NetworkImage(avatarUrl)
                                      : null,
                                  child: (avatarUrl == null || avatarUrl.isEmpty)
                                      ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'U')
                                      : null,
                                ),
                                title: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.star_rounded, size: 10, color: Colors.white),
                                    ),
                                  ],
                                ),
                                subtitle: username.isNotEmpty
                                    ? CustomText(
                                        '@$username',
                                        variant: TextVariant.secondary,
                                        fontSize: 12,
                                      )
                                    : null,
                                trailing: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: cs.error.withValues(alpha: 0.5)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () => _removeCloseFriend(memberId, name),
                                  child: Text(
                                    'Remove',
                                    style: TextStyle(color: cs.error, fontSize: 12),
                                  ),
                                ),
                              );
                            },
                          ))
                : (_isLoadingFriends
                    ? const Center(child: CircularProgressIndicator())
                    : filteredAllFriends.isEmpty
                        ? Center(
                            child: CustomText(
                              _searchQuery.isEmpty
                                  ? 'No friends found.'
                                  : 'No matching friends found.',
                              variant: TextVariant.secondary,
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredAllFriends.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final user = filteredAllFriends[index];
                              final isAlready = _isCloseFriend(user.id);
                              final isAdding = _addingIds.contains(user.id);

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  radius: 20,
                                  backgroundImage: (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                                      ? NetworkImage(user.avatarUrl!)
                                      : null,
                                  child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                                      ? Text(user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : 'U')
                                      : null,
                                ),
                                title: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        user.displayName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isAlready) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF10B981),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.star_rounded, size: 10, color: Colors.white),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: user.username != null && user.username!.isNotEmpty
                                    ? CustomText(
                                        '@${user.username}',
                                        variant: TextVariant.secondary,
                                        fontSize: 12,
                                      )
                                    : null,
                                trailing: isAlready
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.check_rounded, size: 14, color: Color(0xFF10B981)),
                                            SizedBox(width: 4),
                                            Text(
                                              'Added',
                                              style: TextStyle(
                                                color: Color(0xFF10B981),
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: const Color(0xFF10B981),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        onPressed: isAdding
                                            ? null
                                            : () => _addCloseFriend(user.id, user.displayName),
                                        icon: isAdding
                                            ? const SizedBox(
                                                width: 12,
                                                height: 12,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                              )
                                            : const Icon(Icons.star_rounded, size: 14, color: Colors.white),
                                        label: const Text(
                                          'Add',
                                          style: TextStyle(fontSize: 12, color: Colors.white),
                                        ),
                                      ),
                              );
                            },
                          )),
          ),
        ],
      ),
    );
  }
}
