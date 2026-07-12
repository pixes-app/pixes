import 'package:flutter/widgets.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:pixes/components/illust_widget.dart';
import 'package:pixes/components/loading.dart';
import 'package:pixes/components/title_bar.dart';
import 'package:pixes/foundation/app.dart';
import 'package:pixes/network/network.dart';
import 'package:pixes/pages/illust_page.dart';
import 'package:pixes/utils/block.dart';
import 'package:pixes/utils/translation.dart';

import '../components/grid.dart';
import '../components/segmented_button.dart';
import '../components/user_preview.dart';

class RecommendationPage extends StatefulWidget {
  const RecommendationPage({super.key});

  @override
  State<RecommendationPage> createState() => _RecommendationPageState();
}

class _RecommendationPageState extends State<RecommendationPage> {
  var type = 0;
  final artworkPageKey = GlobalKey<_RecommendationArtworksPageState>();
  final userPageKey = GlobalKey<_RecommendationUsersPageState>();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        buildTab(),
        Expanded(
          child: type != 2
              ? _RecommendationArtworksPage(
                  type,
                  key: artworkPageKey,
                )
              : _RecommendationUsersPage(
                  key: userPageKey,
                ),
        )
      ],
    );
  }

  Widget buildTab() {
    return TitleBar(
      title: "Explore".tl,
      onRefresh: () {
        if (type != 2) {
          artworkPageKey.currentState?.refresh();
        } else {
          userPageKey.currentState?.refresh();
        }
      },
      action: SegmentedButton<int>(
        options: [
          SegmentedButtonOption(0, "Illustrations".tl),
          SegmentedButtonOption(1, "Mangas".tl),
          SegmentedButtonOption(2, "Users".tl),
        ],
        onPressed: (key) {
          if (key != type) {
            setState(() {
              type = key;
            });
          }
        },
        value: type,
      ),
    );
  }
}

class _RecommendationArtworksPage extends StatefulWidget {
  const _RecommendationArtworksPage(this.type, {super.key});

  final int type;

  @override
  State<_RecommendationArtworksPage> createState() =>
      _RecommendationArtworksPageState();
}

class _RecommendationArtworksPageState
    extends MultiPageLoadingState<_RecommendationArtworksPage, Illust> {
  @override
  void didUpdateWidget(covariant _RecommendationArtworksPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.type != widget.type) {
      reset();
    }
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
          return IllustWidget(
            data[index],
            onTap: () {
              context.to(() => IllustGalleryPage(
                    illusts: data,
                    initialPage: index,
                    nextUrl: Network.recommendationUrl,
                  ));
            },
          );
        },
      ));
  }

  @override
  Future<Res<List<Illust>>> loadData(page) {
    return widget.type == 0
        ? Network().getRecommendedIllusts()
        : Network().getRecommendedMangas();
  }
}

class _RecommendationUsersPage extends StatefulWidget {
  const _RecommendationUsersPage({super.key});

  @override
  State<_RecommendationUsersPage> createState() =>
      _RecommendationUsersPageState();
}

class _RecommendationUsersPageState
    extends MultiPageLoadingState<_RecommendationUsersPage, UserPreview> {
  @override
  Widget buildContent(BuildContext context, List<UserPreview> data) {
    return withRefresh(CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverGridViewWithFixedItemHeight(
          delegate: SliverChildBuilderDelegate((context, index) {
            if (index == data.length - 1) {
              nextPage();
            }
            return UserPreviewWidget(data[index]);
          }, childCount: data.length),
          minCrossAxisExtent: 440,
          itemHeight: 136,
        ).sliverPaddingHorizontal(8)
      ],
    ));
  }

  @override
  Future<Res<List<UserPreview>>> loadData(page) async {
    var res = await Network().getRecommendationUsers();
    return res;
  }
}
