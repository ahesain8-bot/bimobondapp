import 'dart:async';
import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../../../core/network/api_exceptions.dart';
import 'package:bimobondapp/features/live_viewer/core/errors/failures.dart';
import '../../domain/entities/live_entity.dart';
import '../../domain/entities/live_feed_page_result.dart';
import '../../domain/entities/live_session_entity.dart';
import '../../domain/repositories/live_repository.dart';
import '../datasources/live_remote_datasource.dart';

class FakeLiveRepository implements LiveRepository {
  final LiveRemoteDataSource _remote;

  FakeLiveRepository(this._remote);

  /// Short TTL so reopening the Lives screen does not stampede `/lives/feed`.
  static const _feedCacheTtl = Duration(seconds: 25);

  LiveFeedPageResult? _feedCache;
  DateTime? _feedCacheAt;
  String? _feedCacheKey;
  Future<Either<Failure, LiveFeedPageResult>>? _feedInFlight;
  String? _feedInFlightKey;

  String _feedKey({
    required int page,
    required int limit,
    String? category,
    bool followingOnly = false,
    double? latitude,
    double? longitude,
  }) => '$page|$limit|${category ?? ''}|$followingOnly|$latitude|$longitude';

  @override
  Future<Either<Failure, LiveFeedPageResult>> getLiveFeed({
    int page = 1,
    int limit = 10,
    String? category,
    bool followingOnly = false,
    double? latitude,
    double? longitude,
    bool forceRefresh = false,
  }) async {
    final key = _feedKey(
      page: page,
      limit: limit,
      category: category,
      followingOnly: followingOnly,
      latitude: latitude,
      longitude: longitude,
    );

    if (!forceRefresh &&
        page == 1 &&
        _feedCache != null &&
        _feedCacheAt != null &&
        _feedCacheKey == key &&
        DateTime.now().difference(_feedCacheAt!) < _feedCacheTtl) {
      return Right(_feedCache!);
    }

    final existing = _feedInFlight;
    if (existing != null && _feedInFlightKey == key) {
      return existing;
    }

    final future = _fetchLiveFeed(
      page: page,
      limit: limit,
      category: category,
      followingOnly: followingOnly,
      latitude: latitude,
      longitude: longitude,
      cacheKey: key,
    );
    _feedInFlight = future;
    _feedInFlightKey = key;
    try {
      return await future;
    } finally {
      if (identical(_feedInFlight, future)) {
        _feedInFlight = null;
        _feedInFlightKey = null;
      }
    }
  }

  Future<Either<Failure, LiveFeedPageResult>> _fetchLiveFeed({
    required int page,
    required int limit,
    String? category,
    bool followingOnly = false,
    double? latitude,
    double? longitude,
    required String cacheKey,
  }) async {
    try {
      final pageResult = await _remote.getLiveFeed(
        page: page,
        limit: limit,
        category: category,
        followingOnly: followingOnly,
        latitude: latitude,
        longitude: longitude,
      );
      final activeLives = pageResult.lives
          .where((l) => l.status == LiveStatus.live)
          .toList();
      final result = LiveFeedPageResult(
        lives: activeLives,
        page: pageResult.page,
        limit: pageResult.limit,
        total: pageResult.total,
        totalPages: pageResult.totalPages,
      );
      if (page == 1) {
        _feedCache = result;
        _feedCacheAt = DateTime.now();
        _feedCacheKey = cacheKey;
      }
      return Right(result);
    } on SocketException catch (e) {
      return Left(
        NetworkFailure(
          'No internet connection. Please check your network and try again.',
          details: e.message,
        ),
      );
    } on TimeoutException {
      return const Left(
        NetworkFailure('Connection timed out. Please try again.'),
      );
    } on UnauthorizedException catch (e) {
      return Left(
        AuthorizationFailure(
          e.message,
          code: e.statusCode?.toString(),
          details: e.details,
        ),
      );
    } on NotFoundException catch (e) {
      return Left(
        NotFoundFailure(
          e.message,
          code: e.statusCode?.toString(),
          details: e.details,
        ),
      );
    } on ServiceUnavailableException catch (e) {
      return Left(
        ServerFailure(
          'Live service is temporarily unavailable. Please try again later.',
          code: e.statusCode?.toString(),
          details: e.details,
        ),
      );
    } on BadRequestException catch (e) {
      return Left(
        ValidationFailure(
          e.message,
          code: e.statusCode?.toString(),
          details: e.details,
        ),
      );
    } on ApiException catch (e) {
      return Left(
        ServerFailure(
          e.message,
          code: e.statusCode?.toString(),
          details: e.details,
        ),
      );
    } catch (e) {
      return Left(ServerFailure('Failed to fetch live feed: $e'));
    }
  }

  @override
  Future<Either<Failure, LiveEntity>> getLiveById(String liveId) async {
    try {
      final live = await _remote.getLiveById(liveId);
      return Right(live);
    } catch (e) {
      return const Left(NotFoundFailure('Live not found'));
    }
  }

  @override
  Future<Either<Failure, List<LiveEntity>>> getLivesByCategory(
    String category, {
    int page = 1,
    int limit = 10,
  }) async {
    final result = await getLiveFeed(
      page: page,
      limit: limit,
      category: category,
    );
    return result.map((pageResult) => pageResult.lives);
  }

  @override
  Future<Either<Failure, List<LiveEntity>>> searchLives(
    String query, {
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final pageResult = await _remote.getLiveFeed(page: page, limit: limit);
      final filtered = pageResult.lives.where((live) {
        final q = query.toLowerCase();
        return live.title.toLowerCase().contains(q) ||
            live.hostName.toLowerCase().contains(q) ||
            live.category.toLowerCase().contains(q);
      }).toList();
      return Right(filtered);
    } catch (e) {
      return Left(ServerFailure('Search failed: $e'));
    }
  }

  final Map<String, Future<Either<Failure, JoinLiveResult>>> _joinInFlight = {};

  final Map<String, String?> _joinCampaigns = {};

  @override
  Future<Either<Failure, JoinLiveResult>> joinLive(
    String liveId, {
    String? campaignId,
  }) async {
    final existing = _joinInFlight[liveId];
    final normalizedCampaignId = campaignId?.trim();
    final attribution =
        normalizedCampaignId == null || normalizedCampaignId.isEmpty
        ? null
        : normalizedCampaignId;
    if (existing != null) {
      if (_joinCampaigns[liveId] != attribution) {
        // One connection per room, with no silent attribution borrowing.
        // The caller can finish its current activation and explicitly retry.
        return const Left(
          ValidationFailure(
            'A different entry for this live is already connecting.',
            code: 'JOIN_CONTEXT_CONFLICT',
          ),
        );
      }
      return existing;
    }

    _joinCampaigns[liveId] = attribution;
    final future = _joinLiveOnce(liveId, campaignId: attribution);
    _joinInFlight[liveId] = future;
    try {
      return await future;
    } finally {
      if (identical(_joinInFlight[liveId], future)) {
        _joinInFlight.remove(liveId);
        _joinCampaigns.remove(liveId);
      }
    }
  }

  Future<Either<Failure, JoinLiveResult>> _joinLiveOnce(
    String liveId, {
    String? campaignId,
  }) async {
    try {
      final result = await _remote.joinLive(liveId, campaignId: campaignId);
      return Right(result);
    } on SocketException catch (e) {
      return Left(
        NetworkFailure(
          'No internet connection. Please check your network and try again.',
          details: e.message,
        ),
      );
    } on TimeoutException {
      return const Left(
        NetworkFailure('Connection timed out. Please try again.'),
      );
    } on UnauthorizedException catch (e) {
      return Left(
        AuthorizationFailure(
          e.message,
          code: e.statusCode?.toString(),
          details: e.details,
        ),
      );
    } on NotFoundException catch (e) {
      return Left(
        NotFoundFailure(
          e.message,
          code: e.statusCode?.toString(),
          details: e.details,
        ),
      );
    } on ApiException catch (e) {
      return Left(
        ServerFailure(
          e.message,
          code: e.statusCode?.toString(),
          details: e.details,
        ),
      );
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('BANNED')) {
        return const Left(
          AuthorizationFailure(
            'You are banned from this live stream.',
            code: 'USER_BANNED',
          ),
        );
      }
      if (msg.contains('ENDED')) {
        return const Left(
          NotFoundFailure('This live stream has ended.', code: 'LIVE_ENDED'),
        );
      }
      if (msg.contains('INVALID_JOIN_RESPONSE')) {
        return const Left(
          ServerFailure(
            'Failed to start stream. Please try again.',
            code: 'INVALID_JOIN_RESPONSE',
          ),
        );
      }
      return Left(ServerFailure('Failed to join live: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> leaveLive(String liveId) async {
    try {
      await _remote.leaveLive(liveId);
      return const Right(null);
    } on SocketException catch (e) {
      return Left(
        NetworkFailure('No internet connection.', details: e.message),
      );
    } on UnauthorizedException catch (e) {
      return Left(
        AuthorizationFailure(
          e.message,
          code: e.statusCode?.toString(),
          details: e.details,
        ),
      );
    } catch (e) {
      return Left(ServerFailure('Failed to leave live: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> reportLive(
    String liveId, {
    required String reason,
    String? details,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> blockHost(String hostId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> unblockHost(String hostId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> followHost(String hostId) async {
    try {
      await _remote.followHost(hostId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Follow failed: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> unfollowHost(String hostId) async {
    try {
      await _remote.unfollowHost(hostId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Unfollow failed: $e'));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getTrendingCategories() async {
    try {
      return Right(await _remote.getTrendingCategories());
    } catch (e) {
      return Left(ServerFailure('Failed to load categories: $e'));
    }
  }

  @override
  Future<Either<Failure, List<LiveEntity>>> getRecommendedLives({
    int limit = 10,
  }) async {
    final result = await getLiveFeed(limit: limit);
    return result.map((pageResult) => pageResult.lives);
  }

  @override
  Future<Either<Failure, void>> banViewer({
    required String liveId,
    required String userId,
    String? reason,
  }) async {
    try {
      await _remote.banViewer(liveId: liveId, userId: userId, reason: reason);
      return const Right(null);
    } on SocketException catch (e) {
      return Left(
        NetworkFailure('No internet connection.', details: e.message),
      );
    } on UnauthorizedException catch (e) {
      return Left(
        AuthorizationFailure(
          e.message,
          code: e.statusCode?.toString(),
          details: e.details,
        ),
      );
    } catch (e) {
      return Left(ServerFailure('Failed to ban viewer: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> unbanViewer({
    required String liveId,
    required String userId,
  }) async {
    try {
      await _remote.unbanViewer(liveId: liveId, userId: userId);
      return const Right(null);
    } on SocketException catch (e) {
      return Left(
        NetworkFailure('No internet connection.', details: e.message),
      );
    } on UnauthorizedException catch (e) {
      return Left(
        AuthorizationFailure(
          e.message,
          code: e.statusCode?.toString(),
          details: e.details,
        ),
      );
    } catch (e) {
      return Left(ServerFailure('Failed to unban viewer: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> muteViewerChat({
    required String liveId,
    required String userId,
    String? reason,
  }) async {
    try {
      await _remote.muteViewerChat(
        liveId: liveId,
        userId: userId,
        reason: reason,
      );
      return const Right(null);
    } on SocketException catch (e) {
      return Left(
        NetworkFailure('No internet connection.', details: e.message),
      );
    } on UnauthorizedException catch (e) {
      return Left(
        AuthorizationFailure(
          e.message,
          code: e.statusCode?.toString(),
          details: e.details,
        ),
      );
    } catch (e) {
      return Left(ServerFailure('Failed to mute viewer chat: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> unmuteViewerChat({
    required String liveId,
    required String userId,
  }) async {
    try {
      await _remote.unmuteViewerChat(liveId: liveId, userId: userId);
      return const Right(null);
    } on SocketException catch (e) {
      return Left(
        NetworkFailure('No internet connection.', details: e.message),
      );
    } on UnauthorizedException catch (e) {
      return Left(
        AuthorizationFailure(
          e.message,
          code: e.statusCode?.toString(),
          details: e.details,
        ),
      );
    } catch (e) {
      return Left(ServerFailure('Failed to unmute viewer chat: $e'));
    }
  }
}
