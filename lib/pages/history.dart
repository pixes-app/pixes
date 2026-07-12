import 'package:fluent_ui/fluent_ui.dart' hide TitleBar;
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:pixes/appdata.dart';
import 'package:pixes/components/loading.dart';
import 'package:pixes/components/segmented_button.dart';
import 'package:pixes/components/title_bar.dart';
import 'package:pixes/foundation/app.dart';
import 'package:pixes/foundation/history.dart';
import 'package:pixes/network/network.dart';
import 'package:pixes/utils/translation.dart';

import '../components/illust_widget.dart';
import 'illust_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  int page = 0;
  final networkPageKey = GlobalKey<_NetworkHistoryPageState>();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TitleBar(
          title: "History".tl,
          onRefresh: page == 1 ? () => networkPageKey.currentState?.refresh() : null,
          action: SegmentedButton<int>(
            options: [
              SegmentedButtonOption(
                0,
                "Local".tl,
              ),
              SegmentedButtonOption(
                1,
                "Network".tl,
              ),
            ],
            value: page,
            onPressed: (key) {
              setState(() {
                page = key;
              });
            },
          ),
        ),
        Expanded(
          child: page == 0
              ? const LocalHistoryPage()
              : NetworkHistoryPage(
                  key: networkPageKey,
                ),
        ),
      ],
    );
  }
}

class LocalHistoryPage extends StatefulWidget {
  const LocalHistoryPage({super.key});

  @override
  State<LocalHistoryPage> createState() => _LocalHistoryPageState();
}

class _LocalHistoryPageState extends State<LocalHistoryPage> {
  int page = 1;

  var data = <IllustHistory>[];

  Future<void> refresh() async {
    setState(() {
      page = 1;
      data = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return withRefresh(MasonryGridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 8) +
            EdgeInsets.only(bottom: context.padding.bottom),
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverSimpleGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 240,
        ),
        itemCount: HistoryManager().length,
        itemBuilder: (context, index) {
          if (index == data.length) {
            data.addAll(HistoryManager().getHistories(page));
            page++;
          }
          return IllustHistoryWidget(data[index]);
        },
      ));
  }

  Widget withRefresh(Widget child) {
    return buildRefreshWrapper(
      onRefresh: refresh,
      child: child,
    );
  }
}

class NetworkHistoryPage extends StatefulWidget {
  const NetworkHistoryPage({super.key});

  @override
  State<NetworkHistoryPage> createState() => _NetworkHistoryPageState();
}

class _NetworkHistoryPageState
    extends MultiPageLoadingState<NetworkHistoryPage, Illust> {
  @override
  Widget buildContent(BuildContext context, final List<Illust> data) {
    return withRefresh(MasonryGridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 8) +
            EdgeInsets.only(bottom: context.padding.bottom),
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverSimpleGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 240,
        ),
        itemCount: data.length,
        itemBuilder: (context, index) {
          if (index == data.length - 1) {
            nextPage();
          }
          return IllustWidget(data[index], onTap: () {
            context.to(() => IllustGalleryPage(
                  illusts: data,
                  initialPage: index,
            ));
          });
        },
      ));
  }

  @override
  Future<Res<List<Illust>>> loadData(page) {
    if (appdata.account?.user.isPremium != true) {
      return Future.value(Res.error("Premium Required".tl));
    }
    return Network().getHistory(page);
  }
}
