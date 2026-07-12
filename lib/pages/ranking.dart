import 'package:fluent_ui/fluent_ui.dart' hide TitleBar;
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:pixes/foundation/app.dart';
import 'package:pixes/utils/block.dart';
import 'package:pixes/utils/translation.dart';

import '../components/batch_download.dart';
import '../components/illust_widget.dart';
import '../components/loading.dart';
import '../components/title_bar.dart';
import '../network/network.dart';
import 'illust_page.dart';

class RankingPage extends StatefulWidget {
  const RankingPage({super.key});

  @override
  State<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> {
  String type = "day";
  final pageKey = GlobalKey<_OneRankingPageState>();

  /// mode: day, week, month, day_male, day_female, week_original, week_rookie, day_manga, week_manga, month_manga, day_r18_manga, day_r18
  static const types = {
    "day": "Daily",
    "week": "Weekly",
    "month": "Monthly",
    "day_male": "For male",
    "day_female": "For female",
    "week_original": "Originals",
    "week_rookie": "Rookies",
    "day_manga": "Daily Manga",
    "week_manga": "Weekly Manga",
    "month_manga": "Monthly Manga",
    "day_r18_manga": "R18",
  };

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: Column(
        children: [
          buildHeader(),
          Expanded(
            child: _OneRankingPage(
              type,
              key: pageKey,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildHeader() {
    return TitleBar(
      title: "Ranking".tl,
      onRefresh: () => pageKey.currentState?.refresh(),
      action: Row(
        children: [
          BatchDownloadButton(request: () => Network().getRanking(type)),
          const SizedBox(
            width: 8,
          ),
          DropDownButton(
            title: Text(types[type]!.tl),
            items: types.entries
                .map((e) => MenuFlyoutItem(
                      text: Text(e.value.tl),
                      onPressed: () {
                        setState(() {
                          type = e.key;
                        });
                      },
                    ))
                .toList(),
          )
        ],
      ),
    );
  }
}

class _OneRankingPage extends StatefulWidget {
  const _OneRankingPage(this.type, {super.key});

  final String type;

  @override
  State<_OneRankingPage> createState() => _OneRankingPageState();
}

class _OneRankingPageState
    extends MultiPageLoadingState<_OneRankingPage, Illust> {
  @override
  void didUpdateWidget(covariant _OneRankingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.type != widget.type) {
      nextUrl = null;
      reset();
    }
  }

  @override
  Future<void> refresh() {
    nextUrl = null;
    return super.refresh();
  }

  @override
  Widget buildContent(BuildContext context, final List<Illust> data) {
    checkIllusts(data);
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
                illusts: data, initialPage: index, nextUrl: nextUrl));
          });
        },
      ));
  }

  String? nextUrl;

  @override
  Future<Res<List<Illust>>> loadData(page) async {
    if (nextUrl == "end") {
      return Res.error("No more data");
    }
    var res = await Network().getRanking(widget.type, nextUrl);
    if (!res.error) {
      nextUrl = res.subData;
      nextUrl ??= "end";
    }
    return res;
  }
}
