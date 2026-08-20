import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixes/appdata.dart';
import 'package:pixes/components/md.dart';
import 'package:pixes/foundation/app.dart';
import 'package:pixes/network/network.dart';
import 'package:pixes/pages/main_page.dart';
import 'package:pixes/pages/novel_reading_page.dart';
import 'package:pixes/utils/translation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(Translation.init);

  testWidgets('novel auto-scroll moves, changes speed, and stops safely',
      (tester) async {
    final originalSpeed = appdata.settings["readingAutoScrollSpeed"];
    appdata.settings["readingAutoScrollSpeed"] = 40.0;
    final titleBarController =
        StateController.put<TitleBarController>(TitleBarController());
    Network().dio.httpClientAdapter = _NovelContentAdapter(_longNovelContent);

    addTearDown(() {
      appdata.settings["readingAutoScrollSpeed"] = originalSpeed;
      Network.instance = null;
      StateController.remove<TitleBarController>();
    });

    await tester.pumpWidget(
      FluentApp(home: NovelReadingPage(_testNovel())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Test Novel'), findsOneWidget);
    final scrollable =
        tester.state<ScrollableState>(find.byType(Scrollable).first);
    final position = scrollable.position;
    expect(position.maxScrollExtent, greaterThan(0));

    final initialAction = _action(titleBarController, 'Auto Scroll');
    expect(initialAction.compactOnMobile, isTrue);
    initialAction.onPressed();
    await tester.pump();
    final slowStart = position.pixels;
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final slowDistance = position.pixels - slowStart;
    expect(slowDistance, closeTo(40, 1));
    expect(_action(titleBarController, 'Pause').icon, MdIcons.pause);

    appdata.settings["readingAutoScrollSpeed"] = 80.0;
    final fastStart = position.pixels;
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final fastDistance = position.pixels - fastStart;
    expect(fastDistance, closeTo(80, 1));

    _action(titleBarController, 'Pause').onPressed();
    final pausedOffset = position.pixels;
    await tester.pump(const Duration(seconds: 1));
    expect(position.pixels, pausedOffset);

    position.jumpTo(position.maxScrollExtent - 1);
    _action(titleBarController, 'Auto Scroll').onPressed();
    await tester.pump();
    for (var i = 0;
        i < 400 &&
            titleBarController.actions
                .any((action) => action.title == 'Pause'.tl);
        i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(position.pixels, closeTo(position.maxScrollExtent, 0.5));
    expect(_action(titleBarController, 'Auto Scroll').icon, MdIcons.play_arrow);

    position.jumpTo(100);
    _action(titleBarController, 'Settings').onPressed();
    await tester.pumpAndSettle();
    final slider = tester.widget<Slider>(
      find.byKey(const ValueKey('novel-auto-scroll-speed')),
    );
    expect(slider.value, 80.0);
    slider.onChanged!(100.0);
    await tester.pump();
    expect(appdata.settings["readingAutoScrollSpeed"], 100.0);

    final offsetBehindSettings = position.pixels;
    _action(titleBarController, 'Auto Scroll').onPressed();
    await tester.pump(const Duration(seconds: 1));
    expect(position.pixels, offsetBehindSettings);

    Navigator.of(tester.element(find.byType(NovelReadingPage))).pop();
    await tester.pumpAndSettle();
    _action(titleBarController, 'Auto Scroll').onPressed();
    await tester.pump();
    final updatedSpeedStart = position.pixels;
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(position.pixels - updatedSpeedStart, closeTo(100, 1));
    _action(titleBarController, 'Pause').onPressed();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
  });
}

TitleBarAction _action(TitleBarController controller, String title) {
  return controller.actions.singleWhere((action) => action.title == title.tl);
}

Novel _testNovel() {
  return Novel.fromJson({
    "id": 1,
    "title": "Test Novel",
    "caption": "",
    "is_original": true,
    "image_urls": {"large": ""},
    "create_date": "2026-01-01T00:00:00+00:00",
    "tags": <Object>[],
    "page_count": 1,
    "text_length": _longNovelContent.length,
    "user": {
      "id": 1,
      "name": "Author",
      "account": "author",
      "profile_image_urls": {"medium": ""},
      "is_followed": false,
    },
    "series": null,
    "is_bookmarked": false,
    "total_bookmarks": 0,
    "total_view": 0,
    "total_comments": 0,
    "novel_ai_type": 0,
  });
}

final String _longNovelContent = List.generate(
  200,
  (index) => 'Paragraph $index with enough text to keep the reader scrolling.',
).join('\n');

class _NovelContentAdapter implements HttpClientAdapter {
  _NovelContentAdapter(this.content);

  final String content;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = '<script>novel: ${jsonEncode({"text": content})}</script>';
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: ['text/html; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
