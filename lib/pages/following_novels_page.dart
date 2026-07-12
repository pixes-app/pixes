import 'package:fluent_ui/fluent_ui.dart' hide TitleBar;
import 'package:pixes/components/grid.dart';
import 'package:pixes/components/loading.dart';
import 'package:pixes/components/novel.dart';
import 'package:pixes/components/segmented_button.dart';
import 'package:pixes/components/title_bar.dart';
import 'package:pixes/foundation/widget_utils.dart';
import 'package:pixes/network/network.dart';
import 'package:pixes/utils/translation.dart';

class FollowingNovelsPage extends StatefulWidget {
  const FollowingNovelsPage({super.key});

  @override
  State<FollowingNovelsPage> createState() => _FollowingNovelsPageState();
}

class _FollowingNovelsPageState
    extends MultiPageLoadingState<FollowingNovelsPage, Novel> {
  bool public = true;

  @override
  Widget? buildFrame(BuildContext context, Widget child) {
    return Column(
      children: [
        TitleBar(
          title: "Following".tl,
          onRefresh: refresh,
          action: SegmentedButton(
            options: [
              SegmentedButtonOption("public", "Public".tl),
              SegmentedButtonOption("private", "Private".tl),
            ],
            onPressed: (key) {
              var newPublic = key == "public";
              if (newPublic != public) {
                public = newPublic;
                nextUrl = null;
                reset();
              }
            },
            value: public ? "public" : "private",
          ),
        ),
        Expanded(
          child: child,
        )
      ],
    );
  }

  @override
  Widget buildContent(BuildContext context, List<Novel> data) {
    return Column(
      children: [
        Expanded(
          child: withRefresh(GridViewWithFixedItemHeight(
            itemCount: data.length,
            itemHeight: 164,
            minCrossAxisExtent: 400,
            builder: (context, index) {
              if (index == data.length - 1) {
                nextPage();
              }
              return NovelWidget(data[index]);
            },
          ).paddingHorizontal(8)),
        )
      ],
    );
  }

  String? nextUrl;

  @override
  Future<void> refresh() {
    nextUrl = null;
    return super.refresh();
  }

  @override
  Future<Res<List<Novel>>> loadData(int page) async {
    if (nextUrl == "end") return Res.error("No more data");
    var res = nextUrl == null
        ? await Network().getFollowingNovels(public ? "public" : "private")
        : await Network().getNovelsWithNextUrl(nextUrl!);
    nextUrl = res.subData ?? "end";
    return res;
  }
}
