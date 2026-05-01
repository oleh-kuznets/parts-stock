import 'package:flutter/cupertino.dart';

import '../core/services/sound_service.dart';
import '../features/convert/convert_page.dart';
import '../features/mappings/mappings_page.dart';
import '../features/margins/margins_page.dart';
import '../features/settings/settings_page.dart';
import '../shared/widgets/brand_mark.dart';
import 'app_state.dart';
import 'theme/app_text_styles.dart';
import 'theme/app_theme.dart';
import 'theme/app_theme_preset.dart';

class PartsStockApp extends StatefulWidget {
  const PartsStockApp({super.key, required this.appState});

  final AppState appState;

  @override
  State<PartsStockApp> createState() => _PartsStockAppState();
}

class _PartsStockAppState extends State<PartsStockApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    widget.appState.addListener(_onChange);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    widget.appState.removeListener(_onChange);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    if (widget.appState.themeMode == AppThemeMode.system) {
      setState(() {});
    }
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Brightness _resolveBrightness() {
    switch (widget.appState.themeMode) {
      case AppThemeMode.light:
        return Brightness.light;
      case AppThemeMode.dark:
        return Brightness.dark;
      case AppThemeMode.system:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = _resolveBrightness();
    final AppThemePreset preset = brightness == Brightness.dark
        ? const AppThemePreset.dark()
        : const AppThemePreset.light();
    final AppTextStyles text = AppTextStyles.fromPreset(preset);

    return AppStyleScope(
      preset: preset,
      text: text,
      child: CupertinoApp(
        title: 'Parts Stock',
        debugShowCheckedModeBanner: false,
        theme: AppCupertinoTheme.fromPreset(preset, text),
        home: AppShell(appState: widget.appState),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          DefaultCupertinoLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.appState});

  final AppState appState;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final AppThemePreset preset = context.preset;
    final AppTextStyles t = context.appText;

    final List<_NavDestination> destinations = <_NavDestination>[
      _NavDestination(
        icon: CupertinoIcons.bolt,
        selectedIcon: CupertinoIcons.bolt_fill,
        label: 'Конвертер',
        builder: (BuildContext _) => ConvertPage(appState: widget.appState),
      ),
      _NavDestination(
        icon: CupertinoIcons.square_grid_2x2,
        selectedIcon: CupertinoIcons.square_grid_2x2_fill,
        label: 'Колонки',
        builder: (BuildContext _) => MappingsPage(appState: widget.appState),
      ),
      _NavDestination(
        icon: CupertinoIcons.percent,
        selectedIcon: CupertinoIcons.percent,
        label: 'Націнки',
        builder: (BuildContext _) => MarginsPage(appState: widget.appState),
      ),
      _NavDestination(
        icon: CupertinoIcons.slider_horizontal_3,
        selectedIcon: CupertinoIcons.slider_horizontal_3,
        label: 'Налаштування',
        builder: (BuildContext _) => SettingsPage(appState: widget.appState),
      ),
    ];

    return CupertinoPageScaffold(
      backgroundColor: preset.scaffoldBase,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Expanded(
              child: Row(
                children: <Widget>[
                  _Sidebar(
                    destinations: destinations,
                    activeIndex: _index,
                    onChange: (int next) => setState(() => _index = next),
                  ),
                  Container(width: 1, color: preset.borderSoft),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      transitionBuilder:
                          (Widget child, Animation<double> anim) {
                        return FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.015),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey<int>(_index),
                        child: destinations[_index].builder(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 28,
              color: preset.surfaceBase,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'Parts Stock · CSV → CSV',
                style: t.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavDestination {
  const _NavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.builder,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final WidgetBuilder builder;
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.destinations,
    required this.activeIndex,
    required this.onChange,
  });

  final List<_NavDestination> destinations;
  final int activeIndex;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    final AppThemePreset preset = context.preset;
    final AppTextStyles t = context.appText;
    return Container(
      width: 240,
      decoration: BoxDecoration(color: preset.surfaceBase),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Row(
              children: <Widget>[
                const BrandMark(size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Parts Stock',
                        style: t.titleMedium.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text('CSV перетворювач', style: t.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (int i = 0; i < destinations.length; i++)
            _SidebarItem(
              destination: destinations[i],
              selected: i == activeIndex,
              onTap: () => onChange(i),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
            child: Text(
              'Parts Stock · v1.0',
              style: t.bodySmall.copyWith(color: preset.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final AppThemePreset preset = context.preset;
    final AppTextStyles t = context.appText;
    final bool active = widget.selected;
    final Color background = active
        ? preset.heroEnd.withValues(alpha: 0.12)
        : (_hovered
              ? preset.surfaceMuted.withValues(alpha: 0.6)
              : const Color(0x00000000));
    final Color label = active ? preset.heroEnd : preset.textPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (!widget.selected) SoundService().tap();
            widget.onTap();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  active
                      ? widget.destination.selectedIcon
                      : widget.destination.icon,
                  size: 20,
                  color: label,
                ),
                const SizedBox(width: 12),
                Text(
                  widget.destination.label,
                  style: t.labelLarge.copyWith(
                    color: label,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
