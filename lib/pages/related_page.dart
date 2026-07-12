import 'package:fluent_ui/fluent_ui.dart' hide TitleBar;
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:pixes/components/illust_widget.dart';
import 'package:pixes/components/loading.dart';
import 'package:pixes/components/title_bar.dart';
import 'package:pixes/foundation/app.dart';
import 'package:pixes/network/network.dart';
import 'package:pixes/utils/translation.dart';

class RelatedIllustsPage extends StatefulWidget {
  const RelatedIllustsPage(this.id, {super.key});

  final String id;

  @override
  State<RelatedIllustsPage> createState() => _RelatedIllustsPageState();
}

class _RelatedIllustsPageState
    extends MultiPageLoadingState<RelatedIllustsPage, Illust> {
  @override
  Future<void> refresh() {
    nextUrl = null;
    return super.refresh();
  }

  @override
  Widget? buildFrame(BuildContext context, Widget child) {
    return Column(
      children: [
        TitleBar(
          title: "Related artworks".tl,
          onRefresh: refresh,
        ),
        Expanded(
          child: child,
        )
      ],
    );
  }

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
          return IllustWidget(data[index]);
        },
      ));
  }

  String? nextUrl;

  @override
  Future<Res<List<Illust>>> loadData(page) async {
    if (nextUrl == "end") {
      return Res.error("No more data");
    }
    var res = nextUrl == null
        ? await Network().relatedIllusts(widget.id)
        : await Network().getIllustsWithNextUrl(nextUrl!);
    if (!res.error) {
      nextUrl = res.subData;
      nextUrl ??= "end";
    }
    return res;
  }
}
