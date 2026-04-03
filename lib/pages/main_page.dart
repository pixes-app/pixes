import "dart:async";

import "package:fluent_ui/fluent_ui.dart";
import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:pixes/appdata.dart";
import "package:pixes/components/md.dart";
import "package:pixes/foundation/app.dart";
import "package:pixes/foundation/image_provider.dart";
import "package:pixes/network/network.dart";
import "package:pixes/pages/bookmarks.dart";
import "package:pixes/pages/downloaded_page.dart";
import "package:pixes/pages/following_artworks.dart";
import "package:pixes/pages/following_novels_page.dart";
import "package:pixes/pages/history.dart";
import "package:pixes/pages/novel_bookmarks_page.dart";
import "package:pixes/pages/novel_ranking_page.dart";
import "package:pixes/pages/novel_recommendation_page.dart";
import "package:pixes/pages/ranking.dart";
import "package:pixes/pages/recommendation_page.dart";
import "package:pixes/pages/login_page.dart";
import "package:pixes/pages/search_page.dart";
import "package:pixes/pages/settings_page.dart";
import "package:pixes/pages/user_info_page.dart";
import "package:pixes/utils/loop.dart";
import "package:pixes/utils/mouse_listener.dart";
import "package:pixes/utils/translation.dart";
import "package:window_manager/window_manager.dart";

import "../components/page_route.dart";
import "../utils/debug.dart";
import "downloading_page.dart";

double get _appBarHeight => App.isDesktop ? 36.0 : 48.0;

class TitleBarAction {
  final IconData icon;
  final String title;
  final void Function() onPressed;

  TitleBarAction(this.icon, this.title, this.onPressed);
}

class TitleBarController extends StateController {
  TitleBarController();

  final List<TitleBarAction> actions = [
    if (kDebugMode) TitleBarAction(MdIcons.bug_report, "Debug", debug)
  ];

  void addAction(TitleBarAction action) {
    actions.add(action);
    update();
  }

  void removeAction(TitleBarAction action) {
    actions.remove(action);
    update();
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage>
    with WindowListener
    implements PopEntry {
  final navigatorKey = GlobalKey<NavigatorState>();

  int index = 4;

  int windowButtonKey = 0;

  ModalRoute<dynamic>? _route;

  @override
  void initState() {
    StateController.put<TitleBarController>(TitleBarController());
    windowManager.addListener(this);
    listenMouseSideButtonToBack(navigatorKey);
    App.mainNavigatorKey = navigatorKey;
    index = appdata.settings["initialPage"] ?? 4;
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ModalRoute<dynamic>? nextRoute = ModalRoute.of(context);
    if (nextRoute != _route) {
      _route?.unregisterPopEntry(this);
      _route = nextRoute;
      _route?.registerPopEntry(this);
    }
  }

  @override
  void dispose() {
    StateController.remove<TitleBarController>();
    windowManager.removeListener(this);
    ModalRoute.of(context)!.unregisterPopEntry(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    setState(() {
      windowButtonKey++;
    });
  }

  @override
  void onWindowUnmaximize() {
    setState(() {
      windowButtonKey++;
    });
  }

  bool get isLogin => Network().token != null;

  @override
  Widget build(BuildContext context) {
    if (!isLogin) {
      return NavigationView(
        appBar: buildAppBar(context, navigatorKey),
        content: LoginPage(() => setState(() {})),
      );
    }
    return DefaultSelectionStyle.merge(
      selectionColor: FluentTheme.of(context).selectionColor.toOpacity(0.4),
      child: NavigationView(
        appBar: buildAppBar(context, navigatorKey),
        pane: NavigationPane(
          selected: index,
          onChanged: (value) {
            setState(() {
              index = value;
            });
            navigate(value);
          },
          items: [
            UserPane(),
            PaneItem(
              icon: const Icon(
                MdIcons.search,
                size: 20,
              ),
              title: Text('Search'.tl),
              body: const SizedBox.shrink(),
            ),
            PaneItem(
              icon: const Icon(
                MdIcons.downloading,
                size: 20,
              ),
              title: Text('Downloading'.tl),
              body: const SizedBox.shrink(),
            ),
            PaneItem(
              icon: const Icon(
                MdIcons.download,
                size: 20,
              ),
              title: Text('Downloaded'.tl),
              body: const SizedBox.shrink(),
            ),
            PaneItemSeparator(),
            PaneItemHeader(
                header: Text('${"Illustrations".tl}/${"Manga".tl}')
                    .paddingBottom(4)
                    .paddingLeft(8)),
            PaneItem(
              icon: const Icon(
                MdIcons.explore_outlined,
                size: 20,
              ),
              title: Text('Explore'.tl),
              body: const SizedBox.shrink(),
            ),
            PaneItem(
              icon: const Icon(MdIcons.bookmark_outline, size: 20),
              title: Text('Bookmarks'.tl),
              body: const SizedBox.shrink(),
            ),
            PaneItem(
              icon: const Icon(MdIcons.interests_outlined, size: 20),
              title: Text('Following'.tl),
              body: const SizedBox.shrink(),
            ),
            PaneItem(
              icon: const Icon(MdIcons.history, size: 20),
              title: Text('History'.tl),
              body: const SizedBox.shrink(),
            ),
            PaneItem(
              icon: const Icon(MdIcons.leaderboard_outlined, size: 20),
              title: Text('Ranking'.tl),
              body: const SizedBox.shrink(),
            ),
            PaneItemSeparator(),
            PaneItemHeader(
                header: Text("Novel".tl).paddingBottom(4).paddingLeft(8)),
            PaneItem(
              icon: const Icon(MdIcons.featured_play_list_outlined, size: 20),
              title: Text('Recommendation'.tl),
              body: const SizedBox.shrink(),
            ),
            PaneItem(
              icon: const Icon(MdIcons.collections_bookmark_outlined, size: 20),
              title: Text('Bookmarks'.tl),
              body: const SizedBox.shrink(),
            ),
            PaneItem(
              icon: const Icon(MdIcons.interests_outlined, size: 20),
              title: Text('Following'.tl),
              body: const SizedBox.shrink(),
            ),
            PaneItem(
              icon: const Icon(MdIcons.leaderboard_outlined, size: 20),
              title: Text('Ranking'.tl),
              body: const SizedBox.shrink(),
            ),
            PaneItemSeparator(),
            PaneItemAction(
              icon: const Icon(MdIcons.settings_outlined, size: 20),
              title: Text('Settings'.tl),
              body: const SizedBox.shrink(),
              onTap: () {
                navigatorKey.currentContext?.to(() => const SettingsPage());
              },
            ),
          ],
        ),
        paneBodyBuilder: (pane, child) => MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: Navigator(
            key: navigatorKey,
            onGenerateRoute: (settings) => AppPageRoute(
              isRoot: true,
              builder: (context) => pageBuilders.elementAtOrNull(index)!(),
            ),
          ),
        ),
      ),
    );
  }

  static final pageBuilders = <Widget Function()>[
    () => UserInfoPage(appdata.account!.user.id),
    () => const SearchPage(),
    () => const DownloadingPage(),
    () => const DownloadedPage(),
    () => const RecommendationPage(),
    () => const BookMarkedArtworkPage(),
    () => const FollowingArtworksPage(),
    () => const HistoryPage(),
    () => const RankingPage(),
    () => const NovelRecommendationPage(),
    () => const NovelBookmarksPage(),
    () => const FollowingNovelsPage(),
    () => const NovelRankingPage(),
  ];

  void navigate(int index) {
    var page = pageBuilders.elementAtOrNull(index) ??
        () => Center(
              child: Text("Invalid Page: $index"),
            );
    navigatorKey.currentState!.pushAndRemoveUntil(
      AppPageRoute(
        builder: (context) => page(),
        isRoot: true,
      ),
      (route) => false,
    );
  }

  NavigationAppBar buildAppBar(
      BuildContext context, GlobalKey<NavigatorState> navigatorKey) {
    return NavigationAppBar(
      automaticallyImplyLeading: false,
      height: _appBarHeight,
      title: () {
        return StateBuilder<TitleBarController>(
          builder: (controller) {
            Widget content = Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Row(
                  children: [
                    if (App.isMacOS)
                      const SizedBox(width: 72),
                    if (App.isMacOS)
                      _MacosBackButton(navigatorKey).paddingRight(8),
                    if (!App.isDesktop)
                      const Text(
                        "Pixes",
                        style: TextStyle(fontSize: 13),
                      ),
                    if (!App.isDesktop) const Spacer(),
                    if (App.isDesktop)
                      const Expanded(
                        child: SizedBox(
                          height: double.infinity,
                          child: DragToMoveArea(
                              child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Pixes",
                              style: TextStyle(fontSize: 13),
                            ),
                          )),
                        ),
                      ),
                    for (var action in controller.actions)
                      Button(
                        onPressed: action.onPressed,
                        child: Row(
                          children: [
                            Icon(
                              action.icon,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(action.title),
                          ],
                        ),
                      ).paddingTop(4).paddingLeft(4),
                    if (App.isDesktop)
                      const SizedBox(width: 128)
                    else
                      Tooltip(
                          message: "Search".tl,
                          child: IconButton(
                            icon: const Icon(
                              MdIcons.search,
                              size: 18,
                            ),
                            onPressed: () {
                              if (index == 1) {
                                return;
                              }
                              setState(() {
                                index = 1;
                              });
                              navigate(1);
                            },
                          )),
                  ],
                ),
              ),
            );

            return content;
          },
        );
      }(),
      leading: App.isMacOS ? null : _BackButton(navigatorKey),
      actions: App.isDesktop && !App.isMacOS
          ? WindowButtons(
              key: ValueKey(windowButtonKey),
            )
          : null,
    );
  }

  final popValue = ValueNotifier(false);

  @override
  ValueListenable<bool> get canPopNotifier => popValue;

  @override
  void onPopInvokedWithResult(bool didPop, result) {
    if (App.rootNavigatorKey.currentState?.canPop() ?? false) {
      App.rootNavigatorKey.currentState?.pop();
    } else if (App.mainNavigatorKey?.currentState?.canPop() ?? false) {
      App.mainNavigatorKey?.currentState?.pop();
    } else {
      SystemNavigator.pop();
    }
  }

  @override
  void onPopInvoked(bool didPop) {}
}

class _BackButton extends StatefulWidget {
  const _BackButton(this.navigatorKey);

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  GlobalKey<NavigatorState> get navigatorKey => widget.navigatorKey;

  bool enabled = false;

  Timer? timer;

  @override
  void initState() {
    enabled = navigatorKey.currentState?.canPop() == true;
    Loop.register(loop);
    super.initState();
  }

  void loop() {
    bool enabled = navigatorKey.currentState?.canPop() == true;
    if (enabled != this.enabled) {
      setState(() {
        this.enabled = enabled;
      });
    }
  }

  @override
  void dispose() {
    Loop.remove(loop);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    void onPressed() {
      if (navigatorKey.currentState?.canPop() ?? false) {
        navigatorKey.currentState?.pop();
      }
    }

    return NavigationPaneTheme(
      data: NavigationPaneTheme.of(context).merge(NavigationPaneThemeData(
        unselectedIconColor: WidgetStateProperty.resolveWith((states) {
          if (states.isDisabled) {
            return ButtonThemeData.buttonColor(context, states);
          }
          return ButtonThemeData.uncheckedInputColor(
            FluentTheme.of(context),
            states,
          ).basedOnLuminance();
        }),
      )),
      child: Builder(
        builder: (context) => PaneItem(
          icon: const Center(child: Icon(FluentIcons.back, size: 12.0)),
          title: const Text("Back"),
          body: const SizedBox.shrink(),
          enabled: enabled,
        )
            .build(
              context,
              false,
              onPressed,
              displayMode: PaneDisplayMode.compact,
            )
            .paddingTop(2),
      ),
    );
  }
}

class _MacosBackButton extends StatefulWidget {
  const _MacosBackButton(this.navigatorKey);

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<_MacosBackButton> createState() => __MacosBackButtonState();
}

class __MacosBackButtonState extends State<_MacosBackButton> {
  GlobalKey<NavigatorState> get navigatorKey => widget.navigatorKey;

  bool enabled = false;
  bool _isHovered = false;

  @override
  void initState() {
    enabled = navigatorKey.currentState?.canPop() == true;
    Loop.register(loop);
    super.initState();
  }

  void loop() {
    bool enabled = navigatorKey.currentState?.canPop() == true;
    if (enabled != this.enabled) {
      setState(() {
        this.enabled = enabled;
      });
    }
  }

  @override
  void dispose() {
    Loop.remove(loop);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final iconColor = enabled
        ? theme.iconTheme.color ?? Colors.black
        : (theme.iconTheme.color ?? Colors.black).toOpacity(0.3);
    final bgColor = (_isHovered && enabled)
        ? theme.inactiveBackgroundColor
        : theme.micaBackgroundColor;

    return GestureDetector(
      onTap: enabled
          ? () {
              if (navigatorKey.currentState?.canPop() ?? false) {
                navigatorKey.currentState?.pop();
              }
            }
          : null,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.all(4),
          child: Icon(
            FluentIcons.back,
            size: 14,
            color: iconColor,
          ),
        ),
      ),
    );
  }
}

class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final color = theme.iconTheme.color ?? Colors.black;
    final hoverColor = theme.inactiveBackgroundColor;

    return SizedBox(
      width: 138,
      height: _appBarHeight,
      child: Row(
        children: [
          WindowButton(
            icon: MinimizeIcon(color: color),
            hoverColor: hoverColor,
            onPressed: () async {
              bool isMinimized = await windowManager.isMinimized();
              if (isMinimized) {
                windowManager.restore();
              } else {
                windowManager.minimize();
              }
            },
          ),
          FutureBuilder<bool>(
            future: windowManager.isMaximized(),
            builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
              if (snapshot.data == true) {
                return WindowButton(
                  icon: RestoreIcon(
                    color: color,
                  ),
                  hoverColor: hoverColor,
                  onPressed: () {
                    windowManager.unmaximize();
                  },
                );
              }
              return WindowButton(
                icon: MaximizeIcon(
                  color: color,
                ),
                hoverColor: hoverColor,
                onPressed: () {
                  windowManager.maximize();
                },
              );
            },
          ),
          WindowButton(
            icon: CloseIcon(
              color: color,
            ),
            hoverIcon: CloseIcon(
              color: theme.brightness == Brightness.light
                  ? Colors.white
                  : Colors.black,
            ),
            hoverColor: Colors.red,
            onPressed: () {
              windowManager.close();
            },
          ),
        ],
      ),
    );
  }
}

class WindowButton extends StatefulWidget {
  const WindowButton(
      {required this.icon,
      required this.onPressed,
      required this.hoverColor,
      this.hoverIcon,
      super.key});

  final Widget icon;

  final void Function() onPressed;

  final Color hoverColor;

  final Widget? hoverIcon;

  @override
  State<WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<WindowButton> {
  bool isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (event) => setState(() {
        isHovering = true;
      }),
      onExit: (event) => setState(() {
        isHovering = false;
      }),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          height: double.infinity,
          decoration:
              BoxDecoration(color: isHovering ? widget.hoverColor : null),
          child: isHovering ? widget.hoverIcon ?? widget.icon : widget.icon,
        ),
      ),
    );
  }
}

class UserPane extends PaneItem {
  UserPane() : super(icon: const SizedBox(), body: const SizedBox());

  @override
  Widget build(BuildContext context, bool selected, VoidCallback? onPressed,
      {PaneDisplayMode? displayMode,
      bool showTextOnTop = true,
      int? itemIndex,
      bool? autofocus}) {
    final maybeBody = NavigationView.maybeOf(context);
    var mode = displayMode ?? maybeBody?.displayMode ?? PaneDisplayMode.minimal;

    if (maybeBody?.compactOverlayOpen == true) {
      mode = PaneDisplayMode.open;
    }

    Widget body = () {
      switch (mode) {
        case PaneDisplayMode.minimal:
        case PaneDisplayMode.open:
          return LayoutBuilder(builder: (context, constrains) {
            if (constrains.maxHeight < 72 || constrains.maxWidth < 120) {
              return const SizedBox();
            }
            return Container(
              width: double.infinity,
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(48),
                      child: Image(
                        height: 48,
                        width: 48,
                        image:
                            CachedImageProvider(appdata.account!.user.profile),
                        fit: BoxFit.fill,
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  if (constrains.maxWidth > 90)
                    Expanded(
                      child: Center(
                        child: SizedBox(
                          width: double.infinity,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                appdata.account!.user.name,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                              Text(
                                kDebugMode
                                    ? "<hide due to debug>"
                                    : appdata.account!.user.email,
                                style: const TextStyle(fontSize: 12),
                              )
                            ],
                          ),
                        ),
                      ),
                    )
                ],
              ),
            );
          });
        case PaneDisplayMode.compact:
        case PaneDisplayMode.top:
          return LayoutBuilder(builder: (context, constrains) {
            if (constrains.maxHeight < 48 || constrains.maxWidth < 32) {
              return const SizedBox();
            }
            return Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Image(
                  height: 30,
                  width: 30,
                  image: NetworkImage(appdata.account!.user.profile),
                  fit: BoxFit.fill,
                ),
              ).paddingAll(4),
            );
          });
        default:
          throw "Invalid Display mode";
      }
    }();

    var button = HoverButton(
      builder: (context, states) {
        final theme = NavigationPaneTheme.of(context);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 6.0),
          decoration: BoxDecoration(
            color: () {
              final tileColor = this.tileColor ??
                  theme.tileColor ??
                  kDefaultPaneItemColor(context, mode == PaneDisplayMode.top);
              final newStates = states.toSet()..remove(WidgetState.disabled);
              if (selected && selectedTileColor != null) {
                return selectedTileColor!.resolve(newStates);
              }
              return tileColor.resolve(
                selected
                    ? {
                        states.isHovered
                            ? WidgetState.pressed
                            : WidgetState.hovered,
                      }
                    : newStates,
              );
            }(),
            borderRadius: BorderRadius.circular(4.0),
          ),
          child: FocusBorder(
            focused: states.isFocused,
            renderOutside: false,
            child: body,
          ),
        );
      },
      onPressed: onPressed,
    );

    return Padding(
      key: key,
      padding: const EdgeInsetsDirectional.only(bottom: 4.0),
      child: button,
    );
  }
}

/// Close
class CloseIcon extends StatelessWidget {
  final Color color;

  const CloseIcon({super.key, required this.color});

  @override
  Widget build(BuildContext context) => _AlignedPaint(_ClosePainter(color));
}

class _ClosePainter extends _IconPainter {
  _ClosePainter(super.color);

  @override
  void paint(Canvas canvas, Size size) {
    Paint p = getPaint(color, true);
    canvas.drawLine(const Offset(0, 0), Offset(size.width, size.height), p);
    canvas.drawLine(Offset(0, size.height), Offset(size.width, 0), p);
  }
}

/// Maximize
class MaximizeIcon extends StatelessWidget {
  final Color color;

  const MaximizeIcon({super.key, required this.color});

  @override
  Widget build(BuildContext context) => _AlignedPaint(_MaximizePainter(color));
}

class _MaximizePainter extends _IconPainter {
  _MaximizePainter(super.color);

  @override
  void paint(Canvas canvas, Size size) {
    Paint p = getPaint(color);
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width - 1, size.height - 1), p);
  }
}

/// Restore
class RestoreIcon extends StatelessWidget {
  final Color color;

  const RestoreIcon({
    super.key,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => _AlignedPaint(_RestorePainter(color));
}

class _RestorePainter extends _IconPainter {
  _RestorePainter(super.color);

  @override
  void paint(Canvas canvas, Size size) {
    Paint p = getPaint(color);
    canvas.drawRect(Rect.fromLTRB(0, 2, size.width - 2, size.height), p);
    canvas.drawLine(const Offset(2, 2), const Offset(2, 0), p);
    canvas.drawLine(const Offset(2, 0), Offset(size.width, 0), p);
    canvas.drawLine(
        Offset(size.width, 0), Offset(size.width, size.height - 2), p);
    canvas.drawLine(Offset(size.width, size.height - 2),
        Offset(size.width - 2, size.height - 2), p);
  }
}

/// Minimize
class MinimizeIcon extends StatelessWidget {
  final Color color;

  const MinimizeIcon({super.key, required this.color});

  @override
  Widget build(BuildContext context) => _AlignedPaint(_MinimizePainter(color));
}

class _MinimizePainter extends _IconPainter {
  _MinimizePainter(super.color);

  @override
  void paint(Canvas canvas, Size size) {
    Paint p = getPaint(color);
    canvas.drawLine(
        Offset(0, size.height / 2), Offset(size.width, size.height / 2), p);
  }
}

/// Helpers
abstract class _IconPainter extends CustomPainter {
  _IconPainter(this.color);

  final Color color;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AlignedPaint extends StatelessWidget {
  const _AlignedPaint(this.painter);

  final CustomPainter painter;

  @override
  Widget build(BuildContext context) {
    return Align(
        alignment: Alignment.center,
        child: CustomPaint(size: const Size(10, 10), painter: painter));
  }
}

Paint getPaint(Color color, [bool isAntiAlias = false]) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..isAntiAlias = isAntiAlias
  ..strokeWidth = 1;
