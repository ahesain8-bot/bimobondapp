import 'dart:async';
import 'dart:developer' as developer;

import 'package:bimobondapp/app/gifts/domain/entities/gift_entity.dart';
import 'package:bimobondapp/app/auth/domain/entities/user_entity.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/posts/domain/entities/comment_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/comments_bloc.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/comments_event.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/comments_state.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_bloc.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_event.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_state.dart';
import 'package:bimobondapp/app/posts/presentation/di/posts_injector.dart'
    as di;
import 'package:bimobondapp/app/posts/presentation/utils/post_view_recorder.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_auction_display_utils.dart';
import 'package:bimobondapp/core/constants/home_layout_constants.dart';
import 'package:bimobondapp/core/constants/live_details_layout_constants.dart';
import 'package:bimobondapp/core/constants/traffic_source.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/locale_format_utils.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/app/social/domain/entities/follow_status.dart';
import 'package:bimobondapp/app/social/domain/usecases/toggle_follow_usecase.dart';
import 'package:bimobondapp/app/social/presentation/di/social_injector.dart'
    as social_di;
import 'package:bimobondapp/app/auctions/data/datasources/auction_socket_service.dart';
import 'package:bimobondapp/app/auctions/domain/entities/auction_details_entity.dart';
import 'package:bimobondapp/app/auctions/domain/usecases/cancel_auction_usecase.dart';
import 'package:bimobondapp/app/auctions/domain/usecases/get_active_auctions_usecase.dart';
import 'package:bimobondapp/app/auctions/domain/usecases/get_auction_details_usecase.dart';
import 'package:bimobondapp/app/auctions/presentation/di/auctions_injector.dart'
    as auctions_di;
import 'package:bimobondapp/app/posts/domain/usecases/get_post_by_id_usecase.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:bimobondapp/app/auctions/presentation/widgets/auction_gifts_sheet.dart';
import 'package:bimobondapp/app/home/presentation/widgets/auctions/auction_search_filters.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/live_gift_sheet.dart';
import 'package:bimobondapp/app/home/presentation/widgets/live_details/auction_countdown_bar.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:bimobondapp/app/gifts/domain/repositories/gifts_repository.dart';
import 'package:bimobondapp/app/gifts/domain/usecases/get_gift_inventory_usecase.dart';
import 'package:bimobondapp/app/gifts/domain/usecases/get_gifts_usecase.dart';
import 'package:bimobondapp/app/gifts/domain/usecases/purchase_gift_usecase.dart';
import 'package:bimobondapp/app/gifts/domain/usecases/send_gift_usecase.dart';
import 'package:bimobondapp/app/gifts/presentation/di/gifts_injector.dart'
    as gifts_di;
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/app/home/presentation/widgets/live_details/auction_countdown_parts.dart';
import 'package:bimobondapp/app/gifts/presentation/utils/auction_audio_gift_chip_session.dart';
import 'package:bimobondapp/app/gifts/presentation/utils/auction_last_gift_parser.dart';
import 'package:bimobondapp/app/home/presentation/widgets/live_details/auction_price_with_audio_badge.dart';
import 'package:bimobondapp/app/home/presentation/widgets/live_details/gift_animation_overlay.dart';
import 'package:bimobondapp/app/home/presentation/widgets/live_details/live_bidding_input.dart';
import 'package:bimobondapp/app/home/presentation/widgets/live_details/live_chat_message.dart';
import 'package:bimobondapp/app/home/presentation/widgets/live_details/live_details_header.dart';
import 'package:bimobondapp/app/home/presentation/widgets/live_details/live_media_background.dart';
import 'package:bimobondapp/app/home/presentation/widgets/live_details/live_mock_chat_area.dart';
import 'package:bimobondapp/app/home/presentation/widgets/live_details/live_post_comments_area.dart';
import 'package:bimobondapp/core/utils/comment_sort.dart';
import 'package:bimobondapp/app/home/presentation/widgets/live_details/media_page_indicator.dart';
import 'package:bimobondapp/core/navigation/story_user_navigation.dart';
import 'package:bimobondapp/core/navigation/user_profile_navigation.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/post_options_sheet.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class LiveDetailsScreen extends StatefulWidget {
  final int index;
  final PostEntity? post;
  final bool embeddedInFeed;

  /// Real auction UUID when known from navigation (never the post id).
  final String? auctionId;

  /// Discovery surface for post view tracking — see [TrafficSource].
  final String trafficSource;

  /// When embedded in a vertical PageView, only the visible page should track.
  final bool isActive;

  const LiveDetailsScreen({
    super.key,
    this.index = 0,
    this.post,
    this.embeddedInFeed = false,
    this.auctionId,
    this.trafficSource = TrafficSource.live,
    this.isActive = true,
  });

  @override
  State<LiveDetailsScreen> createState() => _LiveDetailsScreenState();
}

class _LiveDetailsScreenState extends State<LiveDetailsScreen>
    with TickerProviderStateMixin {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final List<LiveChatMessage> _mockChatMessages = [];
  final List<CommentEntity> _postComments = [];
  CommentsBloc? _commentsBloc;
  final PageController _mediaPageController = PageController();
  int _currentImageIndex = 0;
  int _highestBid = LiveDetailsLayoutConstants.initialHighestBid;
  int? _giftContributionOverride;
  int? _startingPriceOverride;
  int? _targetPriceCoinsOverride;
  bool _isAuctionFinished = false;
  bool _isFollowing = false;
  bool _isFollowLoading = false;
  bool _isUIHidden = false;
  Timer? _countdownTimer;
  AuctionSocketService? _auctionSocket;
  StreamSubscription<AuctionUpdatedPayload>? _auctionUpdatedSub;
  StreamSubscription<CommentEntity>? _newCommentSub;
  StreamSubscription<GiftComboPayload>? _giftComboSub;
  StreamSubscription<bool>? _socketConnectionSub;
  String? _joinedAuctionId;
  String? _joinedPostId;
  String? _joinedLiveId;
  String? _lastGiftPlayedKey;
  DateTime? _lastGiftPlayedAt;

  /// Resolved auction UUID when `post.auction.id` is missing from feed payload.
  String? _resolvedAuctionId;
  String? _resolvedLiveId;
  Completer<String?>? _auctionIdResolveCompleter;
  final _audioGiftChipSession = AuctionAudioGiftChipSession();
  String? _ephemeralAudioGiftLabel;
  String? _ephemeralAudioGiftColor;
  final Map<String, GiftComboItem> _activeGiftCombos = {};
  final Map<String, Timer> _giftComboTimers = {};

  /// Full catalog keyed by gift id — used to resolve media for flat socket payloads.
  final Map<String, GiftEntity> _giftCatalogById = {};
  List<GiftEntity> _recommendedSmallGifts = _initialRecommendedSmallGifts;

  static const List<GiftEntity> _initialRecommendedSmallGifts = [];

  Future<void> _loadRecommendedSmallGifts() async {
    try {
      final getGifts = gifts_di.sl<GetGiftsUseCase>();
      final result = await getGifts(const GetGiftsParams());
      if (!mounted) return;
      result.fold((_) {}, (allGifts) {
        _giftCatalogById
          ..clear()
          ..addEntries(allGifts.map((g) => MapEntry(g.id, g)));
        final smalls = allGifts
            .where((g) => !g.isAudioGift && g.size == GiftCatalogSize.small)
            .toList();
        smalls.sort((a, b) => a.priceCoins.compareTo(b.priceCoins));
        if (mounted && smalls.isNotEmpty) {
          setState(() {
            _recommendedSmallGifts = smalls.take(8).toList();
          });
        }
      });
    } catch (_) {}
  }

  Future<void> _giftSendTaskChain = Future.value();

  /// Show the small gift combo card immediately on tap; socket updates the ×N later.
  void _showOptimisticSmallGiftCombo(GiftEntity gift) {
    if (!mounted) return;
    if (gift.isAudioGift || gift.size != GiftCatalogSize.small) return;

    final authState = context.read<AuthBloc>().state;
    final me = authState is AuthSuccess ? authState.user : null;
    if (me == null || me.id.isEmpty) return;

    final senderName =
        _displaySenderName(fullName: me.fullName, username: me.username) ??
        'User';
    final mediaUrl = gift.animationUrl?.trim().isNotEmpty == true
        ? gift.animationUrl!.trim()
        : (gift.displayImageUrl?.trim() ?? '');
    final comboKey = '${me.id}_${gift.id}';
    final existing = _activeGiftCombos[comboKey];
    final nextCombo = (existing?.combo ?? 0) + 1;

    _updateOrAddGiftCombo(
      giftId: gift.id,
      giftName: gift.name,
      animationUrl: mediaUrl,
      thumbnailUrl: gift.displayImageUrl,
      senderId: me.id,
      senderName: senderName,
      senderAvatarUrl: me.avatarUrl,
      comboCount: nextCombo,
      overlayKey: comboKey,
    );
  }

  Future<void> _onQuickSendSmallGift(GiftEntity gift) async {
    if (!_checkAuth()) return;
    if (!_canSendGiftToHost) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.liveGiftCannotSendToSelf)));
      return;
    }

    // Instant UI — do not wait for purchase / socket / auctionGiftCombo.
    _showOptimisticSmallGiftCombo(gift);

    // Fire-and-forget socket send; combo ×N syncs from auctionGiftCombo.
    _giftSendTaskChain = _giftSendTaskChain
        .then((_) async {
          if (!mounted) return;
          try {
            await _executeGiftSendApi(gift);
          } catch (err) {
            developer.log('Gift send queue error: $err', name: 'LiveDetails');
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(err.toString())));
            }
          }
        })
        .catchError((err) {
          developer.log('Gift send queue error: $err', name: 'LiveDetails');
        });
  }

  Future<void> _executeGiftSendApi(GiftEntity gift) async {
    final post = widget.post;
    final receiverId = _hostUserId ?? post?.userId;
    if (receiverId == null || receiverId.isEmpty) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.liveGiftNoRecipient)));
      }
      return;
    }

    String? auctionId;
    if (_isAuctionPost) {
      auctionId = await _ensureGiftAuctionId();
    }

    try {
      final purchaseGift = gifts_di.sl<PurchaseGiftUseCase>();
      final sendGift = gifts_di.sl<SendGiftUseCase>();
      final getInventory = gifts_di.sl<GetGiftInventoryUseCase>();

      // 1. Resolve real gift entity from catalog if tapped from static fallback
      String realGiftId = gift.id;
      GiftEntity targetGift = gift;
      if (realGiftId.startsWith('rec-')) {
        final catalogResult = await gifts_di.sl<GetGiftsUseCase>()(
          const GetGiftsParams(),
        );
        catalogResult.fold((_) {}, (catalog) {
          final matched = catalog.firstWhere(
            (g) => g.name.toLowerCase() == gift.name.toLowerCase(),
            orElse: () => catalog.firstWhere(
              (g) => g.size == GiftCatalogSize.small,
              orElse: () => gift,
            ),
          );
          if (!matched.id.startsWith('rec-')) {
            realGiftId = matched.id;
            targetGift = matched;
          }
        });
      }

      if (realGiftId.startsWith('rec-')) return;

      // 2. Fetch inventory & balance
      final inventoryResult = await getInventory(NoParams());
      GiftInventoryEntity? inventory;
      inventoryResult.fold((_) {}, (inv) => inventory = inv);

      final ownedQty = inventory?.quantityFor(realGiftId) ?? 0;
      final balanceCoins = inventory?.balanceCoins ?? 0;

      // 3. Purchase using POST /gifts/purchase if not in inventory
      if (ownedQty < 1) {
        if (balanceCoins < targetGift.priceCoins) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Insufficient coins (${targetGift.priceCoins} required). Please recharge.',
                ),
              ),
            );
          }
          return;
        }

        final purchaseResult = await purchaseGift(
          PurchaseGiftParams(giftId: realGiftId),
        );
        final purchased = purchaseResult.fold((failure) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(failure.message)));
          }
          return false;
        }, (_) => true);
        if (!purchased) return;
      }

      // 4. Prefer socket sendGift (qty 1); HTTP fallback if socket offline.
      await _ensureAuctionRoomsJoined();
      final liveId = _liveRoomId;
      final socket = _auctionSocket;
      GiftSocketSendResult? socketResult;
      if (socket != null &&
          (liveId != null && liveId.isNotEmpty ||
              (auctionId != null && auctionId.isNotEmpty))) {
        socketResult = await socket.sendGift(
          giftId: realGiftId,
          liveId: liveId,
          auctionId: auctionId,
          quantity: 1,
          receiverId: receiverId,
        );
      }

      if (socketResult != null) {
        if (!socketResult.isSuccess) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  socketResult.errorMessage ?? 'Failed to send gift',
                ),
              ),
            );
          }
          return;
        }
        // Animation / combo come from gift_combo broadcast.
        return;
      }

      final sendResult = await sendGift(
        SendGiftParams(
          giftId: realGiftId,
          receiverId: receiverId,
          quantity: 1,
          postId: post?.id,
          auctionId: auctionId,
          liveId: liveId,
        ),
      );

      await sendResult.fold((failure) async {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(failure.message)));
        }
      }, (_) async {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _bidPopController;
  late Animation<double> _bidPopAnimation;

  int get _streamIndex => widget.post != null
      ? widget.post!.id.hashCode.abs() % 1000
      : widget.index;

  List<PostMediaEntity> get _displayMedia {
    final post = widget.post;
    if (post == null) {
      return [
        PostMediaEntity(
          url: 'https://picsum.photos/800/1200?random=${_streamIndex + 200}',
          mediaType: 'IMAGE',
          order: 0,
        ),
      ];
    }
    return resolveAuctionDisplayMedia(post);
  }

  int get _startingPriceCoins {
    if (_startingPriceOverride != null) return _startingPriceOverride!;
    return widget.post?.auction?.startingPriceCoins ?? 0;
  }

  int get _giftContributionCoins {
    if (_giftContributionOverride != null) return _giftContributionOverride!;
    return widget.post?.auction?.giftContributionCoins ?? 0;
  }

  int get _highestBidCoins {
    if (_startingPriceOverride != null || _giftContributionOverride != null) {
      return _startingPriceCoins + _giftContributionCoins;
    }
    return widget.post?.auction?.displayHighestPriceCoins ?? 0;
  }

  bool get _usesGiftTotal => widget.post?.auction != null;

  bool get _showAuctionCoinPricing =>
      _isAuctionPost || widget.post?.auction != null;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: LiveDetailsLayoutConstants.pulseDuration,
    )..repeat(reverse: true);
    _pulseAnimation =
        Tween<double>(
          begin: LiveDetailsLayoutConstants.pulseOpacityMin,
          end: LiveDetailsLayoutConstants.pulseOpacityMax,
        ).animate(
          CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
        );

    _bidPopController = AnimationController(
      vsync: this,
      duration: LiveDetailsLayoutConstants.bidPopDuration,
    );
    _bidPopAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: LiveDetailsLayoutConstants.bidPopScaleEnd,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: LiveDetailsLayoutConstants.bidPopScaleEnd,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 60,
      ),
    ]).animate(_bidPopController);

    final postId = widget.post?.id;
    if (postId != null) {
      _commentsBloc = di.sl<CommentsBloc>();
      _commentsBloc!.add(
        FetchCommentsRequested(postId: postId, isRefresh: true, sort: 'oldest'),
      );
    }

    if (_isAuctionPost || widget.post?.auction != null) {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        _syncAuctionFinishedState();
        setState(() {});
      });
    }

    _syncAuctionFinishedState();
    if (widget.isActive) {
      _startPostViewWatchTracking();
    }
    unawaited(_startAuctionRealtime());
    unawaited(_loadRecommendedSmallGifts());
    if (_isAuctionPost) {
      unawaited(_ensureGiftAuctionId());
      unawaited(_prefetchAuctionDetails());
    }
  }

  void _applyAuctionDetailsFromApi(
    AuctionDetailsEntity details, {
    bool animateBid = false,
  }) {
    final liveId = details.liveId?.trim();
    final shouldRejoinLive =
        liveId != null && liveId.isNotEmpty && liveId != _resolvedLiveId;
    setState(() {
      if (liveId != null && liveId.isNotEmpty) {
        _resolvedLiveId = liveId;
      }
      _startingPriceOverride = details.startingPriceCoins;
      _giftContributionOverride = details.currentTotalCoins;
      if (details.targetPriceCoins > 0) {
        _targetPriceCoinsOverride = details.targetPriceCoins;
      }
      final highest = details.displayHighestPriceCoins;
      if (details.targetPriceCoins > 0 && highest >= details.targetPriceCoins) {
        if (!_isAuctionFinished) {
          _completeAuction();
        }
      } else if (animateBid) {
        _bidPopController.forward(from: 0);
      }
      _syncAuctionFinishedState();
    });
    if (shouldRejoinLive) {
      unawaited(_ensureAuctionRoomsJoined());
    }
  }

  Future<void> _prefetchAuctionDetails() async {
    final auctionId = await _ensureGiftAuctionId();
    if (!mounted || auctionId == null || auctionId.isEmpty) return;

    final result = await auctions_di.sl<GetAuctionDetailsUseCase>()(
      GetAuctionDetailsParams(auctionId: auctionId),
    );
    if (!mounted) return;

    result.fold((_) {}, (details) {
      _applyAuctionDetailsFromApi(details);
    });
  }

  String? get _auctionId => _auctionRoomId;

  bool get _isAuctionPost => widget.post != null && widget.post!.isAuctionable;

  /// Real auction UUID for gift/API calls — never the post id.
  String? get _giftAuctionId {
    final fromPost = widget.post?.auction?.id?.trim();
    if (fromPost != null && fromPost.isNotEmpty) return fromPost;
    final fromRoute = widget.auctionId?.trim();
    if (fromRoute != null && fromRoute.isNotEmpty) return fromRoute;
    final resolved = _resolvedAuctionId?.trim();
    if (resolved != null && resolved.isNotEmpty) return resolved;
    return null;
  }

  /// Socket room id: prefer auction UUID; some backends also accept post id.
  String? get _auctionRoomId {
    final fromAuction = _giftAuctionId;
    if (fromAuction != null) return fromAuction;
    if (_isAuctionPost) return widget.post?.id;
    return null;
  }

  /// Resolves a real auction UUID when feed omitted `auction.id`.
  /// Tries active auctions by postId, then a full post fetch.
  Future<String?> _ensureGiftAuctionId() async {
    final existing = _giftAuctionId;
    if (existing != null && existing.isNotEmpty) return existing;

    final inFlight = _auctionIdResolveCompleter;
    if (inFlight != null) return inFlight.future;

    final postId = widget.post?.id.trim();
    if (postId == null || postId.isEmpty) return null;

    final completer = Completer<String?>();
    _auctionIdResolveCompleter = completer;

    try {
      String? found;

      final activeResult = await auctions_di.sl<GetActiveAuctionsUseCase>()(
        NoParams(),
      );
      if (!mounted) {
        completer.complete(null);
        return null;
      }
      activeResult.fold((_) {}, (auctions) {
        for (final auction in auctions) {
          if (auction.postId == postId && auction.id.isNotEmpty) {
            found = auction.id;
            break;
          }
        }
      });

      if (found == null || found!.isEmpty) {
        final postResult = await di.sl<GetPostByIdUseCase>()(postId);
        if (!mounted) {
          completer.complete(null);
          return null;
        }
        postResult.fold((_) {}, (post) {
          final id = post.auction?.id?.trim();
          if (id != null && id.isNotEmpty) found = id;
        });
      }

      if (found != null && found!.isNotEmpty && mounted) {
        setState(() => _resolvedAuctionId = found);
        // Rejoin with the real auction UUID once resolved.
        unawaited(_ensureAuctionRoomsJoined());
      }
      completer.complete(found);
      return found;
    } catch (_) {
      completer.complete(null);
      return null;
    } finally {
      if (identical(_auctionIdResolveCompleter, completer)) {
        _auctionIdResolveCompleter = null;
      }
    }
  }

  Future<void> _startAuctionRealtime() async {
    final post = widget.post;
    if (post == null || post.id.isEmpty) return;

    _auctionSocket = auctions_di.sl<AuctionSocketService>();

    await _auctionUpdatedSub?.cancel();
    await _newCommentSub?.cancel();
    await _giftComboSub?.cancel();
    await _socketConnectionSub?.cancel();

    // Post room: newComment events (comment list + gift comments).
    _newCommentSub = _auctionSocket!.onNewComment.listen(_onRealtimeComment);
    // Auction room: auctionUpdated with lastComment / lastGift / totals.
    _auctionUpdatedSub = _auctionSocket!.onAuctionUpdated.listen(
      _onRealtimeAuctionUpdate,
    );
    // Live Gift Combo Aggregator Engine (Redis 5s combo window events)
    _giftComboSub = _auctionSocket!.onGiftCombo.listen(_onRealtimeGiftCombo);
    _socketConnectionSub = _auctionSocket!.onConnectionChanged.listen((
      connected,
    ) {
      if (connected && mounted) {
        unawaited(_ensureAuctionRoomsJoined());
      }
    });

    await _ensureAuctionRoomsJoined();
  }

  /// Live room id for socket gifts — auction.liveId when known, else post id.
  String? get _liveRoomId {
    final fromAuction = _resolvedLiveId?.trim();
    if (fromAuction != null && fromAuction.isNotEmpty) return fromAuction;
    final postId = widget.post?.id.trim();
    if (postId != null && postId.isNotEmpty) return postId;
    return null;
  }

  Future<void> _ensureAuctionRoomsJoined() async {
    final post = widget.post;
    final socket = _auctionSocket;
    if (post == null || socket == null || post.id.isEmpty) return;

    final auctionId = _auctionRoomId;
    final liveId = _liveRoomId;
    await socket.ensureJoined(
      postId: post.id,
      auctionId: auctionId,
      liveId: liveId,
    );
    _joinedPostId = post.id;
    _joinedAuctionId = auctionId;
    _joinedLiveId = liveId;
  }

  void _stopAuctionRealtime() {
    final socket = _auctionSocket;
    if (socket != null) {
      final auctionId = _joinedAuctionId;
      if (auctionId != null && auctionId.isNotEmpty) {
        socket.leaveAuction(auctionId);
      }
      final liveId = _joinedLiveId;
      if (liveId != null && liveId.isNotEmpty) {
        socket.leaveLive(liveId);
      }
      final postId = _joinedPostId;
      if (postId != null && postId.isNotEmpty) {
        socket.leavePost(postId);
      }
    }

    unawaited(_auctionUpdatedSub?.cancel());
    unawaited(_newCommentSub?.cancel());
    unawaited(_giftComboSub?.cancel());
    unawaited(_socketConnectionSub?.cancel());
    _auctionUpdatedSub = null;
    _newCommentSub = null;
    _giftComboSub = null;
    _socketConnectionSub = null;
    _joinedAuctionId = null;
    _joinedPostId = null;
    _joinedLiveId = null;
  }

  void _onRealtimeComment(CommentEntity comment) {
    if (!mounted) return;
    if (!_matchesCommentUpdate(comment)) return;

    _appendCommentIfNew(comment);

    if (comment.isGift) {
      _bidPopController.forward(from: 0);
      // First socket event wins — gift comment can paint before auctionGiftCombo.
      _showGiftVisualFromRealtime(
        giftId: comment.giftName ?? comment.id,
        senderId: comment.user.id,
        giftName: comment.giftName ?? 'Gift',
        animationUrl: comment.giftAnimationUrl,
        thumbnailUrl: comment.giftThumbnailUrl ?? comment.giftIcon,
        size: comment.giftSize,
        combo: 1,
        senderName: _displaySenderName(
          fullName: comment.user.fullName,
          username: comment.user.username,
        ),
        senderAvatarUrl: comment.user.avatarUrl,
        audioUrl: comment.giftAudioUrl,
        colorHex: comment.giftColor,
        isAudio: comment.isAudioGiftComment,
      );
    }
  }

  void _onEphemeralAudioGiftChipUpdate(String? label, String? colorHex) {
    if (!mounted) return;
    setState(() {
      _ephemeralAudioGiftLabel = label;
      _ephemeralAudioGiftColor = colorHex;
    });
  }

  /// Paint gift UI from whichever room event arrives first
  /// (`auctionGiftCombo` / `auctionUpdated.lastGift` / gift comment).
  void _showGiftVisualFromRealtime({
    required String giftId,
    required String senderId,
    required String giftName,
    String? animationUrl,
    String? thumbnailUrl,
    dynamic size,
    int combo = 1,
    String? senderName,
    String? senderAvatarUrl,
    String? audioUrl,
    String? colorHex,
    bool isAudio = false,
  }) {
    if (!mounted) return;

    // Normalize id so comment / auctionUpdated / auctionGiftCombo share one card.
    var resolvedGiftId = giftId.trim();
    GiftEntity? catalogGift = resolvedGiftId.isNotEmpty
        ? _giftCatalogById[resolvedGiftId]
        : null;
    if (catalogGift == null && giftName.trim().isNotEmpty) {
      final lower = giftName.trim().toLowerCase();
      for (final g in _giftCatalogById.values) {
        if (g.name.toLowerCase() == lower) {
          catalogGift = g;
          resolvedGiftId = g.id;
          break;
        }
      }
    }

    final resolvedName = giftName.trim().isNotEmpty
        ? giftName.trim()
        : (catalogGift?.name ?? 'Gift');
    final resolvedAudio = isAudio || catalogGift?.isAudioGift == true;

    if (resolvedAudio) {
      unawaited(
        _audioGiftChipSession.play(
          onUpdate: _onEphemeralAudioGiftChipUpdate,
          label: resolvedName,
          colorHex: colorHex ?? catalogGift?.color,
          audioUrl: audioUrl ?? catalogGift?.audioUrl,
        ),
      );
      return;
    }

    final resolvedAnim =
        (animationUrl?.trim().isNotEmpty == true
            ? animationUrl!.trim()
            : null) ??
        catalogGift?.animationUrl;
    final resolvedThumb =
        (thumbnailUrl?.trim().isNotEmpty == true
            ? thumbnailUrl!.trim()
            : null) ??
        catalogGift?.displayImageUrl;
    final resolvedSize = size ?? catalogGift?.size;
    final mediaUrl = resolvedAnim ?? resolvedThumb ?? '';

    final authState = context.read<AuthBloc>().state;
    final me = authState is AuthSuccess ? authState.user : null;
    final isMyOwnSend =
        me != null &&
        me.id.isNotEmpty &&
        senderId.isNotEmpty &&
        senderId == me.id;

    final resolvedSenderId = senderId.isNotEmpty
        ? senderId
        : (isMyOwnSend ? me.id : (senderName ?? 'User'));
    final resolvedSenderName = isMyOwnSend
        ? (_displaySenderName(fullName: me.fullName, username: me.username) ??
              'User')
        : (senderName?.trim().isNotEmpty == true ? senderName!.trim() : 'User');
    final resolvedAvatar = isMyOwnSend ? me.avatarUrl : senderAvatarUrl;

    final isSmall =
        resolvedSize == GiftCatalogSize.small ||
        resolvedSize?.toString().toUpperCase() == 'SMALL' ||
        // Flat payloads often omit size — prefer combo card when no video URL.
        (resolvedSize == null &&
            (resolvedAnim == null || resolvedAnim.trim().isEmpty));

    final keyGiftId = resolvedGiftId.isNotEmpty ? resolvedGiftId : resolvedName;
    final comboKey = '${resolvedSenderId}_$keyGiftId';

    if (isSmall) {
      _updateOrAddGiftCombo(
        giftId: keyGiftId,
        giftName: resolvedName,
        animationUrl: mediaUrl,
        thumbnailUrl: resolvedThumb,
        senderId: resolvedSenderId,
        senderName: resolvedSenderName,
        senderAvatarUrl: resolvedAvatar,
        comboCount: combo > 0 ? combo : 1,
        overlayKey: comboKey,
      );
      return;
    }

    // Medium / large: full-screen only (deduped inside _playGiftAnimation).
    if (mediaUrl.isNotEmpty) {
      _playGiftAnimation(
        animationUrl: resolvedAnim ?? resolvedThumb,
        thumbnailUrl: resolvedThumb,
        giftName: resolvedName,
        giftId: keyGiftId,
        senderId: resolvedSenderId,
        senderName: resolvedSenderName,
        senderAvatarUrl: resolvedAvatar,
        size: resolvedSize,
        quantity: combo > 0 ? combo : 1,
        comboCount: combo > 0 ? combo : 1,
        skipComboBadge: true,
      );
    }
  }

  void _onRealtimeGiftCombo(GiftComboPayload payload) {
    if (!mounted) return;

    final catalogGift = _giftCatalogById[payload.giftId];
    final giftMap = payload.gift;
    final senderMap = payload.sender;
    final giftName =
        (payload.giftName ?? giftMap?['name'] ?? catalogGift?.name ?? 'Gift')
            .toString();

    _showGiftVisualFromRealtime(
      giftId: payload.giftId,
      senderId: payload.senderId,
      giftName: giftName,
      animationUrl:
          (giftMap?['animationUrl'] ??
                  giftMap?['animation_url'] ??
                  giftMap?['imageUrl'])
              ?.toString(),
      thumbnailUrl:
          (giftMap?['thumbnailUrl'] ??
                  giftMap?['thumbnail_url'] ??
                  giftMap?['imageUrl'])
              ?.toString(),
      size: giftMap?['size'] ?? giftMap?['giftSize'] ?? catalogGift?.size,
      combo: payload.combo,
      senderName:
          payload.senderName ??
          (senderMap?['fullName'] ?? senderMap?['username'])?.toString(),
      senderAvatarUrl:
          payload.senderAvatarUrl ??
          (senderMap?['avatarUrl'] ?? senderMap?['avatar'])?.toString(),
      audioUrl: catalogGift?.audioUrl,
      colorHex: catalogGift?.color,
      isAudio: catalogGift?.isAudioGift == true,
    );
  }

  void _updateOrAddGiftCombo({
    required String giftId,
    required String giftName,
    required String animationUrl,
    String? thumbnailUrl,
    required String senderId,
    required String senderName,
    String? senderAvatarUrl,
    required int comboCount,
    String? overlayKey,
  }) {
    final comboKey = (overlayKey != null && overlayKey.isNotEmpty)
        ? overlayKey
        : '${senderId}_$giftId';
    final existing = _activeGiftCombos[comboKey];

    _giftComboTimers[comboKey]?.cancel();

    final targetCombo = comboCount > 0
        ? (existing != null && comboCount < existing.combo
              ? existing.combo
              : comboCount)
        : ((existing?.combo ?? 0) + 1);

    setState(() {
      if (existing != null) {
        existing.combo = targetCombo;
      } else {
        _activeGiftCombos[comboKey] = GiftComboItem(
          senderId: senderId,
          senderName: senderName,
          senderAvatarUrl: senderAvatarUrl,
          giftId: giftId,
          giftName: giftName,
          animationUrl: animationUrl,
          thumbnailUrl: thumbnailUrl,
          combo: targetCombo,
        );
      }
    });

    // 5-second TTL window matching Redis EXPIRE 5
    _giftComboTimers[comboKey] = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _activeGiftCombos.remove(comboKey);
          _giftComboTimers.remove(comboKey)?.cancel();
        });
      }
    });
  }

  void _playSmallGiftBadge({
    required String animationUrl,
    String? thumbnailUrl,
    String? giftName,
    String? giftId,
    String? senderName,
    String? senderId,
    String? senderAvatarUrl,
    int quantity = 1,
    int? comboCount,
  }) {
    final gName = giftName ?? 'Gift';
    final gId = (giftId != null && giftId.isNotEmpty) ? giftId : gName;
    final sName = senderName ?? 'User';
    final sId = (senderId != null && senderId.isNotEmpty) ? senderId : sName;

    _updateOrAddGiftCombo(
      giftId: gId,
      giftName: gName,
      animationUrl: animationUrl,
      thumbnailUrl: thumbnailUrl,
      senderId: sId,
      senderName: sName,
      senderAvatarUrl: senderAvatarUrl,
      comboCount: comboCount ?? quantity,
    );
  }

  void _playGiftAnimation({
    String? animationUrl,
    String? thumbnailUrl,
    String? senderName,
    String? senderAvatarUrl,
    String? giftName,
    String? giftId,
    String? senderId,
    dynamic size,
    int quantity = 1,
    int? comboCount,
    bool skipComboBadge = false,
  }) async {
    final url = animationUrl?.trim();
    if (url == null || url.isEmpty || !mounted) return;

    final isSmall =
        size == GiftCatalogSize.small ||
        size?.toString().toUpperCase() == 'SMALL';
    if (isSmall) {
      if (!skipComboBadge) {
        _playSmallGiftBadge(
          animationUrl: url,
          thumbnailUrl: thumbnailUrl,
          giftName: giftName,
          giftId: giftId,
          senderName: senderName,
          senderId: senderId,
          senderAvatarUrl: senderAvatarUrl,
          quantity: quantity,
          comboCount: comboCount,
        );
      }
      return;
    }

    // Wait until any open bottom sheet or dialog has completely closed.
    while (mounted && ModalRoute.of(context)?.isCurrent != true) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!mounted) return;

    final dedupeKey = '${giftName ?? ''}|${senderName ?? ''}';
    final now = DateTime.now();
    final lastAt = _lastGiftPlayedAt;
    // Ignore socket+local doubles even when URLs differ slightly.
    if (_lastGiftPlayedKey == dedupeKey &&
        lastAt != null &&
        now.difference(lastAt) < const Duration(seconds: 3)) {
      return;
    }
    if (lastAt != null &&
        now.difference(lastAt) < const Duration(milliseconds: 800)) {
      // Hard throttle: at most one overlay every 800ms.
      return;
    }
    _lastGiftPlayedKey = dedupeKey;
    _lastGiftPlayedAt = now;

    unawaited(
      GiftAnimationOverlay.show(
        context,
        animationUrl: url,
        thumbnailUrl: thumbnailUrl,
        senderName: senderName,
        giftName: giftName,
        size: size,
      ),
    );
  }

  /// Prefer profile name over @username on auction gift overlays/comments.
  String? _displaySenderName({String? fullName, String? username}) {
    final name = fullName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final handle = username?.trim();
    if (handle != null && handle.isNotEmpty) return handle;
    return null;
  }

  bool _matchesCommentUpdate(CommentEntity comment) {
    final postId = widget.post?.id;
    if (postId == null) return false;

    if (comment.postId.isEmpty || comment.postId == postId) {
      return true;
    }

    return false;
  }

  void _appendCommentIfNew(CommentEntity comment) {
    if (comment.parentId != null) return;
    if (_postComments.any((existing) => existing.id == comment.id)) return;

    // Avoid duplicate gift bubbles when optimistic + socket + HTTP refetch
    // arrive with different ids for the same send.
    if (comment.isGift) {
      final senderId = comment.user.id;
      final giftName = comment.giftName?.trim().toLowerCase() ?? '';

      final isServerComment =
          !comment.id.startsWith('local-gift-') &&
          !comment.id.startsWith('socket-gift-');

      // Check if there is a matching temporary/local gift comment
      final localIndex = _postComments.indexWhere((existing) {
        if (!existing.isGift) return false;
        final isTemp =
            existing.id.startsWith('local-gift-') ||
            existing.id.startsWith('socket-gift-');
        if (!isTemp) return false;

        final sameSender =
            senderId.isEmpty ||
            existing.user.id == senderId ||
            existing.user.username == comment.user.username;
        final sameGift =
            giftName.isEmpty ||
            (existing.giftName?.trim().toLowerCase() ?? '') == giftName;

        return sameSender && sameGift;
      });

      if (localIndex != -1) {
        if (isServerComment) {
          // Replace temporary local comment with permanent server comment
          setState(() {
            _postComments[localIndex] = comment;
          });
          _scrollChatToBottom();
        }
        return;
      }
    }

    setState(() {
      // Sort a copy first — clearing `_postComments` before sort wiped the
      // new comment (gifts looked fine because they refetch the list).
      final updated = sortCommentsOldest([..._postComments, comment]);
      _postComments
        ..clear()
        ..addAll(updated);
    });
    _scrollChatToBottom();
  }

  void _onRealtimeAuctionUpdate(AuctionUpdatedPayload payload) {
    if (!mounted) return;
    if (!_matchesAuctionUpdate(payload)) return;

    var shouldAnimateBid = false;

    setState(() {
      if (payload.startingPriceCoins != null) {
        _startingPriceOverride = payload.startingPriceCoins;
      }
      if (payload.currentTotalCoins != null &&
          payload.currentTotalCoins != _giftContributionCoins) {
        _giftContributionOverride = payload.currentTotalCoins;
        shouldAnimateBid = true;
      }
      if (payload.targetPriceCoins != null && payload.targetPriceCoins! > 0) {
        _targetPriceCoinsOverride = payload.targetPriceCoins;
      }
      if (_isFinishedStatus(payload.status)) {
        _isAuctionFinished = true;
        _pulseController.stop();
      }
    });

    if (payload.hasGiftActivity) {
      shouldAnimateBid = true;
      _refreshAuctionComments();
      final gift = payload.lastGift!;
      final parsedLastGift = PostAuctionLastGiftEntity.fromMap(
        Map<String, dynamic>.from(gift),
      );
      final giftName = (gift['name'] ?? gift['giftName'])?.toString();
      final thumb =
          (gift['thumbnailUrl'] ?? gift['thumbnail_url'] ?? gift['imageUrl'])
              ?.toString();
      final animationUrl =
          (gift['animationUrl'] ?? gift['animation_url'] ?? thumb)?.toString();
      final audioUrl = (gift['audioUrl'] ?? gift['audio_url'])?.toString();
      final giftId =
          (gift['giftId'] ?? gift['id'] ?? parsedLastGift?.id)?.toString() ??
          '';

      final senderId =
          (gift['senderId'] ?? gift['sender_id'] ?? gift['userId'])
              ?.toString() ??
          '';
      final senderObj = gift['sender'] is Map ? gift['sender'] as Map : null;
      final senderFullName =
          (gift['senderFullName'] ??
                  gift['senderName'] ??
                  gift['fullName'] ??
                  gift['nameSender'] ??
                  senderObj?['fullName'])
              ?.toString();
      final senderUsername =
          (gift['senderUsername'] ?? gift['username'] ?? senderObj?['username'])
              ?.toString();
      final senderAvatar =
          (gift['senderAvatarUrl'] ??
                  gift['avatarUrl'] ??
                  senderObj?['avatarUrl'] ??
                  senderObj?['avatar'])
              ?.toString();

      // Show gift UI immediately — do not wait for auctionGiftCombo.
      _showGiftVisualFromRealtime(
        giftId: giftId,
        senderId: senderId,
        giftName: giftName ?? parsedLastGift?.name ?? 'Gift',
        animationUrl: animationUrl,
        thumbnailUrl: thumb,
        size: gift['size'] ?? gift['giftSize'],
        combo: payload.combo ?? parsedLastGift?.quantity ?? 1,
        senderName: _displaySenderName(
          fullName: senderFullName,
          username: senderUsername,
        ),
        senderAvatarUrl: senderAvatar,
        audioUrl: audioUrl,
        colorHex: parsedLastGift?.color ?? gift['color']?.toString(),
        isAudio: parsedLastGift?.isAudioGift == true,
      );

      // auctionUpdated gift variant may omit lastComment — still show in list.
      if (payload.lastComment == null) {
        final postId = widget.post?.id;
        if (postId != null) {
          final now = DateTime.now().toUtc().toIso8601String();
          _appendCommentIfNew(
            CommentEntity(
              id: 'socket-gift-$giftId-$senderId-$now',
              content: giftName != null && giftName.isNotEmpty
                  ? 'Sent $giftName'
                  : '',
              postId: postId,
              user: UserEntity(
                id: senderId,
                username: senderUsername,
                fullName: senderFullName,
              ),
              isGift: true,
              giftName: giftName,
              giftThumbnailUrl: parsedLastGift?.isAudioGift == true
                  ? null
                  : thumb,
              giftAnimationUrl: parsedLastGift?.isAudioGift == true
                  ? null
                  : animationUrl,
              giftCatalogType: parsedLastGift?.isAudioGift == true
                  ? GiftCatalogType.audio
                  : GiftCatalogType.image,
              giftColor: parsedLastGift?.color,
              giftAudioUrl: audioUrl,
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
      }
    }

    final target =
        payload.targetPriceCoins ?? widget.post?.auction?.targetPriceCoins ?? 0;
    if (target > 0 && _highestBidCoins >= target) {
      if (!_isAuctionFinished) {
        _completeAuction();
      }
      return;
    }

    if (shouldAnimateBid) {
      _bidPopController.forward(from: 0);
    }
  }

  bool _matchesAuctionUpdate(AuctionUpdatedPayload payload) {
    final postId = widget.post?.id;
    final auctionId = _auctionId;

    if (payload.postId != null && postId != null && payload.postId == postId) {
      return true;
    }

    if (payload.auctionId != null) {
      if (auctionId != null && payload.auctionId == auctionId) return true;
      if (postId != null && payload.auctionId == postId) return true;
    }

    return payload.postId == null && payload.auctionId == null;
  }

  bool _isFinishedStatus(String? status) {
    if (status == null) return false;
    switch (status.toUpperCase()) {
      case 'ENDED':
      case 'FINISHED':
      case 'COMPLETED':
      case 'CLOSED':
        return true;
      default:
        return false;
    }
  }

  void _refreshAuctionComments() {
    final postId = widget.post?.id;
    if (postId == null) return;
    _commentsBloc?.add(
      FetchCommentsRequested(postId: postId, isRefresh: true, sort: 'oldest'),
    );
  }

  DateTime? _viewWatchStartedAt;
  int _accumulatedWatchMs = 0;
  bool _viewWatchTracking = false;
  bool _viewEligible = false;
  bool _viewRecorded = false;
  Timer? _viewEligibleTimer;

  static const _viewMinVisible = Duration(milliseconds: 1000);

  void _startPostViewWatchTracking() {
    final post = widget.post;
    if (post == null || post.isStory || _viewRecorded) return;
    if (!widget.isActive) return;
    if (_isPostOwnerCached()) return;

    if (!_viewWatchTracking) {
      _viewWatchTracking = true;
      _viewWatchStartedAt = DateTime.now();
    }
    _scheduleViewEligibleTimer();
  }

  void _scheduleViewEligibleTimer() {
    _viewEligibleTimer?.cancel();
    if (_viewEligible || _viewRecorded) return;
    final remaining = _viewMinVisible.inMilliseconds - _watchedDurationMs();
    if (remaining <= 0) {
      _viewEligible = true;
      return;
    }
    _viewEligibleTimer = Timer(Duration(milliseconds: remaining), () {
      if (!mounted) return;
      _viewEligible = true;
    });
  }

  void _pausePostViewWatchTracking() {
    _viewEligibleTimer?.cancel();
    _viewEligibleTimer = null;
    if (!_viewWatchTracking) return;
    final started = _viewWatchStartedAt;
    if (started != null) {
      final elapsed = DateTime.now().difference(started).inMilliseconds;
      if (elapsed > 0) _accumulatedWatchMs += elapsed;
    }
    _viewWatchStartedAt = null;
    _viewWatchTracking = false;
  }

  int _watchedDurationMs() {
    var total = _accumulatedWatchMs;
    final started = _viewWatchStartedAt;
    if (_viewWatchTracking && started != null) {
      final elapsed = DateTime.now().difference(started).inMilliseconds;
      if (elapsed > 0) total += elapsed;
    }
    return total;
  }

  int _watchedDurationSeconds() {
    final ms = _watchedDurationMs();
    if (ms <= 0) return 0;
    final seconds = ms ~/ 1000;
    return seconds > 0 ? seconds : 1;
  }

  bool? _cachedIsOwner;

  bool _isPostOwnerCached() {
    try {
      _cachedIsOwner ??= _isPostOwner();
    } catch (_) {
      _cachedIsOwner ??= false;
    }
    return _cachedIsOwner!;
  }

  void _flushPostView({
    String? postId,
    String? trafficSource,
  }) {
    final post = widget.post;
    if ((post == null || post.isStory) && postId == null) return;
    _pausePostViewWatchTracking();

    final watchedMs = _watchedDurationMs();
    final eligible =
        _viewEligible || watchedMs >= _viewMinVisible.inMilliseconds;
    if (!eligible || _viewRecorded) {
      if (!_viewRecorded && widget.isActive && mounted) {
        _startPostViewWatchTracking();
      }
      return;
    }

    final id = (postId ?? post?.id ?? '').trim();
    if (id.isEmpty) return;

    final campaignId = (post != null && (post.isPromoted || post.isAd))
        ? post.promotion?.id
        : null;

    PostViewRecorder.recordIfNeeded(
      postId: id,
      isOwner: postId == null ? _isPostOwnerCached() : false,
      watchedDuration: _watchedDurationSeconds(),
      campaignId: (campaignId != null && campaignId.isNotEmpty)
          ? campaignId
          : null,
      trafficSource: trafficSource ?? widget.trafficSource,
    );
    _viewRecorded = true;
    _viewEligible = false;
    _accumulatedWatchMs = 0;
  }

  void _resetPostViewWatchSession() {
    _viewEligibleTimer?.cancel();
    _viewEligibleTimer = null;
    _viewWatchTracking = false;
    _viewWatchStartedAt = null;
    _accumulatedWatchMs = 0;
    _viewEligible = false;
    _viewRecorded = false;
    _cachedIsOwner = null;
  }

  @override
  void didUpdateWidget(LiveDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final prevPostId = oldWidget.post?.id;
    final nextPostId = widget.post?.id;
    if (prevPostId != nextPostId) {
      if (prevPostId != null) {
        _flushPostView(
          postId: prevPostId,
          trafficSource: oldWidget.trafficSource,
        );
      }
      _resetPostViewWatchSession();
      if (nextPostId != null) {
        _stopAuctionRealtime();
        unawaited(_startAuctionRealtime());
        _commentsBloc?.add(
          FetchCommentsRequested(
            postId: nextPostId,
            isRefresh: true,
            sort: 'oldest',
          ),
        );
        _isAuctionFinished = false;
        _syncAuctionFinishedState();
        if (!_isAuctionFinished && !_pulseController.isAnimating) {
          _pulseController.repeat(reverse: true);
        }
        if (widget.isActive) {
          _startPostViewWatchTracking();
        }
      }
    } else if (widget.isActive && !oldWidget.isActive) {
      _startPostViewWatchTracking();
    } else if (!widget.isActive && oldWidget.isActive) {
      _flushPostView();
    }

    final prevTotal = oldWidget.post?.auction?.currentTotalCoins;
    final nextTotal = widget.post?.auction?.currentTotalCoins;
    if (prevTotal != nextTotal) {
      _giftContributionOverride = null;
      _startingPriceOverride = null;
      _targetPriceCoinsOverride = null;
      if (nextTotal != null && nextTotal != prevTotal) {
        _bidPopController.forward(from: 0);
      }
      _syncAuctionFinishedState();
    } else if (oldWidget.post?.auction?.status !=
            widget.post?.auction?.status ||
        oldWidget.post?.auction?.endedAt != widget.post?.auction?.endedAt) {
      _syncAuctionFinishedState();
    }
  }

  void _syncAuctionFinishedState() {
    final post = widget.post;
    final auction = post?.auction;
    if (auction == null || _isAuctionFinished) return;

    final endedByStatusOrDate = AuctionSearchFilters.isPostEnded(post!);
    final targetCoins =
        resolveAuctionTargetPriceCoins(
          auction,
          overrideCoins: _targetPriceCoinsOverride,
        ) ??
        0;
    final targetReached = targetCoins > 0 && _highestBidCoins >= targetCoins;

    if (endedByStatusOrDate || targetReached) {
      _isAuctionFinished = true;
      if (_pulseController.isAnimating) {
        _pulseController.stop();
      }
    }
  }

  @override
  void dispose() {
    _flushPostView();
    _viewEligibleTimer?.cancel();
    _stopAuctionRealtime();
    _audioGiftChipSession.dispose();
    _chatController.dispose();
    _chatScrollController.dispose();
    _mediaPageController.dispose();
    _commentsBloc?.close();
    _pulseController.dispose();
    _bidPopController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  bool get _usesPostComments => widget.post != null;

  bool get _showCommentsArea => _usesPostComments
      ? (_isAuctionPost || _postComments.isNotEmpty)
      : _mockChatMessages.isNotEmpty;

  List<CommentEntity> get _visiblePostComments =>
      _postComments.where((comment) => comment.parentId == null).toList();

  bool _checkAuth() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthSuccess) return true;

    final l10n = AppLocalizations.of(context)!;
    PopupDialogs.showConfirmDialog(
      context,
      title: l10n.loginRequired,
      message: l10n.loginRequiredMessage,
      cancelLabel: l10n.cancel,
      confirmLabel: l10n.login,
      onConfirm: () => context.pushNamed('login'),
    );
    return false;
  }

  bool _isPostOwner() {
    final post = widget.post;
    if (post == null) return false;

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthSuccess) return false;

    final ownerIds = {
      authState.user.id,
      if (authState.user.firebaseUid != null) authState.user.firebaseUid!,
    };
    final postOwnerIds = {post.userId, if (post.user != null) post.user!.id};
    return ownerIds.any(postOwnerIds.contains);
  }

  String? get _hostUserId {
    final post = widget.post;
    if (post == null) return null;
    if (post.user?.id.isNotEmpty == true) return post.user!.id;
    if (post.userId.isNotEmpty) return post.userId;
    return null;
  }

  Future<void> _toggleFollow() async {
    if (!_checkAuth() || _isPostOwner() || _isFollowLoading) return;

    final userId = _hostUserId;
    if (userId == null || userId.isEmpty) return;

    setState(() => _isFollowLoading = true);
    final result = await social_di.sl<ToggleFollowUseCase>()(
      ToggleFollowParams(userId),
    );
    if (!mounted) return;

    result.fold(
      (failure) {
        PopupDialogs.showErrorDialog(context, failure.message);
      },
      (status) {
        setState(() => _isFollowing = status == FollowStatus.followed);
      },
    );
    setState(() => _isFollowLoading = false);
  }

  void _showOwnerOptions() {
    if (!_checkAuth() || !_isPostOwner()) return;

    final post = widget.post;
    if (post == null) return;

    PostOptionsSheet.show(
      context,
      post: post,
      isOwner: true,
      onPromote: post.canBePromoted
          ? () => context.pushNamed('promote_post', extra: post)
          : null,
      onCancelAuction: _canCancelAuction ? _confirmCancelAuction : null,
      onDelete: _confirmDeletePost,
    );
  }

  bool get _canCancelAuction {
    final auction = widget.post?.auction;
    if (auction == null) return false;
    final id = auction.id;
    if (id == null || id.isEmpty) return false;
    final status = auction.status?.trim().toUpperCase() ?? '';
    return status.isEmpty || status == 'ACTIVE' || status == 'LIVE';
  }

  Future<void> _confirmCancelAuction() async {
    final auctionId = widget.post?.auction?.id;
    if (!_checkAuth() || !_isPostOwner() || auctionId == null) return;

    final l10n = AppLocalizations.of(context)!;
    await PopupDialogs.showConfirmDialog(
      context,
      title: l10n.auctionCancelTitle,
      message: l10n.auctionCancelMessage,
      cancelLabel: l10n.cancel,
      confirmLabel: l10n.auctionCancelAction,
      destructive: true,
      onConfirm: () async {
        final result = await auctions_di.sl<CancelAuctionUseCase>()(
          CancelAuctionParams(auctionId),
        );
        if (!mounted) return;
        result.fold(
          (failure) => PopupDialogs.showErrorDialog(context, failure.message),
          (_) {
            setState(() => _isAuctionFinished = true);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l10n.auctionCancelSuccess)));
          },
        );
      },
    );
  }

  void _confirmDeletePost() {
    final post = widget.post;
    if (!_checkAuth() || !_isPostOwner() || post == null) return;

    final l10n = AppLocalizations.of(context)!;

    PopupDialogs.showConfirmDialog(
      context,
      title: l10n.deletePostTitle,
      message: l10n.deletePostMessage,
      cancelLabel: l10n.cancel,
      confirmLabel: l10n.deleteAction,
      destructive: true,
      onConfirm: () {
        context.read<PostsBloc>().add(DeletePostRequestedEvent(post.id));
      },
    );
  }

  List<CommentEntity> _mergeCommentsById(
    List<CommentEntity> remote,
    List<CommentEntity> local,
  ) {
    final byId = <String, CommentEntity>{
      for (final comment in remote) comment.id: comment,
    };
    for (final comment in local) {
      byId.putIfAbsent(comment.id, () => comment);
    }

    return sortCommentsOldest(byId.values.toList());
  }

  void _onCommentsState(CommentsState state) {
    if (state is CommentsLoadSuccess) {
      setState(() {
        final existing = List<CommentEntity>.from(_postComments);
        final merged = _mergeCommentsById(state.comments, existing);
        // Drop temporary placeholders once the server list is available.
        final cleaned = merged
            .where(
              (c) =>
                  !(c.id.startsWith('local-gift-') ||
                      c.id.startsWith('socket-gift-')) ||
                  !state.comments.any(
                    (remote) =>
                        remote.isGift &&
                        remote.user.id == c.user.id &&
                        (c.giftName == null ||
                            c.giftName!.isEmpty ||
                            remote.giftName == c.giftName),
                  ),
            )
            .toList();
        _postComments
          ..clear()
          ..addAll(cleaned);
      });
      _scrollChatToBottom();
    } else if (state is AddCommentSuccess) {
      _chatController.clear();
      FocusScope.of(context).unfocus();
      _appendCommentIfNew(state.comment);
    } else if (state is CommentsFailure) {
      PopupDialogs.showErrorDialog(context, state.message);
    }
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: LiveDetailsLayoutConstants.uiHideDuration,
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool get _isRtl =>
      !_isAuctionPost && Directionality.of(context) == TextDirection.rtl;

  String _viewersLabel(AppLocalizations l10n) {
    const count = LiveDetailsLayoutConstants.mockViewerCount;
    final formatted = count >= 1000
        ? '${(count / 1000).toStringAsFixed(1)}k'
        : '$count';
    return l10n.liveViewersShort(formatted);
  }

  bool get _biddingEnabled {
    final auction = widget.post?.auction;
    if (auction == null) return true;
    if (_isAuctionFinished) return false;
    return _isAuctionInPeriod;
  }

  void _completeAuction() {
    if (_isAuctionFinished || !mounted) return;
    setState(() => _isAuctionFinished = true);
    _pulseController.stop();
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.auctionTargetReachedMessage),
        backgroundColor: LiveDetailsLayoutConstants.auctionActiveBadgeDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.p16),
        ),
      ),
    );
  }

  void _addBid(int amount) {
    if (!_biddingEnabled) return;

    final target = widget.post?.auction?.targetPriceCoins;
    if (target != null && target > 0) {
      final nextBid = _highestBid + amount;
      if (nextBid >= target) {
        setState(() => _highestBid = target);
        _bidPopController.forward(from: 0);
        _completeAuction();
        return;
      }
    }

    setState(() => _highestBid += amount);
    _bidPopController.forward(from: 0);
  }

  void _placeBidOrComment() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    final postId = widget.post?.id;
    if (postId != null) {
      if (!_checkAuth()) return;
      _commentsBloc?.add(AddCommentRequested(postId: postId, content: text));
      return;
    }

    setState(() => _mockChatMessages.add(LiveChatMessage(text: text)));
    _chatController.clear();
    FocusScope.of(context).unfocus();
    _scrollChatToBottom();
  }

  void _showAuctionGiftsSheet() {
    final auctionId = _giftAuctionId;
    if (auctionId == null || auctionId.isEmpty) return;
    AuctionGiftsSheet.show(context, auctionId: auctionId);
  }

  Future<void> _refreshAfterGift(
    GiftEntity gift, {
    bool isUserTap = false,
    int quantity = 1,
  }) async {
    // Gift card / video come only from socket auctionGiftCombo / gift_combo.
    if (!mounted) return;

    final authState = context.read<AuthBloc>().state;
    final me = authState is AuthSuccess ? authState.user : null;

    // Optimistic gift comment so the sender sees it immediately even if the
    // socket/refetch is slightly delayed.
    final postId = widget.post?.id;
    if (postId != null && me != null) {
      final now = DateTime.now().toUtc().toIso8601String();
      _appendCommentIfNew(
        CommentEntity(
          id: 'local-gift-${gift.id}-$now',
          content: 'Sent ${gift.name}',
          postId: postId,
          user: me,
          isGift: true,
          giftName: gift.name,
          giftIcon: gift.isAudioGift ? null : gift.icon,
          giftThumbnailUrl: gift.isAudioGift ? null : gift.displayImageUrl,
          giftAnimationUrl: gift.isAudioGift ? null : gift.animationUrl,
          giftCatalogType: gift.isAudioGift
              ? GiftCatalogType.audio
              : GiftCatalogType.image,
          giftColor: gift.color,
          giftAudioUrl: gift.audioUrl,
          createdAt: now,
          updatedAt: now,
        ),
      );
      _commentsBloc?.add(
        FetchCommentsRequested(postId: postId, isRefresh: true, sort: 'oldest'),
      );
    }
    context.read<PostsBloc>().add(
      FetchFeedRequestedEvent(
        page: 1,
        limit: HomeLayoutConstants.feedPageSize,
        isRefresh: true,
        isStory: false,
      ),
    );

    final auctionId = _giftAuctionId;
    if (_isAuctionPost && auctionId != null && auctionId.isNotEmpty) {
      await _refreshAuctionGiftTotal(auctionId);
    } else {
      _bidPopController.forward(from: 0);
    }
  }

  Future<void> _refreshAuctionGiftTotal(String auctionId) async {
    final result = await auctions_di.sl<GetAuctionDetailsUseCase>()(
      GetAuctionDetailsParams(auctionId: auctionId),
    );
    if (!mounted) return;

    result.fold((_) {}, (details) {
      _applyAuctionDetailsFromApi(details, animateBid: true);
    });
  }

  bool get _canSendGiftToHost => widget.post == null || !_isPostOwner();

  Future<void> _showGiftSheet() async {
    if (!_canSendGiftToHost) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.liveGiftCannotSendToSelf)));
      return;
    }

    final post = widget.post;
    String? auctionId;
    if (_isAuctionPost) {
      auctionId = await _ensureGiftAuctionId();
      if (!mounted) return;
      if (auctionId == null || auctionId.isEmpty) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.liveGiftNoRecipient)));
        return;
      }
      // Ensure auction room uses the real UUID (not a post-id fallback).
      unawaited(_ensureAuctionRoomsJoined());
    }

    LiveGiftSheet.show(
      context,
      // Always pass postId so the API creates a gift comment on the post.
      postId: post?.id,
      // Prefer nested user.id — feed sometimes omits top-level userId.
      receiverId: _hostUserId ?? post?.userId,
      auctionId: auctionId,
      liveId: _liveRoomId,
      canSendToHost: _canSendGiftToHost,
      onSmallGiftOptimistic: _showOptimisticSmallGiftCombo,
      onGiftSent: _refreshAfterGift,
    );
  }

  Future<void> _openHostProfile() async {
    final userId = _hostUserId;
    if (userId == null || userId.isEmpty) return;

    final isFollowing = await (_isAuctionPost
        ? openUserProfile(
            context,
            userId: userId,
            username: widget.post?.user?.username,
            fullName: widget.post?.user?.fullName,
            avatarUrl: _avatarUrl(),
            isFollowing: _isFollowing,
          )
        : openUserStoryOrProfile(
            context,
            userId: userId,
            username: widget.post?.user?.username,
            fullName: widget.post?.user?.fullName,
            avatarUrl: _avatarUrl(),
            isFollowing: _isFollowing,
          ));
    if (!mounted || isFollowing == null) return;
    setState(() => _isFollowing = isFollowing);
  }

  String _hostName(AppLocalizations l10n) {
    final fullName = widget.post?.user?.fullName;
    if (fullName != null && fullName.trim().isNotEmpty) return fullName.trim();
    final username = widget.post?.user?.username;
    if (username != null && username.isNotEmpty) return username;
    return l10n.liveHostName(_streamIndex + 1);
  }

  String? _avatarUrl() {
    final avatar = widget.post?.user?.avatarUrl;
    if (avatar == null || avatar.isEmpty || avatar == 'null') return null;
    return avatar;
  }

  String _bidCurrencyLabel(AppLocalizations l10n) {
    if (widget.post?.auction != null) return l10n.coinsUnit;
    return widget.post?.auction?.currencyCode ?? l10n.currencySar;
  }

  String _formatHighestBid(AppLocalizations l10n) {
    final locale = Localizations.localeOf(context);
    if (_showAuctionCoinPricing) {
      return formatAuctionLiveCoinsLabel(l10n, locale, _highestBidCoins);
    }
    final amount = LocaleFormatUtils.localizeDigits('$_highestBid', locale);
    return l10n.liveHighestBidAmount(amount, _bidCurrencyLabel(l10n));
  }

  String? _auctionTargetPriceLabel(AppLocalizations l10n) {
    return formatAuctionTargetPriceLabel(
      auction: widget.post?.auction,
      l10n: l10n,
      locale: Localizations.localeOf(context),
      overrideCoins: _targetPriceCoinsOverride,
    );
  }

  int? get _auctionTargetPrice {
    return resolveAuctionTargetPriceCoins(
      widget.post?.auction,
      overrideCoins: _targetPriceCoinsOverride,
    );
  }

  bool get _isAuctionInPeriod {
    final auction = widget.post?.auction;
    if (auction == null) return false;
    final now = DateTime.now().toUtc();
    final start = auction.startedAt.toUtc();
    final end = auction.endedAt.toUtc();
    return !now.isBefore(start) && now.isBefore(end);
  }

  AuctionCountdownParts _auctionCountdownParts() {
    if (_isAuctionFinished) {
      return const AuctionCountdownParts.finished();
    }

    final auction = widget.post?.auction;
    if (auction == null) {
      return const AuctionCountdownParts.finished();
    }

    final now = DateTime.now().toUtc();
    final start = auction.startedAt.toUtc();
    final end = auction.endedAt.toUtc();

    if (end.isBefore(now) || end.isAtSameMomentAs(now)) {
      return const AuctionCountdownParts.finished();
    }

    final isUpcoming = start.isAfter(now);
    final diff = (isUpcoming ? start : end).difference(now);
    return AuctionCountdownParts(
      days: diff.inDays,
      hours: diff.inHours.remainder(24),
      minutes: diff.inMinutes.remainder(60),
      seconds: diff.inSeconds.remainder(60),
      isUpcoming: isUpcoming,
      isActive: !isUpcoming && !_isAuctionFinished,
    );
  }

  String? get _currentUserId {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthSuccess && authState.user.id.isNotEmpty) {
      return authState.user.id;
    }
    return null;
  }

  List<GiftComboItem> get _myActiveGiftCombos {
    final me = _currentUserId;
    if (me == null) return const [];
    return _activeGiftCombos.values
        .where((item) => item.senderId == me)
        .toList();
  }

  List<GiftComboItem> get _othersActiveGiftCombos {
    final me = _currentUserId;
    if (me == null) return _activeGiftCombos.values.toList();
    return _activeGiftCombos.values
        .where((item) => item.senderId != me)
        .toList();
  }

  Widget? _buildMyGiftCombosBesideLiveChip() {
    final combos = _myActiveGiftCombos;
    if (combos.isEmpty) return null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: combos.take(3).map((item) {
        return Padding(
          key: ValueKey<String>('my-combo-${item.key}'),
          padding: const EdgeInsets.only(bottom: 6),
          child: SmallGiftHighestPriceBadge(
            animationUrl: item.animationUrl,
            thumbnailUrl: item.thumbnailUrl,
            giftName: item.giftName,
            senderName: item.senderName,
            senderAvatarUrl: item.senderAvatarUrl,
            quantity: item.combo,
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final hostName = _hostName(l10n);
    final imageUrls = _displayMedia;
    final hasMultipleMedia = imageUrls.length > 1;
    final isAuctionActive = _isAuctionInPeriod && !_isAuctionFinished;
    final isAuctionFinishedBadge = _isAuctionFinished;
    final targetPrice = _auctionTargetPrice;
    final isPostOwner = _isPostOwner();
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final isKeyboardOpen = keyboardInset > 0;

    final scaffold = Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      // Keep media full-bleed; lift the chrome with [keyboardInset] instead.
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          LiveMediaBackground(
            mediaItems: imageUrls,
            pageController: _mediaPageController,
            currentIndex: _currentImageIndex,
            posterUrl: widget.post == null
                ? null
                : MediaUtils.resolveVideoPosterUrl(widget.post!),
            onPageChanged: (index) =>
                setState(() => _currentImageIndex = index),
          ),
          AnimatedOpacity(
            duration: LiveDetailsLayoutConstants.uiHideDuration,
            opacity: _isUIHidden ? 0 : 1,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.black.withValues(alpha: 0.2),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                      Colors.black.withValues(alpha: 0.95),
                    ],
                    stops: const [0.0, 0.2, 0.45, 0.75, 1.0],
                  ),
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
              setState(() => _isUIHidden = !_isUIHidden);
            },
            onHorizontalDragEnd: hasMultipleMedia
                ? null
                : (details) {
                    final velocity = details.primaryVelocity ?? 0;
                    if (velocity >
                        LiveDetailsLayoutConstants.swipeVelocityThreshold) {
                      setState(() => _isUIHidden = _isRtl ? false : true);
                    } else if (velocity <
                        -LiveDetailsLayoutConstants.swipeVelocityThreshold) {
                      setState(() => _isUIHidden = _isRtl ? true : false);
                    }
                  },
            behavior: HitTestBehavior.translucent,
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: keyboardInset),
              child: AnimatedSlide(
                duration: LiveDetailsLayoutConstants.uiHideDuration,
                offset: _isUIHidden
                    ? Offset(
                        _isRtl
                            ? -LiveDetailsLayoutConstants.uiSlideOffset
                            : LiveDetailsLayoutConstants.uiSlideOffset,
                        0,
                      )
                    : Offset.zero,
                curve: Curves.easeInOutCubic,
                child: AnimatedOpacity(
                  duration: LiveDetailsLayoutConstants.uiHideDuration,
                  opacity: _isUIHidden ? 0 : 1,
                  child: SafeArea(
                    // Avoid stacking home-indicator padding on top of the keyboard.
                    bottom: !isKeyboardOpen,
                    child: Column(
                      children: [
                        if (hasMultipleMedia) ...[
                          const SizedBox(
                            height: LiveDetailsLayoutConstants
                                .mediaPageIndicatorTopPadding,
                          ),
                          MediaPageIndicator(
                            count: imageUrls.length,
                            currentIndex: _currentImageIndex,
                          ),
                          const SizedBox(height: AppSizes.p8),
                        ],
                        LiveDetailsHeader(
                          hostName: hostName,
                          subtitle: widget.post?.auction?.itemName,
                          viewersLabel: _viewersLabel(l10n),
                          avatarUrl: _avatarUrl(),
                          hostUserId: _hostUserId,
                          isFollowing: _isFollowing,
                          followLabel: l10n.liveFollow,
                          followingLabel: l10n.liveFollowing,
                          liveBadgeLabel: isAuctionFinishedBadge
                              ? l10n.auctionFinishedBadge
                              : isAuctionActive
                              ? l10n.auctionActiveBadge
                              : l10n.liveBadge,
                          isAuctionActiveBadge: isAuctionActive,
                          isAuctionFinishedBadge: isAuctionFinishedBadge,
                          pulseAnimation: _pulseAnimation,
                          showCloseButton: !widget.embeddedInFeed,
                          showAuctionGifts: _isAuctionPost,
                          onAuctionGifts: _showAuctionGiftsSheet,
                          showOwnerMenu: isPostOwner,
                          showFollowButton:
                              !isPostOwner &&
                              _hostUserId != null &&
                              !_isAuctionPost,
                          onProfileTap: _hostUserId != null
                              ? _openHostProfile
                              : null,
                          onOwnerMenu: _showOwnerOptions,
                          onClose: () => context.pop(),
                          onFollowTap: _isFollowLoading ? () {} : _toggleFollow,
                          countdownBelowProfile: widget.post?.auction != null
                              ? AuctionCountdownBar(
                                  parts: _auctionCountdownParts(),
                                )
                              : null,
                          belowHostProfile: _buildMyGiftCombosBesideLiveChip(),
                        ),
                        if (!isKeyboardOpen) ...[
                          const Expanded(
                            child: IgnorePointer(child: SizedBox.expand()),
                          ),
                          Align(
                            alignment: _isRtl
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: AuctionPriceWithAudioBadge(
                              activeCombos: _othersActiveGiftCombos,
                              audioGiftLabel: _ephemeralAudioGiftLabel,
                              audioGiftColor: _ephemeralAudioGiftColor,
                              topBidLabel: l10n.liveTopBid,
                              bidAmountText: _formatHighestBid(l10n),
                              bidAmountCoins: _showAuctionCoinPricing
                                  ? _highestBidCoins
                                  : null,
                              showGiftIcon: _usesGiftTotal,
                              showCoinIcon: _showAuctionCoinPricing,
                              targetPrice: targetPrice,
                              targetPriceLabel: _auctionTargetPriceLabel(l10n),
                              targetPriceHeader: l10n.liveTargetPrice,
                              isFinished: _isAuctionFinished,
                              popAnimation: _bidPopAnimation,
                              theme: theme,
                            ),
                          ),
                          if (_showCommentsArea) ...[
                            const SizedBox(height: AppSizes.p12),
                            if (_usesPostComments)
                              LivePostCommentsArea(
                                isRtl: _isRtl,
                                comments: _visiblePostComments,
                                scrollController: _chatScrollController,
                              )
                            else
                              LiveMockChatArea(
                                isRtl: _isRtl,
                                messages: _mockChatMessages,
                                authorLabel: l10n.liveChatYou,
                                scrollController: _chatScrollController,
                              ),
                          ],
                        ] else
                          const Spacer(),
                        if (_biddingEnabled && _canSendGiftToHost)
                          QuickRecommendedSmallGiftsShelf(
                            gifts: _recommendedSmallGifts,
                            onSendGift: _onQuickSendSmallGift,
                          ),
                        GestureDetector(
                          onTap: () {},
                          behavior: HitTestBehavior.opaque,
                          child: LiveBiddingInput(
                            controller: _chatController,
                            hintText: _biddingEnabled
                                ? l10n.addCommentHint
                                : l10n.auctionBiddingClosed,
                            enabled: _biddingEnabled,
                            showGiftButton: _canSendGiftToHost,
                            quickBidAmounts: widget.post != null
                                ? const <int>[]
                                : _biddingEnabled
                                ? LiveDetailsLayoutConstants.quickBidAmounts
                                : const <int>[],
                            quickBidLabelBuilder: (amount) =>
                                l10n.liveQuickBid(amount),
                            theme: theme,
                            onSend: _placeBidOrComment,
                            onGift: _biddingEnabled ? _showGiftSheet : () {},
                            onQuickBid: _addBid,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Widget content = scaffold;

    if (widget.post != null) {
      final postId = widget.post!.id;
      content = BlocListener<PostsBloc, PostsState>(
        listenWhen: (previous, current) =>
            current is DeletePostSuccess && current.postId == postId,
        listener: (context, state) {
          if (state is DeletePostSuccess && state.postId == postId) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.postDeletedSuccessfully)),
            );
            if (!widget.embeddedInFeed && context.canPop()) {
              context.pop();
            }
          }
        },
        child: content,
      );
    }

    if (_commentsBloc == null) {
      return _wrapAuctionLtr(content);
    }

    return _wrapAuctionLtr(
      BlocProvider.value(
        value: _commentsBloc!,
        child: BlocListener<CommentsBloc, CommentsState>(
          listener: (context, state) => _onCommentsState(state),
          child: content,
        ),
      ),
    );
  }

  Widget _wrapAuctionLtr(Widget child) {
    if (!_isAuctionPost) return child;
    return Directionality(textDirection: TextDirection.ltr, child: child);
  }
}

/// TikTok-style horizontal quick recommendation bar for sending small gifts with 1 tap.
class QuickRecommendedSmallGiftsShelf extends StatefulWidget {
  const QuickRecommendedSmallGiftsShelf({
    required this.gifts,
    required this.onSendGift,
    super.key,
  });

  final List<GiftEntity> gifts;
  final ValueChanged<GiftEntity> onSendGift;

  @override
  State<QuickRecommendedSmallGiftsShelf> createState() =>
      _QuickRecommendedSmallGiftsShelfState();
}

class _QuickRecommendedSmallGiftsShelfState
    extends State<QuickRecommendedSmallGiftsShelf> {
  Timer? _holdTimer;
  String? _holdingGiftId;

  @override
  void dispose() {
    _stopHold();
    super.dispose();
  }

  void _stopHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _holdingGiftId = null;
  }

  void _startHold(GiftEntity gift) {
    if (_holdingGiftId == gift.id) return;
    _stopHold();
    _holdingGiftId = gift.id;
    widget.onSendGift(gift);
    _holdTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) {
        _stopHold();
        return;
      }
      widget.onSendGift(gift);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.gifts.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 28,
      margin: const EdgeInsets.only(top: 1, bottom: 2),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.gifts.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final gift = widget.gifts[index];

          return GestureDetector(
            onTap: () => widget.onSendGift(gift),
            onLongPressStart: (_) => _startHold(gift),
            onLongPressEnd: (_) => _stopHold(),
            onLongPressCancel: _stopHold,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildGiftMedia(gift),
                  const SizedBox(width: 4),
                  Text(
                    gift.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.coins,
                          size: 9,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${gift.priceCoins}',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGiftMedia(GiftEntity gift) {
    final image = gift.displayImageUrl;
    if (image != null && image.trim().isNotEmpty) {
      return SafeNetworkImage(
        imageUrl: image.trim(),
        width: 20,
        height: 20,
        fit: BoxFit.contain,
      );
    }
    return Text(gift.icon, style: const TextStyle(fontSize: 15));
  }
}
