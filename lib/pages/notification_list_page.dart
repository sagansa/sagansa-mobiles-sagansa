// ====================================================================
// Halaman Notification Center — daftar notifikasi (bell icon).
// ListView notifikasi dengan indikator unread, tap → mark read + deep-link,
// swipe-to-delete per item, tombol "Hapus semua" (dengan konfirmasi),
// "Tandai semua dibaca", pull-to-refresh, dan load-more paginasi.
//
// Badge unread & event notifikasi baru dikelola oleh NotificationProvider
// (global). Saat push FCM masuk, provider menaikkan `revision` → halaman ini
// otomatis reload halaman pertama.
// ====================================================================

import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/notification_model.dart';
import '../providers/notification_provider.dart';
import '../services/notification_router.dart';
import '../services/notification_service.dart';
import '../theme/app_button_style.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/glass_app_bar.dart';

class NotificationListPage extends StatefulWidget {
  const NotificationListPage({super.key});

  @override
  State<NotificationListPage> createState() => _NotificationListPageState();
}

class _NotificationListPageState extends State<NotificationListPage> {
  final NotificationService _service = NotificationService.instance;
  final NotificationProvider _provider = NotificationProvider.instance;

  List<NotificationModel> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  final int _perPage = 20;
  String? _error;

  /// Revision provider terakhir yang sudah ditangani. Bila provider
  /// menaikkan `revision` (notifikasi baru masuk dari push), reload halaman 1.
  int _lastRevision = 0;

  @override
  void initState() {
    super.initState();
    _lastRevision = _provider.revision;
    _provider.addListener(_onProviderChanged);
    _loadInitial();
  }

  @override
  void dispose() {
    _provider.removeListener(_onProviderChanged);
    super.dispose();
  }

  /// Notifikasi baru dari luar (push) → reload halaman pertama.
  void _onProviderChanged() {
    final revision = _provider.revision;
    if (revision != _lastRevision) {
      _lastRevision = revision;
      _loadInitial();
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
    });
    try {
      final result = await _service.getNotifications(page: 1, perPage: _perPage);
      _items = result['data'] as List<NotificationModel>;
      _hasMore = result['has_more'] as bool;
      _page = 1;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
      _provider.refreshUnreadCount();
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final next = _page + 1;
      final result =
          await _service.getNotifications(page: next, perPage: _perPage);
      final more = result['data'] as List<NotificationModel>;
      _items.addAll(more);
      _hasMore = result['has_more'] as bool;
      _page = next;
    } catch (_) {
      // Gagal load more — abaikan (user bisa refresh).
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _onTapItem(NotificationModel item) async {
    // Langsung navigasi (router memakai type + data untuk deep-link).
    _navigate(item);

    // Tandai dibaca bila belum (best-effort, tidak blocking UI).
    if (!item.isRead) {
      try {
        await _service.markRead(item.id);
        if (mounted) {
          setState(() {
            final idx = _items.indexWhere((e) => e.id == item.id);
            if (idx != -1) {
              _items[idx] = NotificationModel(
                id: item.id,
                type: item.type,
                title: item.title,
                body: item.body,
                data: item.data,
                readAt: DateTime.now(),
                createdAt: item.createdAt,
              );
            }
          });
        }
        _provider.refreshUnreadCount();
      } catch (_) {
        // abaikan kegagalan mark-read
      }
    }
  }

  void _navigate(NotificationModel item) {
    final payload = <String, dynamic>{
      'type': item.type,
      if (item.data != null) ...item.data!,
    };
    navigateToNotification(payload);
  }

  /// Swipe-to-delete: panggil API; gagal → kembalikan item + snackbar error.
  Future<bool> _confirmDismiss(NotificationModel item) async {
    try {
      await _service.deleteNotification(item.id);
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus notifikasi: $e')),
        );
      }
      return false;
    }
  }

  /// Item terhapus → hapus dari list & refresh badge unread.
  void _onDismissed(NotificationModel item) {
    setState(() {
      _items.removeWhere((e) => e.id == item.id);
    });
    _provider.refreshUnreadCount();
  }

  Future<void> _markAllRead() async {
    try {
      await _service.markAllRead();
      if (mounted) {
        setState(() {
          _items = _items
              .map((e) => e.isRead
                  ? e
                  : NotificationModel(
                      id: e.id,
                      type: e.type,
                      title: e.title,
                      body: e.body,
                      data: e.data,
                      readAt: DateTime.now(),
                      createdAt: e.createdAt,
                    ))
              .toList();
        });
        _provider.refreshUnreadCount();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Semua notifikasi ditandai dibaca.')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menandai dibaca: $e')),
      );
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus semua notifikasi?'),
        content: const Text(
          'Semua notifikasi akan dihapus permanen. Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: AppButtonStyle.text(foregroundColor: AppColors.error),
            child: const Text('Hapus semua'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _service.clearAll();
      if (mounted) {
        setState(() {
          _items = [];
          _hasMore = false;
          _page = 1;
        });
        _provider.refreshUnreadCount();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Semua notifikasi dihapus.')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus semua: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: GlassAppBar(
        title: const Text('Notifikasi'),
        actions: [
          TextButton.icon(
            onPressed: _items.any((e) => !e.isRead) ? _markAllRead : null,
            icon: const Icon(Icons.done_all),
            label: const Text('Tandai semua'),
          ),
          TextButton.icon(
            onPressed: _items.isEmpty ? null : _clearAll,
            icon: const Icon(Icons.delete_sweep),
            label: const Text('Hapus semua'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadInitial,
        child: _buildBody(theme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Gagal memuat notifikasi.', style: theme.textTheme.bodyMedium),
            AppSpacing.gapVerticalSM,
            ElevatedButton(
              onPressed: _loadInitial,
              child: const Text('Coba lagi'),
            ),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off,
                size: 64, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('Belum ada notifikasi.',
                style: theme.textTheme.bodyMedium),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8).copyWith(
        top: AppBarInsets.top(context),
      ),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          // Footer load-more.
          return _loadingMore
              ? const Center(
                  child: Padding(
                    padding: AppSpacing.paddingMD,
                    child: CircularProgressIndicator(),
                  ),
                )
              : Center(
                  child: TextButton(
                    onPressed: _loadMore,
                    child: const Text('Muat lebih banyak'),
                  ),
                );
        }
        return _buildItem(_items[index], theme);
      },
    );
  }

  Widget _buildItem(NotificationModel item, ThemeData theme) {
    final unread = !item.isRead;
    return Dismissible(
      key: ValueKey('notification-${item.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDismiss(item),
      onDismissed: (_) => _onDismissed(item),
      background: Container(
        color: AppColors.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: ListTile(
        leading: unread
            ? badges.Badge(
                showBadge: true,
                badgeContent: const SizedBox.shrink(),
                badgeStyle: badges.BadgeStyle(
                  badgeColor: AppColors.primary,
                  padding: const EdgeInsets.all(4),
                ),
                child: const Icon(Icons.notifications),
              )
            : const Icon(Icons.notifications_none),
        title: Text(
          item.title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: unread ? FontWeight.bold : FontWeight.normal,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            AppSpacing.gapVerticalXS,
            Text(
              _relativeTime(item.createdAt),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        onTap: () => _onTapItem(item),
      ),
    );
  }

  String _relativeTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inSeconds < 60) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return DateFormat('d MMM yyyy', 'id_ID').format(date);
  }
}
