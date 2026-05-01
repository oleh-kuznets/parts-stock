import 'dart:ui' show AppExitResponse, PathMetric;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/cupertino.dart';

import '../core/services/sound_service.dart';
import '../features/convert/convert_page.dart';
import '../features/mappings/mappings_page.dart';
import '../features/margins/margins_page.dart';
import '../features/settings/settings_page.dart';
import '../shared/widgets/app_dialogs.dart';
import '../shared/widgets/app_toast.dart';
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
  /// Held by [CupertinoApp] so we can present the "are you sure?" dialog
  /// from the OS-level exit handler — which runs outside the widget tree
  /// and therefore has no `BuildContext` of its own.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    widget.appState.addListener(_onChange);
    WidgetsBinding.instance.addObserver(this);
    _lifecycle = AppLifecycleListener(onExitRequested: _onExitRequested);
  }

  @override
  void dispose() {
    widget.appState.removeListener(_onChange);
    WidgetsBinding.instance.removeObserver(this);
    _lifecycle.dispose();
    super.dispose();
  }

  /// Intercepts the OS close request (Cmd-Q / red traffic light /
  /// Alt-F4 / window close button). When a conversion is in flight we
  /// stop and ask the user before letting the process die — losing a
  /// half-written CSV is not a great experience.
  Future<AppExitResponse> _onExitRequested() async {
    if (!widget.appState.isConverting) return AppExitResponse.exit;
    final BuildContext? ctx = _navigatorKey.currentContext;
    if (ctx == null) return AppExitResponse.exit;
    final bool? confirmed = await showAppConfirm(
      ctx,
      title: 'Закрити під час конвертації?',
      message:
          'Зараз йде конвертація. Якщо вийдеш — у теці лишаться '
          'недописані файли.',
      confirmLabel: 'Закрити все одно',
      cancelLabel: 'Не закривати',
      destructive: true,
    );
    return confirmed == true ? AppExitResponse.exit : AppExitResponse.cancel;
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
        navigatorKey: _navigatorKey,
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
  bool _dropping = false;

  // Destinations are described once (icons / label / page builder) and
  // then mounted on first visit — see `_LazyTabStack` below. Pages are
  // kept alive across tab switches so flipping back is instant: no
  // controller re-creation, no `path_provider` re-roundtrips, no scroll
  // reset. Crucially, this also keeps the conversion alive when the user
  // wanders off to "Налаштування" mid-run (the queue + stream subscription
  // live in `ConvertPage` state).
  late final List<_NavDestination> _destinations = <_NavDestination>[
    _NavDestination(
      icon: CupertinoIcons.bolt,
      selectedIcon: CupertinoIcons.bolt_fill,
      label: 'Конвертер',
      build: (BuildContext _) => ConvertPage(appState: widget.appState),
    ),
    _NavDestination(
      icon: CupertinoIcons.square_grid_2x2,
      selectedIcon: CupertinoIcons.square_grid_2x2_fill,
      label: 'Колонки',
      build: (BuildContext _) => MappingsPage(appState: widget.appState),
    ),
    _NavDestination(
      icon: CupertinoIcons.percent,
      selectedIcon: CupertinoIcons.percent,
      label: 'Націнки',
      build: (BuildContext _) => MarginsPage(appState: widget.appState),
    ),
    _NavDestination(
      icon: CupertinoIcons.slider_horizontal_3,
      selectedIcon: CupertinoIcons.slider_horizontal_3,
      label: 'Налаштування',
      build: (BuildContext _) => SettingsPage(appState: widget.appState),
    ),
  ];

  void _onDragEntered() {
    if (_dropping) return;
    setState(() => _dropping = true);
  }

  void _onDragExited() {
    if (!_dropping) return;
    setState(() => _dropping = false);
  }

  Future<void> _onDropDone(DropDoneDetails details) async {
    final List<String> csv = <String>[
      for (final DropItem f in details.files)
        if (f.path.toLowerCase().endsWith('.csv')) f.path,
    ];
    setState(() => _dropping = false);
    if (csv.isEmpty) {
      AppToast.show(
        context,
        'Кидай тільки .csv — інше я не приймаю',
        tone: AppToastTone.warning,
      );
      return;
    }
    SoundService().drop();
    widget.appState.emitDroppedFiles(csv);
    if (_index != 0) setState(() => _index = 0);
  }

  @override
  Widget build(BuildContext context) {
    final AppThemePreset preset = context.preset;

    return CupertinoPageScaffold(
      backgroundColor: preset.scaffoldBase,
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double width = constraints.maxWidth;
            final _SidebarMode mode;
            if (width < 720) {
              mode = _SidebarMode.icons;
            } else {
              mode = _SidebarMode.full;
            }
            return Row(
              children: <Widget>[
                RepaintBoundary(
                  child: _Sidebar(
                    destinations: _destinations,
                    activeIndex: _index,
                    onChange: _onSelectIndex,
                    mode: mode,
                  ),
                ),
                Container(width: 1, color: preset.borderSoft),
                Expanded(
                  child: DropTarget(
                    onDragEntered: (_) => _onDragEntered(),
                    onDragExited: (_) => _onDragExited(),
                    onDragDone: _onDropDone,
                    // Page area lives in its own paint layer so the sidebar
                    // glider's 280 ms animation doesn't dirty the (much
                    // bigger) page bitmap on every frame.
                    child: RepaintBoundary(
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          // All four feature pages are mounted up-front
                          // and kept alive — see `_AliveTabStack`. Tab
                          // switches become a paint-layer flip rather than
                          // a teardown + rebuild + first-paint shader
                          // compile (which on Windows reliably looked like
                          // the app had hung).
                          _AliveTabStack(
                            index: _index,
                            childCount: _destinations.length,
                            builder: (BuildContext ctx, int i) =>
                                _destinations[i].build(ctx),
                          ),
                          // Only rendered while a drag is in flight. Keeping
                          // it permanently alive (with `AnimatedOpacity` at 0)
                          // would cost a layer and a CustomPainter pass on
                          // every frame for nothing.
                          if (_dropping)
                            const IgnorePointer(
                              child: RepaintBoundary(child: _DropOverlay()),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _onSelectIndex(int next) {
    if (next == _index) return;
    setState(() => _index = next);
  }
}

enum _SidebarMode { full, icons }

/// Eager, shader-prewarming tab stack for the four feature pages.
///
/// Mounts all pages once and keeps them alive across tab switches. The first
/// frame paints the pages once so Windows doesn't have to build a new page and
/// compile its shaders on the user's first navigation click.
///
/// State (controllers, listeners, `_runStates`, scroll position, ...) is
/// preserved across tab flips because each child sits behind a stable
/// `ValueKey<int>(i)` regardless of stack order.
class _AliveTabStack extends StatefulWidget {
  const _AliveTabStack({
    required this.index,
    required this.childCount,
    required this.builder,
  });

  final int index;
  final int childCount;
  final IndexedWidgetBuilder builder;

  @override
  State<_AliveTabStack> createState() => _AliveTabStackState();
}

class _AliveTabStackState extends State<_AliveTabStack> {
  bool _shadersPrewarmed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted) return;
      setState(() => _shadersPrewarmed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> stacked = <Widget>[];
    for (int i = 0; i < widget.childCount; i++) {
      if (i == widget.index) continue;
      stacked.add(_wrap(i, active: false));
    }
    stacked.add(_wrap(widget.index, active: true));

    return Stack(fit: StackFit.expand, children: stacked);
  }

  Widget _wrap(int i, {required bool active}) {
    final bool offstage = !active && _shadersPrewarmed;
    return Positioned.fill(
      key: ValueKey<int>(i),
      child: Offstage(
        offstage: offstage,
        child: TickerMode(
          enabled: active,
          child: RepaintBoundary(child: widget.builder(context, i)),
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
    required this.build,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final WidgetBuilder build;
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.destinations,
    required this.activeIndex,
    required this.onChange,
    required this.mode,
  });

  // Each row gets a fixed height so a single shared "glider" can
  // smoothly animate between them.
  static const double _itemHeightFull = 42;
  static const double _itemHeightCompact = 46;
  static const double _itemHorizontalPadFull = 12;
  static const double _itemHorizontalPadCompact = 10;

  final List<_NavDestination> destinations;
  final int activeIndex;
  final ValueChanged<int> onChange;
  final _SidebarMode mode;

  @override
  Widget build(BuildContext context) {
    final AppThemePreset preset = context.preset;
    final AppTextStyles t = context.appText;
    final bool full = mode == _SidebarMode.full;
    final double width = full ? 232 : 72;
    final double itemH = full ? _itemHeightFull : _itemHeightCompact;
    final double horizontalPad = full
        ? _itemHorizontalPadFull
        : _itemHorizontalPadCompact;
    final double listHeight = destinations.length * itemH;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: width,
      decoration: BoxDecoration(color: preset.surfaceBase),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: full
                ? const EdgeInsets.fromLTRB(20, 24, 20, 22)
                : const EdgeInsets.fromLTRB(14, 24, 14, 22),
            child: full
                ? Row(
                    children: <Widget>[
                      const BrandMark(size: 36),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Parts Stock',
                          style: t.titleMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                : const Center(child: BrandMark(size: 36)),
          ),
          SizedBox(
            height: listHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (int i = 0; i < destinations.length; i++)
                  SizedBox(
                    height: itemH,
                    child: _SidebarItem(
                      destination: destinations[i],
                      selected: i == activeIndex,
                      onTap: () => onChange(i),
                      compact: !full,
                      horizontalPad: horizontalPad,
                    ),
                  ),
              ],
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
    required this.compact,
    required this.horizontalPad,
  });

  final _NavDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;
  final double horizontalPad;

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

    final Color iconColor = active
        ? preset.heroEnd
        : preset.textPrimary.withValues(alpha: 0.78);
    final Color labelColor = active
        ? preset.heroEnd
        : preset.textPrimary.withValues(alpha: 0.86);

    final Widget tileContent = widget.compact
        ? Center(
            child: Icon(
              active
                  ? widget.destination.selectedIcon
                  : widget.destination.icon,
              size: 20,
              color: iconColor,
            ),
          )
        : Row(
            children: <Widget>[
              Icon(
                active
                    ? widget.destination.selectedIcon
                    : widget.destination.icon,
                size: 18,
                color: iconColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.destination.label,
                  style: t.labelLarge.copyWith(
                    color: labelColor,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: widget.horizontalPad,
        vertical: 3,
      ),
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
          child: Container(
            padding: widget.compact
                ? const EdgeInsets.symmetric(horizontal: 8)
                : const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: active
                  ? preset.heroEnd.withValues(alpha: 0.12)
                  : _hovered
                  ? preset.surfaceMuted.withValues(alpha: 0.7)
                  : const Color(0x00000000),
              borderRadius: BorderRadius.circular(10),
            ),
            child: tileContent,
          ),
        ),
      ),
    );
  }
}

/// Full-bleed overlay shown while a file is being dragged over the
/// content canvas. Uses a frosted-glass surface with a dashed accent
/// border and a pulsing "drop here" prompt. Positioned inside a
/// non-interactive `IgnorePointer` so it never blocks the drop event
/// itself.
class _DropOverlay extends StatelessWidget {
  const _DropOverlay();

  @override
  Widget build(BuildContext context) {
    final AppThemePreset preset = context.preset;
    final AppTextStyles t = context.appText;
    final Color accent = preset.heroEnd;

    return Container(
      color: preset.scaffoldBase.withValues(alpha: 0.78),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: accent,
            strokeWidth: 2,
            dashLength: 10,
            gapLength: 6,
            cornerRadius: 22,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 44),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    CupertinoIcons.cloud_upload_fill,
                    size: 30,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Кидай сюди CSV',
                  style: t.headlineSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: preset.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Я підхоплю файли і додам їх у чергу конвертера.',
                  style: t.bodyMedium.copyWith(color: preset.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints a dashed rounded-rectangle border around the child, used by
/// [_DropOverlay] for a soft "target zone" treatment.
class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
    required this.cornerRadius,
  });

  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;
  final double cornerRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(cornerRadius),
    );
    final Path path = Path()..addRRect(rrect);
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double end = (distance + dashLength).clamp(0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.dashLength != dashLength ||
      old.gapLength != gapLength ||
      old.cornerRadius != cornerRadius;
}
