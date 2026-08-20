import 'package:fluent_ui/fluent_ui.dart' hide TitleBar;
import 'package:flutter/scheduler.dart';
import 'package:pixes/appdata.dart';
import 'package:pixes/components/animated_image.dart';
import 'package:pixes/components/loading.dart';
import 'package:pixes/components/md.dart';
import 'package:pixes/components/page_route.dart';
import 'package:pixes/components/title_bar.dart';
import 'package:pixes/foundation/app.dart';
import 'package:pixes/foundation/image_provider.dart';
import 'package:pixes/foundation/log.dart';
import 'package:pixes/network/network.dart';
import 'package:pixes/network/translator.dart';
import 'package:pixes/pages/image_page.dart';
import 'package:pixes/pages/main_page.dart';
import 'package:pixes/utils/ext.dart';
import 'package:pixes/utils/translation.dart';

const double _minAutoScrollSpeed = 10.0;
const double _maxAutoScrollSpeed = 100.0;
const double _defaultAutoScrollSpeed = 40.0;

double _getAutoScrollSpeed() {
  final value = appdata.settings["readingAutoScrollSpeed"];
  if (value is! num) return _defaultAutoScrollSpeed;
  return value
      .toDouble()
      .clamp(_minAutoScrollSpeed, _maxAutoScrollSpeed)
      .toDouble();
}

class NovelReadingPage extends StatefulWidget {
  const NovelReadingPage(this.novel, {super.key});

  final Novel novel;

  @override
  State<NovelReadingPage> createState() => _NovelReadingPageState();
}

class _NovelReadingPageState extends LoadingState<NovelReadingPage, String>
    with SingleTickerProviderStateMixin {
  TitleBarAction? settingsAction;

  TitleBarAction? autoScrollAction;

  late final ScrollController _scrollController;

  late final Ticker _autoScrollTicker;

  Duration? _lastAutoScrollTick;

  bool _isAutoScrolling = false;

  bool isShowingSettings = false;

  String? translatedContent;

  /// The novel currently shown. Changes when navigating between the
  /// chapters (episodes) of a series.
  late Novel novel;

  /// All episodes of the series this novel belongs to, in reading order.
  /// Null until loaded, or if the novel does not belong to a series.
  List<Novel>? seriesNovels;

  bool isLoadingSeries = false;

  @override
  void initState() {
    novel = widget.novel;
    super.initState();
    _scrollController = ScrollController();
    _autoScrollTicker = createTicker(_handleAutoScrollTick);
    autoScrollAction = _createAutoScrollAction();
    settingsAction = TitleBarAction(MdIcons.tune, "Settings".tl, () {
      if (!mounted || isLoading || data == null) return;
      _stopAutoScroll();
      if (!isShowingSettings) {
        _NovelReadingSettings.show(
          context,
          () {
            setState(() {});
          },
          TranslationController(
            content: data!,
            isTranslated: translatedContent != null,
            onTranslated: (s) {
              setState(() {
                translatedContent = s;
              });
            },
            revert: () {
              setState(() {
                translatedContent = null;
              });
            },
          ),
        ).then(
          (value) {
            isShowingSettings = false;
          },
        );
        isShowingSettings = true;
      } else {
        Navigator.of(context).pop();
      }
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      final controller = StateController.findOrNull<TitleBarController>();
      if (controller == null) return;
      controller.addAction(autoScrollAction!);
      controller.addAction(settingsAction!);
    });
    if (novel.seriesId != null) {
      loadSeries();
    }
  }

  @override
  void dispose() {
    _stopAutoScroll(updateAction: false);
    _autoScrollTicker.dispose();
    _scrollController.dispose();
    final currentAutoScrollAction = autoScrollAction;
    final currentSettingsAction = settingsAction;
    Future.delayed(const Duration(milliseconds: 200), () {
      final controller = StateController.findOrNull<TitleBarController>();
      if (controller == null) return;
      if (currentAutoScrollAction != null) {
        controller.removeAction(currentAutoScrollAction);
      }
      if (currentSettingsAction != null) {
        controller.removeAction(currentSettingsAction);
      }
    });
    super.dispose();
  }

  TitleBarAction _createAutoScrollAction() {
    return TitleBarAction(
      _isAutoScrolling ? MdIcons.pause : MdIcons.play_arrow,
      _isAutoScrolling ? "Pause".tl : "Auto Scroll".tl,
      _toggleAutoScroll,
      compactOnMobile: true,
    );
  }

  void _refreshAutoScrollAction() {
    final current = autoScrollAction;
    final replacement = _createAutoScrollAction();
    autoScrollAction = replacement;
    if (current == null) return;
    StateController.findOrNull<TitleBarController>()
        ?.replaceAction(current, replacement);
  }

  void _toggleAutoScroll() {
    if (!mounted) return;
    if (_isAutoScrolling) {
      _stopAutoScroll();
      return;
    }
    if (ModalRoute.of(context)?.isCurrent != true) return;
    _startAutoScroll();
  }

  void _startAutoScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (!position.hasContentDimensions ||
        position.pixels >= position.maxScrollExtent - 0.5) {
      return;
    }
    _isAutoScrolling = true;
    _lastAutoScrollTick = null;
    _autoScrollTicker.start();
    _refreshAutoScrollAction();
  }

  void _stopAutoScroll({bool updateAction = true}) {
    if (!_isAutoScrolling) return;
    _isAutoScrolling = false;
    _lastAutoScrollTick = null;
    _autoScrollTicker.stop();
    if (updateAction) {
      _refreshAutoScrollAction();
    }
  }

  void _handleAutoScrollTick(Duration elapsed) {
    if (!_isAutoScrolling) return;
    if (!_scrollController.hasClients) {
      _stopAutoScroll();
      return;
    }

    final position = _scrollController.position;
    if (!position.hasContentDimensions) {
      _lastAutoScrollTick = elapsed;
      return;
    }
    if (position.pixels >= position.maxScrollExtent - 0.5) {
      _stopAutoScroll();
      return;
    }

    final previousTick = _lastAutoScrollTick;
    _lastAutoScrollTick = elapsed;
    if (previousTick == null) return;

    final elapsedSeconds = ((elapsed - previousTick).inMicroseconds / 1000000)
        .clamp(0.0, 0.1)
        .toDouble();
    final nextOffset =
        (position.pixels + _getAutoScrollSpeed() * elapsedSeconds)
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();
    position.jumpTo(nextOffset);
    if (nextOffset >= position.maxScrollExtent - 0.5) {
      _stopAutoScroll();
    }
  }

  /// Loads the full ordered list of episodes for the current series.
  void loadSeries() async {
    final seriesId = novel.seriesId;
    if (seriesId == null || isLoadingSeries) return;
    setState(() {
      isLoadingSeries = true;
    });
    final all = <Novel>[];
    String? nextUrl;
    // Series are paginated; load every page. The cap guards against an
    // unexpected pagination loop.
    for (var i = 0; i < 50; i++) {
      var res = await Network().getNovelSeries(seriesId.toString(), nextUrl);
      if (res.error) break;
      all.addAll(res.data);
      nextUrl = res.subData;
      if (nextUrl == null || nextUrl.isEmpty) break;
    }
    if (!mounted) return;
    setState(() {
      isLoadingSeries = false;
      if (all.isNotEmpty) {
        seriesNovels = all;
      }
    });
  }

  /// Switches the reader to [target] and reloads its content.
  void goToNovel(Novel target) {
    if (target.id == novel.id || isLoading) return;
    _stopAutoScroll();
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.minScrollExtent);
    }
    setState(() {
      novel = target;
      translatedContent = null;
      isLoading = true;
      error = null;
      data = null;
    });
    loadData().then((value) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        if (value.success) {
          data = value.data;
        } else {
          error = value.errorMessage!;
        }
      });
    });
  }

  void showChapterList() {
    final list = seriesNovels;
    if (list == null) return;
    _stopAutoScroll();
    Navigator.of(context).push(
      SideBarRoute(_NovelChapterList(
        novels: list,
        currentId: novel.id,
        onSelected: goToNovel,
      )),
    );
  }

  @override
  Widget buildContent(BuildContext context, String data) {
    var content = buildList(context).toList();
    content.add(buildChapterNav(context));
    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: Listener(
        onPointerDown: (_) => _stopAutoScroll(),
        onPointerSignal: (_) => _stopAutoScroll(),
        child: SelectionArea(
          child: DefaultTextStyle.merge(
            style: const TextStyle(fontSize: 16.0, height: 1.6),
            child: ListView.builder(
              key: ValueKey(novel.id),
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
              itemBuilder: (context, index) {
                return content[index];
              },
              itemCount: content.length,
            ),
          ),
        ),
      ),
    );
  }

  /// The previous / chapter-list / next bar shown at the end of a chapter.
  Widget buildChapterNav(BuildContext context) {
    if (novel.seriesId == null) {
      return const SizedBox.shrink();
    }
    if (seriesNovels == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: isLoadingSeries
              ? const SizedBox.square(
                  dimension: 24,
                  child: ProgressRing(strokeWidth: 2),
                )
              : Button(
                  onPressed: loadSeries,
                  child: Text("Load chapters".tl),
                ),
        ),
      );
    }
    final list = seriesNovels!;
    final index = list.indexWhere((n) => n.id == novel.id);
    final hasPrev = index > 0;
    final hasNext = index >= 0 && index < list.length - 1;
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Column(
        children: [
          const Divider(
            style: DividerThemeData(horizontalMargin: EdgeInsets.all(0)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Button(
                  onPressed: hasPrev ? () => goToNovel(list[index - 1]) : null,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(MdIcons.chevron_left, size: 18),
                      const SizedBox(width: 4),
                      Text("Previous".tl,
                          style: const TextStyle(
                              height: 1.0,
                              leadingDistribution:
                                  TextLeadingDistribution.even)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: showChapterList,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(MdIcons.format_list_bulleted, size: 18),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          index >= 0
                              ? "${index + 1} / ${list.length}"
                              : "Chapters".tl,
                          style: const TextStyle(
                              height: 1.0,
                              leadingDistribution:
                                  TextLeadingDistribution.even),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Button(
                  onPressed: hasNext ? () => goToNovel(list[index + 1]) : null,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Next".tl,
                          style: const TextStyle(
                              height: 1.0,
                              leadingDistribution:
                                  TextLeadingDistribution.even)),
                      const SizedBox(width: 4),
                      const Icon(MdIcons.chevron_right, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Future<Res<String>> loadData() {
    return Network().getNovelContent(novel.id.toString());
  }

  Iterable<Widget> buildList(BuildContext context) sync* {
    double fontSizeAdd = appdata.settings["readingFontSize"] - 16.0;
    double fontHeight = appdata.settings["readingLineHeight"];

    yield Text(novel.title,
        style: TextStyle(
            fontSize: 24.0 + fontSizeAdd, fontWeight: FontWeight.bold));
    yield const SizedBox(height: 12.0);
    yield const Divider(
      style: DividerThemeData(horizontalMargin: EdgeInsets.all(0)),
    );
    yield const SizedBox(height: 12.0);

    var novelContent = (translatedContent ?? data!).split('\n');
    for (var content in novelContent) {
      if (content.isEmpty) continue;
      if (content.startsWith('[uploadedimage:')) {
        var imageId = content.nums;
        yield GestureDetector(
          onTap: () {
            ImagePage.show(["novel:${novel.id.toString()}/$imageId"]);
          },
          child: SizedBox(
            height: 300,
            width: double.infinity,
            child: AnimatedImage(
              image: CachedNovelImageProvider(novel.id.toString(), imageId),
              filterQuality: FilterQuality.medium,
              fit: BoxFit.contain,
              height: 300,
              width: double.infinity,
            ),
          ),
        );
      } else if (content.startsWith('[chapter:')) {
        var title = content.replaceLast(']', '').split(':')[1];
        yield Text(title,
                style: TextStyle(
                    fontSize: 20.0 + fontSizeAdd,
                    fontWeight: FontWeight.bold,
                    height: fontHeight))
            .paddingBottom(8);
      } else {
        yield Text(content,
                style:
                    TextStyle(fontSize: 16.0 + fontSizeAdd, height: fontHeight))
            .paddingBottom(appdata.settings["readingParagraphSpacing"]);
      }
    }
  }
}

/// A side panel listing every chapter (episode) of a series, used to jump
/// directly to a specific chapter from the reader.
class _NovelChapterList extends StatelessWidget {
  const _NovelChapterList({
    required this.novels,
    required this.currentId,
    required this.onSelected,
  });

  final List<Novel> novels;

  final int currentId;

  final void Function(Novel novel) onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TitleBar(title: "Chapters".tl),
        Expanded(
          child: ListView.builder(
            itemCount: novels.length,
            itemBuilder: (context, index) {
              final n = novels[index];
              final isCurrent = n.id == currentId;
              return ListTile(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                tileColor: isCurrent
                    ? WidgetStateColor.resolveWith((states) =>
                        ColorScheme.of(context).primaryContainer.toOpacity(0.6))
                    : null,
                onPressed: () {
                  Navigator.of(context).pop();
                  if (!isCurrent) {
                    onSelected(n);
                  }
                },
                leading: Text(
                  "${index + 1}",
                  style: TextStyle(
                    color: ColorScheme.of(context).primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: isCurrent
                    ? Icon(
                        MdIcons.check,
                        size: 18,
                        color: ColorScheme.of(context).primary,
                      )
                    : const SizedBox(
                        width: 18,
                        height: 18,
                      ),
                title: Text(
                  n.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class TranslationController {
  final String content;

  final bool isTranslated;

  final void Function(String translated) onTranslated;

  final void Function() revert;

  const TranslationController({
    required this.content,
    required this.isTranslated,
    required this.onTranslated,
    required this.revert,
  });
}

class _NovelReadingSettings extends StatefulWidget {
  const _NovelReadingSettings(this.callback, this.controller);

  final void Function() callback;

  final TranslationController controller;

  static Future show(
    BuildContext context,
    void Function() callback,
    TranslationController controller,
  ) {
    return Navigator.of(context).push(
      SideBarRoute(_NovelReadingSettings(callback, controller)),
    );
  }

  @override
  State<_NovelReadingSettings> createState() => __NovelReadingSettingsState();
}

class __NovelReadingSettingsState extends State<_NovelReadingSettings> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          TitleBar(title: "Reading Settings".tl),
          const SizedBox(height: 8),
          Card(
            padding: EdgeInsets.zero,
            child: ListTile(
              title: Text("Font Size".tl),
              subtitle: Slider(
                value: appdata.settings["readingFontSize"],
                onChanged: (value) {
                  setState(() {
                    appdata.settings["readingFontSize"] = value;
                  });
                  appdata.writeSettings();
                  widget.callback();
                },
                min: 12.0,
                max: 24.0,
                divisions: 12,
                label: appdata.settings["readingFontSize"].toString(),
              ),
              trailing: Text(appdata.settings["readingFontSize"].toString()),
            ),
          ).paddingHorizontal(8).paddingBottom(8),
          Card(
            padding: EdgeInsets.zero,
            child: ListTile(
              title: Text("Line Height".tl),
              subtitle: Slider(
                value: appdata.settings["readingLineHeight"],
                onChanged: (value) {
                  setState(() {
                    appdata.settings["readingLineHeight"] = value;
                  });
                  appdata.writeSettings();
                  widget.callback();
                },
                min: 1.0,
                max: 2.0,
                divisions: 10,
                label: appdata.settings["readingLineHeight"].toString(),
              ),
              trailing: Text(appdata.settings["readingLineHeight"].toString()),
            ),
          ).paddingHorizontal(8).paddingBottom(8),
          Card(
            padding: EdgeInsets.zero,
            child: ListTile(
              title: Text("Paragraph Spacing".tl),
              subtitle: Slider(
                value: appdata.settings["readingParagraphSpacing"],
                onChanged: (value) {
                  setState(() {
                    appdata.settings["readingParagraphSpacing"] = value;
                  });
                  appdata.writeSettings();
                  widget.callback();
                },
                min: 0.0,
                max: 16.0,
                divisions: 8,
                label: appdata.settings["readingParagraphSpacing"].toString(),
              ),
              trailing:
                  Text(appdata.settings["readingParagraphSpacing"].toString()),
            ),
          ).paddingHorizontal(8).paddingBottom(8),
          Card(
            padding: EdgeInsets.zero,
            child: ListTile(
              title: Text("Auto Scroll Speed".tl),
              subtitle: Slider(
                key: const ValueKey("novel-auto-scroll-speed"),
                value: _getAutoScrollSpeed(),
                onChanged: (value) {
                  setState(() {
                    appdata.settings["readingAutoScrollSpeed"] = value;
                  });
                },
                onChangeEnd: (_) => appdata.writeSettings(),
                min: _minAutoScrollSpeed,
                max: _maxAutoScrollSpeed,
                divisions: 9,
                label: "${(_getAutoScrollSpeed() / 10).round()}",
              ),
              trailing: Text("${(_getAutoScrollSpeed() / 10).round()} / 10"),
            ),
          ).paddingHorizontal(8).paddingBottom(8),
          // 深色模式
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: EdgeInsets.zero,
            child: ListTile(
              title: Text("Theme".tl),
              trailing: DropDownButton(
                  title: Text(appdata.settings["theme"] ?? "System".tl),
                  items: [
                    MenuFlyoutItem(
                        text: Text("System".tl),
                        onPressed: () {
                          setState(() {
                            appdata.settings["theme"] = "System";
                          });
                          appdata.writeData();
                          StateController.findOrNull(tag: "MyApp")?.update();
                        }),
                    MenuFlyoutItem(
                        text: Text("light".tl),
                        onPressed: () {
                          setState(() {
                            appdata.settings["theme"] = "Light";
                          });
                          appdata.writeData();
                          StateController.findOrNull(tag: "MyApp")?.update();
                        }),
                    MenuFlyoutItem(
                        text: Text("dark".tl),
                        onPressed: () {
                          setState(() {
                            appdata.settings["theme"] = "Dark";
                          });
                          appdata.writeData();
                          StateController.findOrNull(tag: "MyApp")?.update();
                        }),
                  ]),
            ),
          ).paddingBottom(8),
          Card(
            padding: EdgeInsets.zero,
            child: ListTile(
              title: Text("Translate Novel".tl),
              trailing: widget.controller.isTranslated
                  ? Button(
                      onPressed: () {
                        widget.controller.revert();
                        context.pop();
                      },
                      child: Text("Revert".tl),
                    )
                  : Button(
                      onPressed: translate,
                      child: isTranslating
                          ? const SizedBox(
                              width: 42,
                              height: 18,
                              child: Center(
                                child: SizedBox.square(
                                  dimension: 18,
                                  child: ProgressRing(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            )
                          : Text("Translate".tl),
                    ),
            ),
          ).paddingHorizontal(8).paddingBottom(8),
        ],
      ),
    );
  }

  bool isTranslating = false;

  void translate() async {
    setState(() {
      isTranslating = true;
    });
    try {
      var translated = await Translator.instance
          .translate(widget.controller.content, "zh-CN");
      widget.controller.onTranslated(translated);
      if (mounted) {
        context.pop();
      }
    } catch (e) {
      setState(() {
        isTranslating = false;
      });
      if (mounted) {
        context.showToast(message: "Failed to translate".tl);
      }
      Log.error("Translate", e.toString());
    }
  }
}
