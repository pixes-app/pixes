import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:pixes/appdata.dart';
import 'package:pixes/components/animated_image.dart';
import 'package:pixes/components/keyboard.dart';
import 'package:pixes/components/loading.dart';
import 'package:pixes/components/message.dart';
import 'package:pixes/components/page_route.dart';
import 'package:pixes/components/title_bar.dart';
import 'package:pixes/components/user_preview.dart';
import 'package:pixes/foundation/app.dart';
import 'package:pixes/foundation/history.dart';
import 'package:pixes/foundation/image_provider.dart';
import 'package:pixes/network/download.dart';
import 'package:pixes/network/network.dart';
import 'package:pixes/pages/comments_page.dart';
import 'package:pixes/pages/image_page.dart';
import 'package:pixes/pages/related_page.dart';
import 'package:pixes/pages/search_page.dart';
import 'package:pixes/pages/user_info_page.dart';
import 'package:pixes/utils/block.dart';
import 'package:pixes/utils/translation.dart';
import 'package:share_plus/share_plus.dart';

import '../components/illust_widget.dart';
import '../components/md.dart';
import '../components/ugoira.dart';

const _kBottomBarHeight = 64.0;

class IllustGalleryPage extends StatefulWidget {
  const IllustGalleryPage(
      {required this.illusts,
      required this.initialPage,
      this.nextUrl,
      super.key});

  final List<Illust> illusts;

  final int initialPage;

  final String? nextUrl;

  static var cachedHistoryIds = <int>{};

  @override
  State<IllustGalleryPage> createState() => _IllustGalleryPageState();
}

class _IllustGalleryPageState extends State<IllustGalleryPage> {
  late List<Illust> illusts;

  late final PageController controller;

  String? nextUrl;

  bool loading = false;

  late int page = widget.initialPage;

  @override
  void initState() {
    illusts = List.from(widget.illusts);
    controller = PageController(initialPage: widget.initialPage);
    nextUrl = widget.nextUrl;
    if (nextUrl == "end") {
      nextUrl = null;
    }
    super.initState();
  }

  @override
  void dispose() {
    if (IllustGalleryPage.cachedHistoryIds.length > 5) {
      Network().sendHistory(
          IllustGalleryPage.cachedHistoryIds.toList().reversed.toList());
      IllustGalleryPage.cachedHistoryIds.clear();
    }
    super.dispose();
  }

  void nextPage() {
    var length = illusts.length;
    if (controller.page == length - 1) return;
    controller.nextPage(
        duration: const Duration(milliseconds: 200), curve: Curves.ease);
  }

  void previousPage() {
    if (controller.page == 0) return;
    controller.previousPage(
        duration: const Duration(milliseconds: 200), curve: Curves.ease);
  }

  @override
  Widget build(BuildContext context) {
    var length = illusts.length;
    if (nextUrl != null) {
      length++;
    }

    return Stack(
      children: [
        Positioned.fill(
          child: PageView.builder(
            controller: controller,
            itemCount: length,
            itemBuilder: (context, index) {
              if (index == illusts.length) {
                return buildLast();
              }
              return IllustPage(illusts[index],
                  nextPage: nextPage, previousPage: previousPage);
            },
            onPageChanged: (value) => setState(() {
              page = value;
            }),
          ),
        ),
        if (page < length - 1 && length > 1 && App.isDesktop)
          Positioned(
            right: 0,
            top: 0,
            bottom: 32,
            child: Center(
                child: IconButton(
              icon: const Icon(FluentIcons.chevron_right),
              onPressed: () {
                nextPage();
              },
            )),
          ),
        if (page != 0 && length > 1 && App.isDesktop)
          Positioned(
            left: 0,
            top: 0,
            bottom: 32,
            child: Center(
                child: IconButton(
              icon: const Icon(FluentIcons.chevron_left),
              onPressed: () {
                previousPage();
              },
            )),
          ),
      ],
    );
  }

  Widget buildLast() {
    if (nextUrl == null) {
      return const SizedBox();
    }
    load();
    return const Center(
      child: ProgressRing(),
    );
  }

  void load() async {
    if (loading) return;
    loading = true;

    var res = await Network().getIllustsWithNextUrl(nextUrl!);
    loading = false;
    if (res.error) {
      if (mounted) {
        context.showToast(message: "Network Error");
      }
    } else {
      nextUrl = res.subData;
      illusts.addAll(res.data);
      setState(() {});
    }
  }
}

class IllustPage extends StatefulWidget {
  const IllustPage(this.illust, {this.nextPage, this.previousPage, super.key});

  final Illust illust;

  final void Function()? nextPage;

  final void Function()? previousPage;

  static Map<String, UpdateFollowCallback> followCallbacks = {};

  static void updateFollow(String uid, bool isFollowed) {
    followCallbacks.forEach((key, value) {
      if (key.startsWith("$uid#")) {
        value(isFollowed);
      }
    });
  }

  @override
  State<IllustPage> createState() => _IllustPageState();
}

class _IllustPageState extends State<IllustPage> {
  String get id => "${widget.illust.author.id}#${widget.illust.id}";

  final _bottomBarController = _BottomBarController();

  KeyEventListenerState? keyboardListener;

  @override
  void initState() {
    keyboardListener = KeyEventListener.of(context);
    keyboardListener?.removeAll();
    keyboardListener?.addHandler(handleKey);
    IllustPage.followCallbacks[id] = (v) {
      setState(() {
        widget.illust.author.isFollowed = v;
      });
    };
    HistoryManager().addHistory(widget.illust);
    if (appdata.account!.user.isPremium) {
      IllustGalleryPage.cachedHistoryIds.add(widget.illust.id);
    }
    super.initState();
  }

  @override
  void dispose() {
    keyboardListener?.removeHandler(handleKey);
    IllustPage.followCallbacks.remove(id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var isBlocked = checkIllusts([widget.illust]).isEmpty;
    return ColoredBox(
      color: FluentTheme.of(context).micaBackgroundColor,
      child: SizedBox.expand(
        child: ColoredBox(
          color: FluentTheme.of(context).scaffoldBackgroundColor,
          child: LayoutBuilder(builder: (context, constrains) {
            return Stack(
              children: [
                if (!isBlocked)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    top: 0,
                    child: buildBody(constrains.maxWidth, constrains.maxHeight),
                  ),
                if (!isBlocked)
                  _BottomBar(
                    widget.illust,
                    constrains.maxHeight,
                    constrains.maxWidth,
                    updateCallback: () => setState(() {}),
                    controller: _bottomBarController,
                  ),
                if (isBlocked)
                  const Positioned.fill(
                      child: Center(
                    child: Center(
                        child: Text(
                      "This artwork is blocked",
                    )),
                  ))
              ],
            );
          }),
        ),
      ),
    );
  }

  final scrollController = ScrollController();

  void handleKey(LogicalKeyboardKey key) {
    const kShortcutScrollOffset = 200;

    var shortcuts = appdata.settings["shortcuts"] as List;

    switch (shortcuts.indexOf(key.keyId)) {
      case 0:
        if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent) {
          _bottomBarController.openOrClose();
        } else {
          scrollController.animateTo(
            scrollController.offset + kShortcutScrollOffset,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
        break;
      case 1:
        if (_bottomBarController.isOpen()) {
          _bottomBarController.openOrClose();
          break;
        }
        scrollController.animateTo(
          scrollController.offset - kShortcutScrollOffset,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
        break;
      case 2:
        widget.nextPage?.call();
        break;
      case 3:
        widget.previousPage?.call();
        break;
      case 4:
        _bottomBarController.favorite();
      case 5:
        _bottomBarController.download();
      case 6:
        _bottomBarController.follow();
      case 7:
        if (ModalRoute.of(context)?.isCurrent ?? true) {
          CommentsPage.show(context, widget.illust.id.toString());
        } else {
          context.pop();
        }
      case 8:
        openImage(0);
    }
  }

  Widget buildBody(double width, double height) {
    return ListView.builder(
        controller: scrollController,
        itemCount: widget.illust.images.length + 2,
        padding: EdgeInsets.zero,
        itemBuilder: (context, index) {
          return buildImage(width, height, index);
        });
  }

  void openImage(int index) {
    var images = <String>[];
    for (var i = 0; i < widget.illust.images.length; i++) {
      var downloadFile = DownloadManager().getImage(widget.illust.id, i);
      if (downloadFile != null) {
        images.add("file://${downloadFile.path}");
      } else {
        images.add(widget.illust.images[i].original);
      }
    }
    ImagePage.show(images, initialPage: index);
  }

  Widget buildImage(double width, double height, int index) {
    if (index == 0) {
      return Text(
        widget.illust.title,
        style: const TextStyle(fontSize: 24),
      ).paddingVertical(8).paddingHorizontal(12);
    }
    index--;
    File? downloadFile;
    if (widget.illust.downloaded) {
      downloadFile = DownloadManager().getImage(widget.illust.id, index);
    }
    if (index == widget.illust.images.length) {
      return SizedBox(
        height: _kBottomBarHeight + context.padding.bottom,
      );
    }
    var imageWidth = width;
    var imageHeight = widget.illust.height * width / widget.illust.width;
    if (imageHeight > height) {
      // 确保图片能够完整显示在屏幕上
      var scale = imageHeight / height;
      imageWidth = imageWidth / scale;
      imageHeight = height;
    }
    Widget image;

    var imageUrl = appdata.settings["showOriginalImage"]
        ? widget.illust.images[index].original
        : widget.illust.images[index].large;

    if (!widget.illust.isUgoira) {
      image = SizedBox(
        width: imageWidth,
        height: imageHeight,
        child: GestureDetector(
          onTap: () => openImage(index),
          child: Image(
              key: ValueKey(index),
              image: downloadFile == null
                  ? CachedImageProvider(imageUrl) as ImageProvider
                  : FileImage(downloadFile) as ImageProvider,
              width: imageWidth,
              fit: BoxFit.cover,
              height: imageHeight,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                double? value;
                if (loadingProgress.expectedTotalBytes != null) {
                  value = (loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!) *
                      100;
                }
                if (value != null && (value > 100 || value < 0)) {
                  value = null;
                }
                return Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: ProgressRing(
                      value: value,
                    ),
                  ),
                );
              }),
        ),
      );
    } else {
      image = UgoiraWidget(
        id: widget.illust.id.toString(),
        previewImage: CachedImageProvider(widget.illust.images[index].large),
        width: imageWidth,
        height: imageHeight,
      );
    }

    return Center(
      child: image,
    );
  }
}

class _BottomBarController {
  VoidCallback? _openOrClose;

  VoidCallback get openOrClose => _openOrClose!;

  bool Function()? _isOpen;

  bool isOpen() => _isOpen!();

  VoidCallback? _favorite;

  VoidCallback get favorite => _favorite!;

  VoidCallback? _download;

  VoidCallback get download => _download!;

  VoidCallback? _follow;

  VoidCallback get follow => _follow!;
}

class _BottomBar extends StatefulWidget {
  const _BottomBar(this.illust, this.height, this.width,
      {this.updateCallback, this.controller});

  final void Function()? updateCallback;

  final Illust illust;

  final double height;

  final double width;

  final _BottomBarController? controller;

  @override
  State<_BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<_BottomBar> with TickerProviderStateMixin {
  double pageHeight = 0;

  double widgetHeight = 48;

  final key = GlobalKey();

  double _width = 0;

  late VerticalDragGestureRecognizer _recognizer;

  late final AnimationController animationController;

  double get minValue => pageHeight - widgetHeight;
  double get maxValue =>
      pageHeight - _kBottomBarHeight - context.padding.bottom;

  @override
  void initState() {
    _width = widget.width;
    pageHeight = widget.height;
    Future.delayed(const Duration(milliseconds: 200), () {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      widgetHeight = (box?.size.height) ?? 0;
    });
    _recognizer = VerticalDragGestureRecognizer()
      ..onStart = _handlePointerDown
      ..onUpdate = _handlePointerMove
      ..onEnd = _handlePointerUp
      ..onCancel = _handlePointerCancel;
    animationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 180), value: 1);
    if (widget.controller != null) {
      widget.controller!._openOrClose = () {
        if (animationController.value == 0) {
          animationController.animateTo(1);
        } else if (animationController.value == 1) {
          animationController.animateTo(0);
        }
      };
      widget.controller!._isOpen = () => animationController.value == 0;
      widget.controller!._favorite = favorite;
      widget.controller!._download = () {
        DownloadManager().addDownloadingTask(widget.illust);
        setState(() {});
      };
      widget.controller!._follow = follow;
    }
    super.initState();
  }

  @override
  void dispose() {
    animationController.dispose();
    _recognizer.dispose();
    super.dispose();
  }

  void _handlePointerDown(DragStartDetails details) {}
  void _handlePointerMove(DragUpdateDetails details) {
    var offset = details.primaryDelta ?? 0;
    final minValue = pageHeight - widgetHeight;
    final maxValue = pageHeight - _kBottomBarHeight - context.padding.bottom;
    var top = animationController.value * (maxValue - minValue) + minValue;
    top = (top + offset).clamp(minValue, maxValue);
    animationController.value = (top - minValue) / (maxValue - minValue);
  }

  void _handlePointerUp(DragEndDetails details) {
    var speed = details.primaryVelocity ?? 0;
    const minShouldTransitionSpeed = 1000;
    if (speed > minShouldTransitionSpeed) {
      animationController.forward();
    } else if (speed < 0 - minShouldTransitionSpeed) {
      animationController.reverse();
    } else {
      _handlePointerCancel();
    }
  }

  void _handlePointerCancel() {
    if (animationController.value == 1 || animationController.value == 0) {
      return;
    }
    if (animationController.value >= 0.5) {
      animationController.forward();
    } else {
      animationController.reverse();
    }
  }

  @override
  void didUpdateWidget(covariant _BottomBar oldWidget) {
    if (widget.height != pageHeight) {
      setState(() {
        pageHeight = widget.height;
      });
    }
    _recognizer.dispose();
    if (_width != widget.width) {
      _width = widget.width;
      Future.microtask(() {
        final box = key.currentContext?.findRenderObject() as RenderBox?;
        var oldHeight = widgetHeight;
        widgetHeight = (box?.size.height) ?? 0;
        if (oldHeight != widgetHeight) {
          setState(() {});
        }
      });
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: CurvedAnimation(
        parent: animationController,
        curve: Curves.ease,
        reverseCurve: Curves.ease,
      ),
      builder: (context, child) {
        return Positioned(
          top: minValue + (maxValue - minValue) * animationController.value,
          left: 0,
          right: 0,
          child: Listener(
            onPointerDown: (event) {
              _recognizer.addPointer(event);
            },
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                var offset = (event).scrollDelta.dy;
                if (offset < 0) {
                  animationController.reverse();
                } else {
                  animationController.forward();
                }
              }
            },
            child: Card(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
              backgroundColor:
                  FluentTheme.of(context).micaBackgroundColor.toOpacity(0.96),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: double.infinity,
                key: key,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildTop(),
                    buildStats(),
                    buildTags(),
                    buildMoreActions(),
                    SelectableText(
                      "${"Artwork ID".tl}: ${widget.illust.id}\n"
                      "${"Artist ID".tl}: ${widget.illust.author.id}\n"
                      "${widget.illust.createDate.toString().split('.').first}",
                      style: TextStyle(color: ColorScheme.of(context).outline),
                    ).paddingLeft(4),
                    SizedBox(
                      height: 8 + context.padding.bottom,
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget buildTop() {
    return SizedBox(
      height: _kBottomBarHeight,
      width: double.infinity,
      child: LayoutBuilder(builder: (context, constrains) {
        return Row(
          children: [
            buildAuthor(),
            ...buildActions(constrains.maxWidth),
            const Spacer(),
            if (animationController.value == 1)
              IconButton(
                  icon: const Icon(FluentIcons.up),
                  onPressed: () {
                    animationController.reverse();
                  })
            else
              IconButton(
                  icon: const Icon(FluentIcons.down),
                  onPressed: () {
                    animationController.forward();
                  })
          ],
        );
      }),
    );
  }

  bool isFollowing = false;

  void follow() async {
    if (isFollowing) return;
    setState(() {
      isFollowing = true;
    });
    var method = widget.illust.author.isFollowed ? "delete" : "add";
    var res =
        await Network().follow(widget.illust.author.id.toString(), method);
    if (res.error) {
      if (mounted) {
        context.showToast(message: "Network Error");
      }
    } else {
      widget.illust.author.isFollowed = !widget.illust.author.isFollowed;
    }
    setState(() {
      isFollowing = false;
    });
    UserInfoPage.followCallbacks[widget.illust.author.id.toString()]
        ?.call(widget.illust.author.isFollowed);
    UserPreviewWidget.followCallbacks[widget.illust.author.id.toString()]
        ?.call(widget.illust.author.isFollowed);
  }

  Widget buildAuthor() {
    final bool showUserName = MediaQuery.of(context).size.width > 640;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: double.infinity,
        width: showUserName ? 246 : 136,
        child: Row(
          children: [
            SizedBox(
              height: 40,
              width: 40,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: ColoredBox(
                  color: ColorScheme.of(context).secondaryContainer,
                  child: GestureDetector(
                    onTap: () => context.to(() => UserInfoPage(
                          widget.illust.author.id.toString(),
                        )),
                    child: AnimatedImage(
                      image: CachedImageProvider(widget.illust.author.avatar),
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(
              width: 8,
            ),
            if (showUserName)
              Expanded(
                child: Text(
                  widget.illust.author.name,
                  maxLines: 2,
                ),
              ),
            if (isFollowing)
              Button(
                  onPressed: follow,
                  child: const SizedBox(
                    width: 42,
                    height: 24,
                    child: Center(
                      child: SizedBox.square(
                        dimension: 18,
                        child: ProgressRing(
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  ))
            else if (!widget.illust.author.isFollowed)
              Button(onPressed: follow, child: Text("Follow".tl).fixWidth(62))
            else
              Button(
                onPressed: follow,
                child: Text(
                  "Unfollow".tl,
                  style: TextStyle(color: ColorScheme.of(context).error),
                ).fixWidth(62),
              ),
          ],
        ),
      ),
    );
  }

  bool isBookmarking = false;

  void favorite([String type = "public"]) async {
    if (isBookmarking) return;
    setState(() {
      isBookmarking = true;
    });
    var method = widget.illust.isBookmarked ? "delete" : "add";
    var res =
        await Network().addBookmark(widget.illust.id.toString(), method, type);
    if (res.error) {
      if (mounted) {
        context.showToast(message: "Network Error");
      }
    } else {
      widget.illust.isBookmarked = !widget.illust.isBookmarked;
      IllustWidget.favoriteCallbacks[widget.illust.id.toString()]
          ?.call(widget.illust.isBookmarked);
    }
    setState(() {
      isBookmarking = false;
    });
  }

  Iterable<Widget> buildActions(double width) sync* {
    yield const SizedBox(
      width: 8,
    );

    void download() {
      DownloadManager().addDownloadingTask(widget.illust);
      setState(() {});
    }

    bool showText = width > 640;

    yield Button(
      onPressed: favorite,
      child: SizedBox(
        height: 28,
        child: Row(
          children: [
            if (isBookmarking)
              const SizedBox(
                width: 18,
                height: 18,
                child: ProgressRing(
                  strokeWidth: 2,
                ),
              )
            else if (widget.illust.isBookmarked)
              Icon(
                Icons.favorite,
                color: ColorScheme.of(context).error,
                size: 18,
              )
            else
              const Icon(
                Icons.favorite_border,
                size: 18,
              ),
            if (showText)
              const SizedBox(
                width: 8,
              ),
            if (showText)
              if (widget.illust.isBookmarked)
                Text("Cancel".tl)
              else
                Text("Favorite".tl)
          ],
        ),
      ),
    );

    yield const SizedBox(
      width: 8,
    );

    if (!widget.illust.downloaded) {
      if (widget.illust.downloading) {
        yield Button(
          onPressed: () => {},
          child: SizedBox(
            height: 28,
            child: Row(
              children: [
                Icon(
                  FluentIcons.download,
                  color: ColorScheme.of(context).outline,
                  size: 18,
                ),
                if (showText)
                  const SizedBox(
                    width: 8,
                  ),
                if (showText)
                  Text(
                    "Downloading".tl,
                    style: TextStyle(color: ColorScheme.of(context).outline),
                  ),
              ],
            ),
          ),
        );
      } else {
        yield Button(
          onPressed: download,
          child: SizedBox(
            height: 28,
            child: Row(
              children: [
                const Icon(
                  FluentIcons.download,
                  size: 18,
                ),
                if (showText)
                  const SizedBox(
                    width: 8,
                  ),
                if (showText) Text("Download".tl),
              ],
            ),
          ),
        );
      }
    }

    yield const SizedBox(
      width: 8,
    );

    yield Button(
      onPressed: () => CommentsPage.show(context, widget.illust.id.toString()),
      child: SizedBox(
        height: 28,
        child: Row(
          children: [
            const Icon(
              FluentIcons.comment,
              size: 18,
            ),
            if (showText)
              const SizedBox(
                width: 8,
              ),
            if (showText) Text("Comment".tl),
          ],
        ),
      ),
    );
  }

  Widget buildStats() {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          const SizedBox(
            width: 2,
          ),
          Expanded(
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                  border: Border.all(
                      color: ColorScheme.of(context).outlineVariant,
                      width: 0.6),
                  borderRadius: BorderRadius.circular(4)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        FluentIcons.view,
                        size: 20,
                      ),
                      Text(
                        "Views".tl,
                        style: const TextStyle(fontSize: 12),
                      )
                    ],
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  Text(
                    widget.illust.totalView.toString(),
                    style: TextStyle(
                        color: ColorScheme.of(context).primary,
                        fontWeight: FontWeight.w500,
                        fontSize: 18),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(
            width: 16,
          ),
          Expanded(
              child: Container(
            height: 52,
            decoration: BoxDecoration(
                border: Border.all(
                    color: ColorScheme.of(context).outlineVariant, width: 0.6),
                borderRadius: BorderRadius.circular(4)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      FluentIcons.six_point_star,
                      size: 20,
                    ),
                    Text(
                      "Favorites".tl,
                      style: const TextStyle(fontSize: 12),
                    )
                  ],
                ),
                const SizedBox(
                  width: 12,
                ),
                Text(
                  widget.illust.totalBookmarks.toString(),
                  style: TextStyle(
                      color: ColorScheme.of(context).primary,
                      fontWeight: FontWeight.w500,
                      fontSize: 18),
                )
              ],
            ),
          )),
          const SizedBox(
            width: 2,
          ),
        ],
      ),
    );
  }

  Widget buildTags() {
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: widget.illust.tags.map((e) {
          var text = e.name;
          if (e.translatedName != null && e.name != e.translatedName) {
            text += "/${e.translatedName}";
          }
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                context.to(() => SearchResultPage(e.name));
              },
              child: Card(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                child: Text(
                  text,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ).paddingVertical(8).paddingHorizontal(2);
  }

  Widget buildMoreActions() {
    return Wrap(
      runSpacing: 8,
      spacing: 8,
      children: [
        Button(
          onPressed: () => favorite("private"),
          child: SizedBox(
            height: 28,
            child: Row(
              children: [
                if (isBookmarking)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: ProgressRing(
                      strokeWidth: 2,
                    ),
                  )
                else if (widget.illust.isBookmarked)
                  Icon(
                    Icons.favorite,
                    color: ColorScheme.of(context).error,
                    size: 18,
                  )
                else
                  const Icon(
                    Icons.favorite_border,
                    size: 18,
                  ),
                const SizedBox(
                  width: 8,
                ),
                if (widget.illust.isBookmarked)
                  Text("Cancel".tl)
                else
                  Text("Private".tl)
              ],
            ),
          ),
        ).fixWidth(96),
        Button(
          onPressed: () {
            Share.share(
                "${widget.illust.title}\nhttps://pixiv.net/artworks/${widget.illust.id}");
          },
          child: SizedBox(
            height: 28,
            child: Row(
              children: [
                const Icon(
                  Icons.share,
                  size: 18,
                ),
                const SizedBox(
                  width: 8,
                ),
                Text("Share".tl)
              ],
            ),
          ),
        ).fixWidth(96),
        Button(
          onPressed: () {
            var text = "https://pixiv.net/artworks/${widget.illust.id}";
            Clipboard.setData(ClipboardData(text: text));
            showToast(context, message: "Copied".tl);
          },
          child: SizedBox(
            height: 28,
            child: Row(
              children: [
                const Icon(Icons.copy, size: 18),
                const SizedBox(
                  width: 8,
                ),
                Text("Link".tl)
              ],
            ),
          ),
        ).fixWidth(96),
        Button(
          onPressed: () {
            context.to(() => RelatedIllustsPage(widget.illust.id.toString()));
          },
          child: SizedBox(
            height: 28,
            child: Row(
              children: [
                const Icon(Icons.stars, size: 18),
                const SizedBox(
                  width: 8,
                ),
                Text("Related".tl)
              ],
            ),
          ),
        ).fixWidth(96),
        Button(
          onPressed: () async {
            await Navigator.of(context)
                .push(SideBarRoute(_BlockingPage(widget.illust)));
            if (mounted) {
              widget.updateCallback?.call();
            }
          },
          child: SizedBox(
            height: 28,
            child: Row(
              children: [
                const Icon(MdIcons.block, size: 18),
                const SizedBox(
                  width: 8,
                ),
                Text("Block".tl)
              ],
            ),
          ),
        ).fixWidth(96),
      ],
    ).paddingHorizontal(2).paddingBottom(4);
  }
}

class _BlockingPage extends StatefulWidget {
  const _BlockingPage(this.illust);

  final Illust illust;

  @override
  State<_BlockingPage> createState() => __BlockingPageState();
}

class __BlockingPageState extends State<_BlockingPage> {
  List<int> blockedTags = [];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TitleBar(title: "Block".tl),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.only(bottom: context.padding.bottom),
            itemCount: widget.illust.tags.length + 2,
            itemBuilder: (context, index) {
              if (index == widget.illust.tags.length + 1) {
                return buildSubmit();
              }

              var text = index == 0
                  ? widget.illust.author.name
                  : widget.illust.tags[index - 1].name;

              var subTitle = index == 0
                  ? "author"
                  : widget.illust.tags[index - 1].translatedName ?? "";

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                borderColor: blockedTags.contains(index)
                    ? ColorScheme.of(context).outlineVariant
                    : ColorScheme.of(context).outlineVariant.toOpacity(0.2),
                padding: EdgeInsets.zero,
                child: ListTile(
                  title: Text(text),
                  subtitle: Text(subTitle),
                  trailing: Button(
                          onPressed: () {
                            if (blockedTags.contains(index)) {
                              blockedTags.remove(index);
                            } else {
                              blockedTags.add(index);
                            }
                            setState(() {});
                          },
                          child: blockedTags.contains(index)
                              ? Text("Cancel".tl)
                              : Text("Block".tl))
                      .fixWidth(72),
                ),
              );
            },
          ),
        )
      ],
    );
  }

  var flyout = FlyoutController();

  bool isSubmitting = false;

  Widget buildSubmit() {
    return FlyoutTarget(
      controller: flyout,
      child: FilledButton(
        onPressed: () async {
          if (this.blockedTags.isEmpty) {
            return;
          }
          if (isSubmitting) return;
          var blockedTags = <String>[];
          var blockedUsers = <String>[];
          for (var i in this.blockedTags) {
            if (i == 0) {
              blockedUsers.add(widget.illust.author.id.toString());
            } else {
              blockedTags.add(widget.illust.tags[i - 1].name);
            }
          }
          bool addToAccount = false;
          bool addToLocal = false;
          if (appdata.account!.user.isPremium) {
            await flyout.showFlyout(
                navigatorKey: App.rootNavigatorKey.currentState,
                builder: (context) {
                  return MenuFlyout(
                    items: [
                      MenuFlyoutItem(
                          text: Text("Local".tl),
                          onPressed: () {
                            addToLocal = true;
                          }),
                      MenuFlyoutItem(
                          text: Text("Account".tl),
                          onPressed: () {
                            addToAccount = true;
                          }),
                      MenuFlyoutItem(
                          text: Text("Both".tl),
                          onPressed: () {
                            addToLocal = true;
                            addToAccount = true;
                          }),
                    ],
                  );
                });
          } else {
            addToLocal = true;
          }
          if (addToAccount) {
            setState(() {
              isSubmitting = true;
            });
            var res =
                await Network().editMute(blockedTags, blockedUsers, [], []);
            setState(() {
              isSubmitting = false;
            });
            if (res.error) {
              if (mounted) {
                context.showToast(message: "Network Error");
              }
              return;
            }
          }
          if (addToLocal) {
            for (var tag in blockedTags) {
              appdata.settings['blockTags'].add(tag);
            }
            for (var user in blockedUsers) {
              appdata.settings['blockTags'].add('user:$user');
            }
            appdata.writeSettings();
          }
          if (mounted) {
            context.pop();
          }
        },
        child: isSubmitting
            ? const ProgressRing(
                strokeWidth: 1.6,
              ).fixWidth(18).fixHeight(18).toAlign(Alignment.center)
            : Text("Submit".tl),
      ).fixWidth(96).fixHeight(32),
    ).toAlign(Alignment.center).paddingTop(16);
  }
}

class IllustPageWithId extends StatefulWidget {
  const IllustPageWithId(this.id, {super.key});

  final String id;

  @override
  State<IllustPageWithId> createState() => _IllustPageWithIdState();
}

class _IllustPageWithIdState extends LoadingState<IllustPageWithId, Illust> {
  @override
  Widget buildContent(BuildContext context, Illust data) {
    return IllustPage(data);
  }

  @override
  Future<Res<Illust>> loadData() {
    return Network().getIllustByID(widget.id);
  }
}
