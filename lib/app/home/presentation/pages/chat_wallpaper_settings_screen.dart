import 'package:bimobondapp/core/constants/settings_layout_constants.dart';
import 'package:bimobondapp/core/theme/chat_theme.dart';
import 'package:bimobondapp/core/theme/cubit/chat_wallpaper_cubit.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:bimobondapp/core/widgets/custom_app_bar.dart';
import 'package:bimobondapp/core/widgets/custom_loading_widget.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class BackendWallpaperAsset {
  final String id;
  final String name;
  final String imageUrl;
  final String? thumbnailUrl;
  final int sortOrder;

  BackendWallpaperAsset({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.thumbnailUrl,
    this.sortOrder = 0,
  });

  factory BackendWallpaperAsset.fromJson(Map<String, dynamic> json) {
    return BackendWallpaperAsset(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Wallpaper',
      imageUrl: json['imageUrl']?.toString() ?? '',
      thumbnailUrl: json['thumbnailUrl']?.toString(),
      sortOrder:
          json['sortOrder'] is num ? (json['sortOrder'] as num).toInt() : 0,
    );
  }
}

class ChatWallpaperSettingsScreen extends StatefulWidget {
  final String? chatId;
  final String? currentWallpaperUrl;
  final String? currentWallpaperAssetId;

  const ChatWallpaperSettingsScreen({
    super.key,
    this.chatId,
    this.currentWallpaperUrl,
    this.currentWallpaperAssetId,
  });

  @override
  State<ChatWallpaperSettingsScreen> createState() =>
      _ChatWallpaperSettingsScreenState();
}

class _ChatWallpaperSettingsScreenState
    extends State<ChatWallpaperSettingsScreen> {
  List<BackendWallpaperAsset> _backendWallpapers = [];
  bool _isLoadingBackend = true;
  bool _isUpdatingWallpaper = false;
  String? _selectedAssetId;
  String? _updatingAssetId;

  @override
  void initState() {
    super.initState();
    final cubitState = context.read<ChatWallpaperCubit>().state;
    final activeUrl =
        widget.currentWallpaperUrl ?? cubitState.activeWallpaperUrl;
    _selectedAssetId = widget.currentWallpaperAssetId;
    _fetchBackendWallpapers(activeUrl);
  }

  Future<void> _fetchBackendWallpapers(String? activeUrl) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final dio = Dio(
        BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': ApiConstants.apiKey,
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );

      final response = await dio.get(ApiConstants.chatWallpapersCatalog);
      if (response.statusCode == 200 && response.data is List) {
        final list = (response.data as List)
            .map((e) => BackendWallpaperAsset.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList();

        String? matchedAssetId = _selectedAssetId;
        if (matchedAssetId == null &&
            activeUrl != null &&
            activeUrl.trim().isNotEmpty) {
          final trimmedUrl = activeUrl.trim();
          for (final asset in list) {
            if (asset.imageUrl == trimmedUrl ||
                asset.thumbnailUrl == trimmedUrl ||
                (asset.imageUrl.isNotEmpty &&
                    trimmedUrl.contains(asset.imageUrl)) ||
                (asset.id.isNotEmpty && trimmedUrl.contains(asset.id))) {
              matchedAssetId = asset.id;
              break;
            }
          }
        }

        if (mounted) {
          setState(() {
            _backendWallpapers = list;
            _selectedAssetId = matchedAssetId;
            _isLoadingBackend = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingBackend = false);
      }
    } catch (e) {
      debugPrint(
          'ChatWallpaperSettingsScreen: error fetching backend wallpapers: $e');
      if (mounted) setState(() => _isLoadingBackend = false);
    }
  }

  void _showImageSourcePicker() {
    final theme = Theme.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.camera,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                ),
                title: Text(
                  isArabic ? 'الكاميرا' : 'Camera',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  isArabic
                      ? 'التقط صورة جديدة بالكاميرا'
                      : 'Take a new photo with camera',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _uploadCustomDeviceWallpaper(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.image,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                ),
                title: Text(
                  isArabic ? 'استوديو الصور' : 'Studio / Photos',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  isArabic
                      ? 'اختر صورة من الاستوديو'
                      : 'Choose from studio gallery',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _uploadCustomDeviceWallpaper(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _uploadCustomDeviceWallpaper(ImageSource source) async {
    if (_isUpdatingWallpaper) return;
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile == null || !mounted) return;

      setState(() {
        _isUpdatingWallpaper = true;
        _updatingAssetId = 'custom_device_upload';
      });

      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final dio = Dio(
        BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          headers: {
            'x-api-key': ApiConstants.apiKey,
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(pickedFile.path),
      });

      String? uploadedUrl;

      // 1. Primary: Upload directly via POST /chats/:id/personal-wallpaper/upload if chatId is provided
      if (widget.chatId != null && widget.chatId!.isNotEmpty) {
        try {
          final res = await dio.post(
            ApiConstants.chatPersonalWallpaperUpload(widget.chatId!),
            data: formData,
          );
          if (res.data is Map) {
            uploadedUrl = res.data['personalWallpaperUrl']?.toString() ??
                res.data['wallpaperUrl']?.toString() ??
                res.data['url']?.toString();
          }
        } catch (e) {
          debugPrint('Error uploading via chatPersonalWallpaperUpload: $e');
        }
      }

      // 2. Fallback: Upload to general media upload endpoint first then patch
      if (uploadedUrl == null || uploadedUrl.isEmpty) {
        try {
          final uploadRes = await dio.post(
            ApiConstants.uploadMedia,
            data: formData,
          );
          if (uploadRes.statusCode == 200 || uploadRes.statusCode == 201) {
            if (uploadRes.data is Map) {
              uploadedUrl = uploadRes.data['url']?.toString() ??
                  uploadRes.data['mediaUrl']?.toString() ??
                  uploadRes.data['path']?.toString();
            }
          }
        } catch (e) {
          debugPrint('Error uploading image file to media endpoint: $e');
        }

        if (uploadedUrl != null &&
            uploadedUrl.isNotEmpty &&
            widget.chatId != null &&
            widget.chatId!.isNotEmpty) {
          try {
            await dio.patch(
              ApiConstants.chatPersonalWallpaper(widget.chatId!),
              data: {'wallpaperUrl': uploadedUrl},
            );
          } catch (_) {
            await dio.patch(
              ApiConstants.chatWallpaper(widget.chatId!),
              data: {'wallpaperUrl': uploadedUrl},
            );
          }
        }
      }

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        if (widget.chatId == null || widget.chatId!.isEmpty) {
          if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
            context.read<ChatWallpaperCubit>().setNetworkWallpaper(uploadedUrl);
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.chatWallpaperUpdated),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(uploadedUrl);
      }
    } catch (e) {
      debugPrint('Error uploading custom wallpaper: $e');
      if (mounted) {
        setState(() {
          _isUpdatingWallpaper = false;
          _updatingAssetId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload wallpaper: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _applyWallpaperToChat(
      String? assetId, String? wallpaperUrl) async {
    if (_isUpdatingWallpaper) return;

    setState(() {
      _isUpdatingWallpaper = true;
      _updatingAssetId = assetId;
      _selectedAssetId = assetId;
    });

    if (mounted && (widget.chatId == null || widget.chatId!.isEmpty)) {
      context.read<ChatWallpaperCubit>().setNetworkWallpaper(wallpaperUrl);
    }

    if (widget.chatId != null && widget.chatId!.isNotEmpty) {
      try {
        final token = await FirebaseAuth.instance.currentUser?.getIdToken();
        final dio = Dio(
          BaseOptions(
            baseUrl: ApiConstants.baseUrl,
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': ApiConstants.apiKey,
              if (token != null) 'Authorization': 'Bearer $token',
            },
          ),
        );

        if (assetId == null && wallpaperUrl == null) {
          // DELETE /chats/:id/personal-wallpaper (Reset to default)
          try {
            await dio.delete(
              ApiConstants.chatPersonalWallpaper(widget.chatId!),
            );
          } catch (_) {
            await dio.patch(
              ApiConstants.chatWallpaper(widget.chatId!),
              data: {'wallpaperAssetId': null, 'wallpaperUrl': null},
            );
          }
        } else {
          // PATCH /chats/:id/personal-wallpaper { "wallpaperAssetId": assetId }
          final Map<String, dynamic> patchData = {};
          if (assetId != null && assetId.isNotEmpty) {
            patchData['wallpaperAssetId'] = assetId;
          }
          if (wallpaperUrl != null && wallpaperUrl.isNotEmpty) {
            patchData['wallpaperUrl'] = wallpaperUrl;
          }

          try {
            await dio.patch(
              ApiConstants.chatPersonalWallpaper(widget.chatId!),
              data: patchData,
            );
          } catch (_) {
            await dio.patch(
              ApiConstants.chatWallpaper(widget.chatId!),
              data: patchData,
            );
          }
        }

        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.chatWallpaperUpdated),
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).pop(wallpaperUrl);
        }
      } catch (e) {
        debugPrint(
            'ChatWallpaperSettingsScreen: error updating chat wallpaper: $e');
        if (mounted) {
          setState(() {
            _isUpdatingWallpaper = false;
            _updatingAssetId = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update wallpaper: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } else {
      if (mounted) {
        Navigator.of(context).pop(wallpaperUrl);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final chatTheme = ChatTheme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: CustomAppBar(
        title: l10n.chatWallpaperTitle,
        showBackButton: !_isUpdatingWallpaper,
        onBackPressed: () => Navigator.of(context).pop(),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: SettingsLayoutConstants.horizontalPadding,
          vertical: SettingsLayoutConstants.bodyVerticalPadding,
        ),
        children: [
          CustomText(
            l10n.chatWallpaperSubtitle,
            variant: TextVariant.secondary,
            fontSize: SettingsLayoutConstants.trailingFontSize,
          ),
          const SizedBox(height: SettingsLayoutConstants.groupSpacing),

          // Upload Custom Device Photo Tile
          Padding(
            padding: const EdgeInsets.only(
              bottom: SettingsLayoutConstants.sheetItemSpacing,
            ),
            child: Material(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(
                SettingsLayoutConstants.groupRadius,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(
                  SettingsLayoutConstants.groupRadius,
                ),
                onTap: _isUpdatingWallpaper
                    ? null
                    : _showImageSourcePicker,
                child: Padding(
                  padding: const EdgeInsets.all(
                    SettingsLayoutConstants.tileHorizontalPadding,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            SettingsLayoutConstants.iconContainerRadius,
                          ),
                        ),
                        child: Icon(
                          LucideIcons.imagePlus,
                          size: 28,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(
                        width: SettingsLayoutConstants.sheetItemSpacing,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomText(
                              l10n.chatWallpaperChooseFromPhotos,
                              fontSize:
                                  SettingsLayoutConstants.itemTitleFontSize,
                              fontWeight: FontWeight.w600,
                            ),
                            const SizedBox(height: 2),
                            CustomText(
                              l10n.chatWallpaperUploadDeviceSubtitle,
                              variant: TextVariant.secondary,
                              fontSize: 12,
                            ),
                          ],
                        ),
                      ),
                      if (_isUpdatingWallpaper &&
                          _updatingAssetId == 'custom_device_upload')
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Default (No Wallpaper) Tile
          Padding(
            padding: const EdgeInsets.only(
              bottom: SettingsLayoutConstants.sheetItemSpacing,
            ),
            child: Material(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(
                SettingsLayoutConstants.groupRadius,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(
                  SettingsLayoutConstants.groupRadius,
                ),
                onTap: _isUpdatingWallpaper
                    ? null
                    : () => _applyWallpaperToChat(null, null),
                child: Padding(
                  padding: const EdgeInsets.all(
                    SettingsLayoutConstants.tileHorizontalPadding,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: chatTheme.chatBackgroundColor,
                          borderRadius: BorderRadius.circular(
                            SettingsLayoutConstants.iconContainerRadius,
                          ),
                        ),
                        child: const Icon(LucideIcons.imageOff, size: 28),
                      ),
                      const SizedBox(
                        width: SettingsLayoutConstants.sheetItemSpacing,
                      ),
                      Expanded(
                        child: CustomText(
                          l10n.chatWallpaperDefault,
                          fontSize: SettingsLayoutConstants.itemTitleFontSize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_isUpdatingWallpaper && _updatingAssetId == null)
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: theme.colorScheme.primary,
                          ),
                        )
                      else if (_selectedAssetId == null)
                        Icon(
                          LucideIcons.circleCheck,
                          color: theme.colorScheme.primary,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Backend Wallpapers Section Header
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: CustomText(
              l10n.chatWallpaperCatalog,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_isLoadingBackend)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: CustomLoadingWidget(size: 48),
              ),
            )
          else
            ..._backendWallpapers.map((wallpaper) {
              final isSelected = _selectedAssetId == wallpaper.id;
              final isTargetUpdating =
                  _isUpdatingWallpaper && _updatingAssetId == wallpaper.id;
              final rawUrl = wallpaper.thumbnailUrl ?? wallpaper.imageUrl;
              final formattedUrl = rawUrl.startsWith('http')
                  ? rawUrl
                  : '${ApiConstants.baseUrl}$rawUrl';

              return Padding(
                padding: const EdgeInsets.only(
                  bottom: SettingsLayoutConstants.sheetItemSpacing,
                ),
                child: Material(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(
                    SettingsLayoutConstants.groupRadius,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(
                      SettingsLayoutConstants.groupRadius,
                    ),
                    onTap: _isUpdatingWallpaper
                        ? null
                        : () => _applyWallpaperToChat(
                            wallpaper.id, wallpaper.imageUrl),
                    child: Padding(
                      padding: const EdgeInsets.all(
                        SettingsLayoutConstants.tileHorizontalPadding,
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              SettingsLayoutConstants.iconContainerRadius,
                            ),
                            child: SizedBox(
                              width: 72,
                              height: 72,
                              child: Image.network(
                                formattedUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  color: theme.dividerColor,
                                  child: const Icon(LucideIcons.image),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: SettingsLayoutConstants.sheetItemSpacing,
                          ),
                          Expanded(
                            child: CustomText(
                              wallpaper.name,
                              fontSize:
                                  SettingsLayoutConstants.itemTitleFontSize,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (isTargetUpdating)
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: theme.colorScheme.primary,
                              ),
                            )
                          else if (isSelected)
                            Icon(
                              LucideIcons.circleCheck,
                              color: theme.colorScheme.primary,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
