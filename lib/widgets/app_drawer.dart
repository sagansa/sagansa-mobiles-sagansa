import 'dart:convert';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../pages/admin_profile_list_page.dart';
import '../pages/home_page.dart';
import '../pages/printer_settings_page.dart';
import '../pages/profile_page.dart';
import '../pages/sop_list_page.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';
import '../utils/error_utils.dart';
import '../widgets/app_version_text.dart';
import '../widgets/ios_bar_button.dart';

/// Drawer navigasi seragam dengan desain autentik iOS Glassmorphism (Frosted Glass).
class AppDrawer extends StatelessWidget {
  final String userName;
  final String companyName;
  final bool isAdmin;
  final List<Widget> extraItems;
  final bool showAppVersion;
  final Future<void> Function(BuildContext context)? onLogout;

  const AppDrawer({
    super.key,
    required this.userName,
    required this.companyName,
    this.isAdmin = false,
    this.extraItems = const [],
    this.showAppVersion = true,
    this.onLogout,
  });

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'U';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return trimmed.substring(0, trimmed.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final drawerWidth = (mediaQuery.size.width * 0.82).clamp(280.0, 330.0);

    return Drawer(
      width: drawerWidth,
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(
          right: Radius.circular(24),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(
          right: Radius.circular(24),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        const Color(0xFF1C1C1E).withValues(alpha: 0.84),
                        const Color(0xFF141416).withValues(alpha: 0.88),
                      ]
                    : [
                        const Color(0xFFF9F6F0).withValues(alpha: 0.84),
                        const Color(0xFFF2ECE1).withValues(alpha: 0.88),
                      ],
              ),
              border: Border(
                right: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.08),
                  width: 0.8,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.08),
                  blurRadius: 28,
                  offset: const Offset(4, 0),
                ),
              ],
            ),
            child: SafeArea(
              top: true,
              bottom: true,
              child: Column(
                children: [
                  // 1. Header Profil & Brand iOS
                  _buildIosHeader(context),

                  const SizedBox(height: 6),

                  // 2. Konten Menu Gulir (Grouped Inset Style)
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Group 1: Menu Utama
                          _buildIosGroup(
                            context: context,
                            header: 'MENU UTAMA',
                            children: [
                              _buildIosTile(
                                context: context,
                                icon: CupertinoIcons.house_fill,
                                iconColor: const Color(0xFF3B82F6), // iOS Blue
                                title: 'Beranda',
                                onTap: () {
                                  Navigator.pop(context);
                                  final route = ModalRoute.of(context);
                                  final isHome = route is MaterialPageRoute &&
                                      route.builder(context) is HomePage;
                                  if (isHome) return;
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const HomePage()),
                                  );
                                },
                              ),
                              _buildIosTile(
                                context: context,
                                icon: CupertinoIcons.person_crop_circle_fill,
                                iconColor: const Color(0xFF8B5CF6), // iOS Purple
                                title: 'Profil Saya',
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const ProfilePage()),
                                  );
                                },
                              ),
                              // Surat Perusahaan hidup di dashboard Ops
                              // (tab 5 nav bawah), bukan di drawer — lihat
                              // OperationalDashboardPage.
                              _buildIosTile(
                                context: context,
                                icon: CupertinoIcons.printer_fill,
                                iconColor: const Color(0xFF0D9488), // iOS Teal
                                title: 'Printer Thermal',
                                showDivider: isAdmin,
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const PrinterSettingsPage(),
                                    ),
                                  );
                                },
                              ),
                              if (isAdmin)
                                _buildIosTile(
                                  context: context,
                                  icon: CupertinoIcons.person_3_fill,
                                  iconColor: const Color(0xFFD97706), // iOS Amber
                                  title: 'Kelola Profil',
                                  showDivider: false,
                                  onTap: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const AdminProfileListPage(),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),

                          // Group 2: Pengaturan & Preferensi
                          _buildIosGroup(
                            context: context,
                            header: 'PREFERENSI & BANTUAN',
                            children: [
                              Consumer<ThemeProvider>(
                                builder: (context, themeProvider, _) {
                                  final currentMode = themeProvider.themeMode;
                                  final modes = [
                                    ThemeMode.light,
                                    ThemeMode.dark,
                                    ThemeMode.system,
                                  ];
                                  final labels = ['Terang', 'Gelap', 'Sistem'];
                                  final icons = [
                                    CupertinoIcons.sun_max_fill,
                                    CupertinoIcons.moon_fill,
                                    CupertinoIcons.device_phone_portrait,
                                  ];
                                  // Konten Tampilan dirender LANGSUNG sebagai
                                  // anak grup (pola yang sama dengan tile),
                                  // bukan grup/kartu tersendiri — kartu
                                  // bersarang membuat garisnya menempel ke
                                  // garis kartu luar tanpa jarak.
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          14,
                                          16,
                                          16,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  width: 30,
                                                  height: 30,
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                        0xFF6366F1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: const Color(
                                                                0xFF6366F1)
                                                            .withValues(
                                                                alpha: 0.35),
                                                        blurRadius: 6,
                                                        offset:
                                                            const Offset(0, 2),
                                                      ),
                                                    ],
                                                  ),
                                                  child: const Center(
                                                    child: Icon(
                                                      CupertinoIcons.moon_fill,
                                                      size: 17,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  'Tampilan',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        fontSize: 14.5,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        letterSpacing: -0.2,
                                                      ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 14),
                                            Row(
                                              children: List.generate(
                                                modes.length,
                                                (i) {
                                                  final selected =
                                                      currentMode == modes[i];
                                                  final accent = isDark
                                                      ? AppColors.darkPrimary
                                                      : AppColors.primary;
                                                  return Expanded(
                                                    child: GestureDetector(
                                                      onTap: () {
                                                        HapticFeedback
                                                            .lightImpact();
                                                        themeProvider
                                                            .setThemeMode(
                                                                modes[i]);
                                                      },
                                                      child: AnimatedContainer(
                                                        duration: const Duration(
                                                            milliseconds: 200),
                                                        margin: EdgeInsets.only(
                                                          right: i <
                                                                  modes.length -
                                                                      1
                                                              ? 8
                                                              : 0,
                                                        ),
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          vertical: 12,
                                                          horizontal: 8,
                                                        ),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: selected
                                                              ? accent
                                                              : (isDark
                                                                  ? Colors.white
                                                                      .withValues(
                                                                          alpha:
                                                                              0.08)
                                                                  : Colors.black
                                                                      .withValues(
                                                                          alpha:
                                                                              0.05)),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(10),
                                                          border: selected
                                                              ? null
                                                              : Border.all(
                                                                  color: isDark
                                                                      ? Colors
                                                                          .white
                                                                          .withValues(
                                                                              alpha:
                                                                                  0.10)
                                                                      : Colors
                                                                          .black
                                                                          .withValues(
                                                                              alpha:
                                                                                  0.07),
                                                                  width: 0.8,
                                                                ),
                                                        ),
                                                        child: Column(
                                                          children: [
                                                            Icon(
                                                              icons[i],
                                                              size: 18,
                                                              color: selected
                                                                  ? Colors.white
                                                                  : (isDark
                                                                      ? Colors
                                                                          .white
                                                                          .withValues(
                                                                              alpha:
                                                                                  0.6)
                                                                      : Colors
                                                                          .black
                                                                          .withValues(
                                                                              alpha:
                                                                                  0.5)),
                                                            ),
                                                            const SizedBox(
                                                                height: 4),
                                                            Text(
                                                              labels[i],
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                fontWeight: selected
                                                                    ? FontWeight
                                                                        .w700
                                                                    : FontWeight
                                                                        .w500,
                                                                color: selected
                                                                    ? Colors
                                                                        .white
                                                                    : (isDark
                                                                        ? Colors
                                                                            .white
                                                                            .withValues(
                                                                                alpha:
                                                                                    0.6)
                                                                        : Colors
                                                                            .black
                                                                            .withValues(
                                                                                alpha:
                                                                                    0.5)),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Pemisah ke tile berikutnya (Bantuan &
                                      // Panduan) — indent sama dengan divider
                                      // tile (ikon 30 + gap 12 + padding 14).
                                      Padding(
                                        padding: const EdgeInsets.only(left: 56),
                                        child: Divider(
                                          height: 0.5,
                                          thickness: 0.5,
                                          color: isDark
                                              ? Colors.white.withValues(alpha: 0.08)
                                              : Colors.black.withValues(alpha: 0.06),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              _buildIosTile(
                                context: context,
                                icon: CupertinoIcons.question_circle_fill,
                                iconColor:
                                    const Color(0xFF10B981), // iOS Emerald
                                title: 'Bantuan & Panduan',
                                showDivider: false,
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const SopListPage()),
                                  );
                                },
                              ),
                            ],
                          ),

                          // Group 3: Akun / Logout
                          _buildIosGroup(
                            context: context,
                            header: 'AKUN',
                            children: [
                              _buildIosTile(
                                context: context,
                                icon: CupertinoIcons.arrow_right_square_fill,
                                iconColor: const Color(0xFFEF4444), // iOS Red
                                title: 'Keluar',
                                isDestructive: true,
                                showDivider: false,
                                trailing: Icon(
                                  CupertinoIcons.chevron_right,
                                  size: 14,
                                  color: colorScheme.error.withValues(alpha: 0.6),
                                ),
                                onTap: () => _handleLogout(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3. Footer Versi Aplikasi
                  if (showAppVersion)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AppVersionText(),
                          Text(
                            'Sagansa Systems • iOS Edition',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              color: colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Header iOS: Logo Sagansa, Judul Brand, Tombol Tutup silang, dan Kartu Profil Pengguna
  Widget _buildIosHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final roleLabel = isAdmin ? 'Administrator' : 'Staff';
    final initials = _getInitials(userName);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Baris 1: Logo, Brand text, dan Tombol X
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.06),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SvgPicture.asset(
                  'assets/images/logo.svg',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SAGANSA',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      fontSize: 14,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Management Systems',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10.5,
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Tombol Tutup X melingkar khas iOS
              IosBarButton(
                size: 30,
                tooltip: 'Tutup Menu',
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
                child: Icon(
                  CupertinoIcons.xmark,
                  size: 14,
                  color: colorScheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Baris 2: Kartu Profil Pengguna (iOS Inset Card)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.80),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.black.withValues(alpha: 0.05),
                width: 0.8,
              ),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.025),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              children: [
                // Avatar inisial
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                              AppColors.darkPrimary,
                              AppColors.darkPrimary.withValues(alpha: 0.75),
                            ]
                          : [
                              AppColors.primary,
                              AppColors.primary.withValues(alpha: 0.85),
                            ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isDark
                                ? AppColors.darkPrimary
                                : AppColors.primary)
                            .withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        color:
                            isDark ? AppColors.darkOnPrimary : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        userName.isNotEmpty ? userName : 'Pengguna Sagansa',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          letterSpacing: -0.2,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: isAdmin
                                  ? (isDark
                                      ? AppColors.darkPrimaryContainer
                                      : AppColors.primaryContainer)
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.10)
                                      : Colors.black.withValues(alpha: 0.05)),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              roleLabel,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: isAdmin
                                    ? (isDark
                                        ? AppColors.darkOnPrimaryContainer
                                        : AppColors.onPrimaryContainer)
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              companyName.isNotEmpty
                                  ? companyName
                                  : 'Sagansa Group',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                                color: colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.75),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Grup menu ala iOS Grouped List (kartu rounded dengan hairline border)
  Widget _buildIosGroup({
    required BuildContext context,
    String? header,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.only(left: 18, bottom: 6, top: 12),
            child: Text(
              header,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
              width: 0.8,
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.025),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ],
    );
  }

  /// Baris menu individual bergaya iOS Settings & Sidebar
  Widget _buildIosTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    required VoidCallback onTap,
    bool isDestructive = false,
    bool showDivider = true,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        splashColor: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.05),
        highlightColor: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.02),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  // Kotak ikon warna-warni khas iOS
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: iconColor,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: iconColor.withValues(alpha: 0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        icon,
                        size: 17,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Judul & subjudul
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.2,
                            color: isDestructive
                                ? colorScheme.error
                                : colorScheme.onSurface,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 1),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11.5,
                              color: colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Trailing (Chevron atau tombol switch)
                  trailing ??
                      Icon(
                        CupertinoIcons.chevron_right,
                        size: 14,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.25)
                            : Colors.black.withValues(alpha: 0.22),
                      ),
                ],
              ),
            ),
            if (showDivider)
              Padding(
                padding: const EdgeInsets.only(left: 56),
                child: Divider(
                  height: 0.5,
                  thickness: 0.5,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Dialog konfirmasi logout menggunakan CupertinoAlertDialog khas iOS
  Future<void> _handleLogout(BuildContext context) async {
    HapticFeedback.lightImpact();
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Konfirmasi Keluar'),
        content: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('Apakah Anda yakin ingin keluar dari sesi akun ini?'),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      Navigator.pop(context); // Tutup drawer terlebih dahulu
      if (onLogout != null) {
        await onLogout!(context);
      } else {
        await _defaultLogout(context);
      }
    }
  }

  Future<void> _defaultLogout(BuildContext context) async {
    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.logout();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/login',
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.sanitize(e))),
        );
      }
    }
  }

  /// Helper pembaca data user dari SharedPreferences (seragam dengan
  /// DashboardScaffold) agar pemanggil tidak perlu duplikasi.
  /// Mengembalikan name, company, dan isAdmin.
  static Future<Map<String, dynamic>> loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userString = prefs.getString('user');
      if (userString != null) {
        final userData = json.decode(userString);
        final roles = List<String>.from(userData['roles'] ?? []);
        final isAdmin =
            roles.contains('admin') || roles.contains('super_admin');
        return {
          'name': userData['name'] ?? '',
          'company': userData['company']?['name'] ?? 'SAGANSA',
          'isAdmin': isAdmin,
        };
      }
    } catch (_) {}
    return {'name': '', 'company': 'SAGANSA', 'isAdmin': false};
  }

  /// Set menu tambahan yang seragam untuk seluruh halaman (Home maupun
  /// dashboard operasional): Profil Saya, dan Kelola Profil (khusus admin).
  static List<Widget> buildStandardExtraItems(BuildContext context,
      {required bool isAdmin}) {
    return [
      ListTile(
        leading: const Icon(Icons.person_outline),
        title: const Text('Profil Saya'),
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfilePage()),
          );
        },
      ),
      if (isAdmin)
        ListTile(
          leading: const Icon(Icons.manage_accounts_outlined),
          title: const Text('Kelola Profil'),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const AdminProfileListPage()),
            );
          },
        ),
    ];
  }
}
