import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/leave_model.dart';
import '../services/leave_service.dart';
import '../theme/app_button_style.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/approval_action_buttons.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/leave_detail_bottom_sheet.dart';
import '../widgets/leave_stats_header.dart';
import '../widgets/modern_bottom_nav.dart';
import '../widgets/modern_fab.dart';
import 'leave_form_page.dart';

class LeavePage extends StatefulWidget {
  const LeavePage({super.key});

  @override
  LeavePageState createState() => LeavePageState();
}

class LeavePageState extends State<LeavePage> {
  final LeaveService _leaveService = LeaveService();
  final ScrollController _scrollController = ScrollController();
  List<LeaveModel> _leaves = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isAdmin = false;
  String? _errorMessage;
  int _page = 1;
  bool _hasMore = true;
  String? _selectedStatus;



  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadUserRole();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        !_isLoading &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString('user');
    if (userString != null) {
      final userData = json.decode(userString);
      final roles = List<String>.from(userData['roles'] ?? []);
      setState(() {
        // Hanya role 'admin' yang melihat semua pengajuan + approve/reject.
        // Role lain (super_admin/owner/supervisor/dst.) melihat milik sendiri —
        // endpoint /leaves (LeaveController::index) sudah memfilter berdasarkan
        // created_by_id untuk seluruh non-admin.
        _isAdmin = roles.contains('admin');
      });
    }
    _loadLeaves();
  }

  Future<void> _loadLeaves() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _page = 1;
      _hasMore = true;
    });

    try {
      if (_isAdmin) {
        final result = await _leaveService.getAdminLeaves(
          page: 1,
          status: _selectedStatus,
        );
        setState(() {
          _leaves = (result['data'] as List)
              .map((e) => LeaveModel.fromJson(e as Map<String, dynamic>))
              .toList();
          _hasMore = _page < (result['meta']['last_page'] ?? 1);
          _isLoading = false;
        });
      } else {
        final result = await _leaveService.getLeavesPaged(page: _page);
        setState(() {
          _leaves = result['data'] as List<LeaveModel>;
          _hasMore = result['has_more'] as bool;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _isLoadingMore || _isLoading) return;
    setState(() => _isLoadingMore = true);

    try {
      if (_isAdmin) {
        final result = await _leaveService.getAdminLeaves(
          page: _page + 1,
          status: _selectedStatus,
        );
        setState(() {
          _leaves.addAll((result['data'] as List)
              .map((e) => LeaveModel.fromJson(e as Map<String, dynamic>))
              .toList());
          _page++;
          _hasMore = _page < (result['meta']['last_page'] ?? 1);
        });
      } else {
        final result = await _leaveService.getLeavesPaged(page: _page + 1);
        setState(() {
          _leaves.addAll(result['data'] as List<LeaveModel>);
          _page++;
          _hasMore = result['has_more'] as bool;
        });
      }
    } catch (_) {
      // ignore pagination errors, allow retry on next scroll
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Color _getStatusColor(dynamic status) {
    final s = status is int ? status : int.tryParse(status.toString()) ?? 0;
    switch (s) {
      case 1:
        return AppColors.warning;
      case 2:
        return AppColors.success;
      case 3:
        return AppColors.error;
      default:
        return AppColors.onSurfaceVariant;
    }
  }

  String _getStatusText(dynamic status) {
    final s = status is int ? status : int.tryParse(status.toString()) ?? 0;
    switch (s) {
      case 1:
        return 'Pending';
      case 2:
        return 'Disetujui';
      case 3:
        return 'Ditolak';
      default:
        return 'Unknown';
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  Future<void> _approveLeave(LeaveModel leave) async {
    try {
      setState(() => _isLoading = true);
      await _leaveService.approveLeave(leave.id);
      await _loadLeaves();
      if (mounted) {
        SnackbarUtils.success(
          context,
          'Cuti ${leave.createdBy.name} berhasil disetujui',
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        SnackbarUtils.error(context, e);
      }
    }
  }

  Future<void> _rejectLeave(LeaveModel leave) async {
    final notesController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tolak Cuti'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tolak pengajuan cuti dari ${leave.createdBy.name}?'),
            AppSpacing.gapVerticalMD,
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Catatan penolakan (opsional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: AppButtonStyle.filled(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => _isLoading = true);
      await _leaveService.rejectLeave(
        leave.id,
        rejectNote: notesController.text.isNotEmpty ? notesController.text : null,
      );
      await _loadLeaves();
      if (mounted) {
        SnackbarUtils.error(
          context,
          'Pengajuan cuti ${leave.createdBy.name} ditolak',
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        SnackbarUtils.error(context, e);
      }
    }
  }

  void _openLeaveDetail(LeaveModel leave) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LeaveDetailBottomSheet(
        leave: leave,
        isAdmin: _isAdmin,
        onApprove: () => _approveLeave(leave),
        onReject: () => _rejectLeave(leave),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _leaves.where((l) => l.status == 1).length;
    final approvedCount = _leaves.where((l) => l.status == 2).length;
    final rejectedCount = _leaves.where((l) => l.status == 3).length;

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: GlassAppBar(
        title: const Text('Cuti & Izin'),
        centerTitle: true,
      ),
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
        children: [
          // Header Stats summary
          LeaveStatsHeader(
            totalCount: _leaves.length,
            pendingCount: pendingCount,
            approvedCount: approvedCount,
            rejectedCount: rejectedCount,
            activeStatus: _selectedStatus,
            onStatusSelected: (status) {
              setState(() => _selectedStatus = status);
              _loadLeaves();
            },
          ),
          // Main list content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _buildErrorWidget()
                    : _leaves.isEmpty
                        ? _buildEmptyWidget()
                        : _buildListWidget(),
          ),
        ],
      ),
      ),
      bottomNavigationBar: ModernBottomNav(
        currentIndex: 1,
        onTap: (index) {
          if (index != 1) {
            Navigator.pop(context);
          }
        },
      ),
      floatingActionButton: CustomFAB(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LeaveFormPage()),
          );
          if (result == true) {
            _loadLeaves();
          }
        },
        icon: Icons.event_busy,
        tooltip: 'Tambah Cuti',
      ),
    );
  }

  Widget _buildErrorWidget() {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: AppSpacing.paddingLG,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: colorScheme.error),
            AppSpacing.gapVerticalMD,
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            AppSpacing.gapVerticalLG,
            ElevatedButton(
              onPressed: _loadLeaves,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWidget() {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 64, color: colorScheme.outline),
          AppSpacing.gapVerticalMD,
          Text('Belum ada data cuti.', style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }

  Widget _buildListWidget() {
    return RefreshIndicator(
      onRefresh: _loadLeaves,
      child: ListView.builder(
        controller: _scrollController,
        padding: AppSpacing.paddingMD
            .copyWith(bottom: ModernBottomNav.clearance(context)),
        itemCount: _leaves.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _leaves.length) {
            return _isLoadingMore
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : const SizedBox.shrink();
          }
          final leave = _leaves[index];
          return _buildLeaveCard(leave);
        },
      ),
    );
  }

  String _formatDate(dynamic dateOrStr) {
    if (dateOrStr == null) return '-';
    DateTime date;
    if (dateOrStr is DateTime) {
      date = dateOrStr;
    } else {
      final str = dateOrStr.toString();
      if (str.isEmpty) return '-';
      try {
        date = DateTime.parse(str);
      } catch (_) {
        return str;
      }
    }
    return DateFormat('d MMM yyyy', 'id_ID').format(date);
  }

  Widget _buildLeaveCard(LeaveModel leave) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusColor = _getStatusColor(leave.status);
    final initials = _getInitials(leave.createdBy.name);
    final isPending = leave.status == 1;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusMD,
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        borderRadius: AppSpacing.borderRadiusMD,
        onTap: () => _openLeaveDetail(leave),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Avatar / Initial + Name/Reason + Status Badge
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: colorScheme.primaryContainer,
                    child: Text(
                      initials,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isAdmin ? leave.createdBy.name : leave.formattedReason,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_isAdmin)
                          Text(
                            leave.formattedReason,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: AppSpacing.borderRadiusLG,
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      _getStatusText(leave.status),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Row 2: Date range & Duration pill badge
              Row(
                children: [
                  Icon(Icons.date_range_rounded, size: 16, color: colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${_formatDate(leave.fromDate)} - ${_formatDate(leave.untilDate)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: AppSpacing.borderRadiusMD,
                    ),
                    child: Text(
                      leave.durationText,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (leave.notes != null && leave.notes.toString().isNotEmpty) ...[
                AppSpacing.gapVerticalSM,
                Text(
                  leave.notes.toString(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              // Admin Actions (if pending)
              if (_isAdmin && isPending) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                ApprovalActionButtons(
                  onApprove: () => _approveLeave(leave),
                  onReject: () => _rejectLeave(leave),
                  height: 36,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
