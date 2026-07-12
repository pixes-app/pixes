import 'package:fluent_ui/fluent_ui.dart' hide TitleBar;
import 'package:pixes/components/grid.dart';
import 'package:pixes/components/loading.dart';
import 'package:pixes/components/novel.dart';
import 'package:pixes/components/title_bar.dart';
import 'package:pixes/foundation/app.dart';
import 'package:pixes/network/network.dart';
import 'package:pixes/utils/translation.dart';

class NovelRecommendationPage extends StatefulWidget {
  const NovelRecommendationPage({super.key});

  @override
  State<NovelRecommendationPage> createState() =>
      _NovelRecommendationPageState();
}

class _NovelRecommendationPageState
    extends MultiPageLoadingState<NovelRecommendationPage, Novel> {
  @override
  Widget buildContent(BuildContext context, List<Novel> data) {
    return Column(
      children: [
        TitleBar(
          title: "Recommendation".tl,
          onRefresh: refresh,
        ),
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

  @override
  Future<Res<List<Novel>>> loadData(int page) {
    return Network().getRecommendNovels();
  }
}
