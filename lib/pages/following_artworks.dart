import 'package:fluent_ui/fluent_ui.dart' hide TitleBar;
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:pixes/components/title_bar.dart';
import 'package:pixes/foundation/app.dart';
import 'package:pixes/utils/block.dart';
import 'package:pixes/utils/translation.dart';

import '../components/batch_download.dart';
import '../components/illust_widget.dart';
import '../components/loading.dart';
import '../components/segmented_button.dart';
import '../network/network.dart';
import 'illust_page.dart';

class FollowingArtworksPage extends StatefulWidget {
  const FollowingArtworksPage({super.key});

  @override
  State<FollowingArtworksPage> createState() => _FollowingArtworksPageState();
}

class _FollowingArtworksPageState extends State<FollowingArtworksPage> {
  String restrict = "all";
  final pageKey = GlobalKey<_OneFollowingPageState>();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        buildTab(),
        Expanded(
          child: _OneFollowingPage(
            restrict,
            key: pageKey,
          ),
        )
      ],
    );
  }

  Widget buildTab() {
    return TitleBar(
      title: "Following".tl,
      onRefresh: () => pageKey.currentState?.refresh(),
      action: Row(
        children: [
          BatchDownloadButton(
              request: () => Network().getFollowingArtworks(restrict)),
          const SizedBox(
            width: 8,
          ),
          SegmentedButton(
            options: [
              SegmentedButtonOption("all", "All".tl),
              SegmentedButtonOption("public", "Public".tl),
              SegmentedButtonOption("private", "Private".tl),
            ],
            onPressed: (key) {
              if (key != restrict) {
                setState(() {
                  restrict = key;
                });
              }
            },
            value: restrict,
          )
        ],
      ),
    );
  }
}

class _OneFollowingPage extends StatefulWidget {
  const _OneFollowingPage(this.restrict, {super.key});

  final String restrict;

  @override
  State<_OneFollowingPage> createState() => _OneFollowingPageState();
}

class _OneFollowingPageState
    extends MultiPageLoadingState<_OneFollowingPage, Illust> {
  @override
  void didUpdateWidget(covariant _OneFollowingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.restrict != widget.restrict) {
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
  Widget buildContent(BuildContext context, List<Illust> data) {
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
    var res = await Network().getFollowingArtworks(widget.restrict, nextUrl);
    if (!res.error) {
      nextUrl = res.subData;
      nextUrl ??= "end";
    }
    return res;
  }
}
