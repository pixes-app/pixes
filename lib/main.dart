import "dart:async";
import "dart:ui";

import "package:dynamic_color/dynamic_color.dart";
import "package:fluent_ui/fluent_ui.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart" as md;
import "package:flutter/services.dart";
import "package:pixes/appdata.dart";
import "package:pixes/components/keyboard.dart";
import "package:pixes/components/md.dart";
import "package:pixes/components/message.dart";
import "package:pixes/foundation/app.dart";
import "package:pixes/foundation/history.dart";
import "package:pixes/foundation/log.dart";
import "package:pixes/network/app_dio.dart";
import "package:pixes/pages/main_page.dart";
import "package:pixes/utils/app_links.dart";
import "package:pixes/utils/loop.dart";
import "package:pixes/utils/translation.dart";
import "package:pixes/utils/update.dart";
import "package:pixes/utils/window.dart";
import "package:window_manager/window_manager.dart";

void main() {
  runZonedGuarded(() async {
    Future.delayed(const Duration(seconds: 3), checkUpdate);
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      Log.error("Unhandled", "${details.exception}\n${details.stack}");
    };
    setSystemProxy();
    await App.init();
    await appdata.readData();
    await Translation.init();
    HistoryManager().init();
    handleLinks();
    if (App.isDesktop) {
      await WindowManager.instance.ensureInitialized();
      windowManager.waitUntilReadyToShow().then((_) async {
        await windowManager.setTitleBarStyle(
          TitleBarStyle.hidden,
          windowButtonVisibility: App.isMacOS,
        );
        if (App.isLinux) {
          // https://github.com/leanflutter/window_manager/issues/460
          return;
        }
       
        if (App.isMacOS) {
          await windowManager.setMinimumSize(const Size(650, 600));
        } else {
          await windowManager.setMinimumSize(const Size(500, 600));
        }
        var placement = await WindowPlacement.loadFromFile();
        await placement.applyToWindow();
        await windowManager.show();
        Loop.register(WindowPlacement.loop);
      });
    }
    Loop.start();
    Log.info("APP", "Application started");
    runApp(const MyApp());
  }, (error, stack) {
    Log.error("Unhandled Exception", "$error\n$stack");
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    return StateBuilder<SimpleController>(
        init: SimpleController(),
        tag: "MyApp",
        builder: (controller) {
          Brightness brightness =
              PlatformDispatcher.instance.platformBrightness;

          if (appdata.settings["theme"] == "Dark") {
            brightness = Brightness.dark;
          } else if (appdata.settings["theme"] == "Light") {
            brightness = Brightness.light;
          }

          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              systemNavigationBarColor: Colors.transparent,
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: brightness.opposite,
              systemNavigationBarIconBrightness: brightness.opposite,
            ),
            child: DynamicColorBuilder(
              builder: (light, dark) {
                final colorScheme =
                    (brightness == Brightness.light ? light : dark) ??
                        md.ColorScheme.fromSeed(
                            seedColor: Colors.blue, brightness: brightness);
                return FluentApp(
                    navigatorKey: App.rootNavigatorKey,
                    debugShowCheckedModeBanner: false,
                    title: 'pixes',
                    theme: FluentThemeData(
                        brightness: brightness,
                        fontFamily: App.isWindows ? "Microsoft YaHei UI" : null,
                        accentColor: AccentColor.swatch({
                          'darkest': darken(colorScheme.primary, 30),
                          'darker': darken(colorScheme.primary, 20),
                          'dark': darken(colorScheme.primary, 10),
                          'normal': colorScheme.primary,
                          'light': lighten(colorScheme.primary, 10),
                          'lighter': lighten(colorScheme.primary, 20),
                          'lightest': lighten(colorScheme.primary, 30)
                        }),
                        focusTheme: const FocusThemeData(
                          primaryBorder: BorderSide.none,
                          secondaryBorder: BorderSide.none,
                        )),
                    home: const MainPage(),
                    builder: (context, child) {
                      ErrorWidget.builder = (details) {
                        if (details.exception
                            .toString()
                            .contains("RenderFlex overflowed")) {
                          return const SizedBox.shrink();
                        }
                        Log.error(
                            "UI", "${details.exception}\n${details.stack}");
                        return Text(details.exception.toString());
                      };
                      if (child == null) {
                        throw "widget is null";
                      }

                      String? font;
                      List<String>? fallback;
                      if (App.isLinux || App.isWindows) {
                        font = 'Noto Sans CJK';
                        fallback = [
                          'Segoe UI',
                          'Noto Sans SC',
                          'Noto Sans TC',
                          'Noto Sans',
                          'Microsoft YaHei',
                          'PingFang SC',
                          'Arial',
                          'sans-serif'
                        ];
                      }

                      Widget widget = MdTheme(
                        data: MdThemeData.from(
                            colorScheme: colorScheme, useMaterial3: true),
                        child: DefaultTextStyle.merge(
                          style: TextStyle(
                            fontFamily: font,
                            fontFamilyFallback: fallback,
                          ),
                          child: OverlayWidget(child),
                        ),
                      );

                      return KeyEventListener(child: widget);
                    });
              },
            ),
          );
        });
  }
}

int _floatToInt8(double x) {
  return (x * 255.0).round() & 0xff;
}

Color darken(Color c, [int percent = 10]) {
  assert(1 <= percent && percent <= 100);
  var f = 1 - percent / 100;
  return Color.fromARGB(
    _floatToInt8(c.a),
    _floatToInt8(c.r * f),
    _floatToInt8(c.g * f),
    _floatToInt8(c.b * f),
  );
}

Color lighten(Color c, [int percent = 10]) {
  assert(1 <= percent && percent <= 100);
  var p = percent / 100;
  return Color.fromARGB(
    _floatToInt8(c.a),
    _floatToInt8(c.r + (1 - c.r) * p),
    _floatToInt8(c.g + (1 - c.g) * p),
    _floatToInt8(c.b + (1 - c.b) * p),
  );
}
