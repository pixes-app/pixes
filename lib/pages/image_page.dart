import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:pixes/components/md.dart';
import 'package:pixes/components/message.dart';
import 'package:pixes/components/page_route.dart';
import 'package:pixes/foundation/app.dart';
import 'package:pixes/foundation/cache_manager.dart';
import 'package:pixes/foundation/image_provider.dart';
import 'package:pixes/pages/main_page.dart';
import 'package:pixes/utils/io.dart';
import 'package:pixes/utils/translation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:window_manager/window_manager.dart';

class ImagePage extends StatefulWidget {
  const ImagePage(this.urls, {this.initialPage = 0, super.key});

  final List<String> urls;

  final int initialPage;

  static show(List<String> urls, {int initialPage = 0}) {
    App.rootNavigatorKey.currentState?.push(AppPageRoute(
        builder: (context) => ImagePage(urls, initialPage: initialPage)));
  }

  @override
  State<ImagePage> createState() => _ImagePageState();
}

class _ImagePageState extends State<ImagePage> with WindowListener {
  int windowButtonKey = 0;

  @override
  void initState() {
    windowManager.addListener(this);
    super.initState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
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

  late var controller = PageController(initialPage: widget.initialPage);

  late int currentPage = widget.initialPage;

  var menuController = FlyoutController();

  Future<File?> getFile() async {
    var image = widget.urls[currentPage];
    if (image.startsWith("file://")) {
      return File(image.replaceFirst("file://", ""));
    }
    var key = image;
    if (key.startsWith("novel:")) {
      key = key.split(':').last;
    }
    var file = await CacheManager().findCache(key);
    return file == null ? null : File(file);
  }

  String getExtensionName() {
    var fileName = widget.urls[currentPage].split('/').last;
    if (fileName.contains('.')) {
      return '.${fileName.split('.').last}';
    }
    return '.jpg';
  }

  void showMenu() {
    menuController.showFlyout(
        barrierColor: Colors.transparent,
        position: App.isMobile ? Offset(context.size!.width, 0) : null,
        builder: (context) => MenuFlyout(
              items: [
                MenuFlyoutItem(
                    text: Text("Save to".tl),
                    onPressed: () async {
                      var file = await getFile();
                      if (file != null) {
                        var fileName = widget.urls[currentPage].split('/').last;
                        if (!fileName.contains('.')) {
                          fileName += getExtensionName();
                        }
                        saveFile(file, fileName);
                      }
                    }),
                if (App.isMobile)
                  MenuFlyoutItem(
                      text: Text("Save to gallery".tl),
                      onPressed: () async {
                        var file = await getFile();
                        if (file != null) {
                          var fileName =
                              widget.urls[currentPage].split('/').last;
                          if (!fileName.contains('.')) {
                            fileName += getExtensionName();
                          }
                          await ImageGallerySaverPlus.saveImage(
                            await file.readAsBytes(),
                            quality: 100,
                            name: fileName,
                          );
                          if (context.mounted) {
                            showToast(context, message: "Saved".tl);
                          }
                        }
                      }),
                MenuFlyoutItem(
                    text: Text("Share".tl),
                    onPressed: () async {
                      var file = await getFile();
                      if (file != null) {
                        var ext = getExtensionName();
                        var fileName = widget.urls[currentPage].split('/').last;
                        if (!fileName.contains('.')) {
                          fileName += ext;
                        }
                        var mediaType = switch (ext) {
                          '.jpg' => 'image/jpeg',
                          '.jpeg' => 'image/jpeg',
                          '.png' => 'image/png',
                          '.gif' => 'image/gif',
                          '.webp' => 'image/webp',
                          _ => 'application/octet-stream'
                        };
                        Share.shareXFiles([
                          XFile.fromData(await file.readAsBytes(),
                              mimeType: mediaType, name: fileName)
                        ]);
                      }
                    }),
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      color: FluentTheme.of(context).micaBackgroundColor,
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent &&
              !HardwareKeyboard.instance.isControlPressed) {
            if (event.scrollDelta.dy > 0 &&
                controller.page!.toInt() < widget.urls.length - 1) {
              controller.jumpToPage(controller.page!.toInt() + 1);
            } else if (event.scrollDelta.dy < 0 &&
                controller.page!.toInt() > 0) {
              controller.jumpToPage(controller.page!.toInt() - 1);
            }
          }
        },
        child: LayoutBuilder(
          builder: (context, constrains) {
            var height = constrains.maxHeight;
            return Stack(
              children: [
                Positioned.fill(
                    child: PhotoViewGallery.builder(
                  pageController: controller,
                  backgroundDecoration:
                      const BoxDecoration(color: Colors.transparent),
                  itemCount: widget.urls.length,
                  builder: (context, index) {
                    var image = widget.urls[index];

                    return PhotoViewGalleryPageOptions(
                      filterQuality: FilterQuality.medium,
                      imageProvider: getImageProvider(image),
                    );
                  },
                  onPageChanged: (index) {
                    setState(() {
                      currentPage = index;
                    });
                  },
                )),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SizedBox(
                    height: 36,
                    child: Row(
                      children: [
                        if (App.isMacOS)
                          const SizedBox(width: 72),
                        const SizedBox(
                          width: 6,
                        ),
                        IconButton(
                            icon: const Icon(FluentIcons.back).paddingAll(2),
                            onPressed: () => context.pop()),
                        const Expanded(
                          child: DragToMoveArea(
                            child: SizedBox.expand(),
                          ),
                        ),
                        buildActions(),
                        if (App.isMacOS)
                          const SizedBox(width: 16),
                        if (App.isWindows || App.isLinux)
                          WindowButtons(
                            key: ValueKey(windowButtonKey),
                          ),
                      ],
                    ),
                  ),
                ),
                if (currentPage != 0)
                  Positioned(
                    left: 0,
                    top: height / 2 - 9,
                    child: IconButton(
                      icon: const Icon(
                        FluentIcons.chevron_left,
                        size: 18,
                      ),
                      onPressed: () {
                        controller.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                    ).paddingAll(8),
                  ),
                if (currentPage != widget.urls.length - 1)
                  Positioned(
                    right: 0,
                    top: height / 2 - 9,
                    child: IconButton(
                      icon: const Icon(FluentIcons.chevron_right, size: 18),
                      onPressed: () {
                        controller.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                    ).paddingAll(8),
                  ),
                Positioned(
                  left: 12,
                  bottom: 8,
                  child: Text(
                    "${currentPage + 1}/${widget.urls.length}",
                  ),
                )
              ],
            );
          },
        ),
      ),
    );
  }

  Widget buildActions() {
    var width = MediaQuery.of(context).size.width;
    return FlyoutTarget(
      controller: menuController,
      child: width > 600
          ? Button(
              onPressed: showMenu,
              child: Row(
                children: [
                  const Icon(
                    MdIcons.menu,
                    size: 18,
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  Text('Actions'.tl),
                ],
              ))
          : IconButton(
              icon: const Icon(
                MdIcons.more_horiz,
                size: 20,
              ),
              onPressed: showMenu),
    );
  }

  ImageProvider getImageProvider(String url) {
    if (url.startsWith("file://")) {
      return FileImage(File(url.replaceFirst("file://", "")));
    } else if (url.startsWith("novel:")) {
      var ids = url.split(':').last.split('/');
      return CachedNovelImageProvider(ids[0], ids[1]);
    }
    return CachedImageProvider(url) as ImageProvider;
  }
}
