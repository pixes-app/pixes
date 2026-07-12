import 'package:fluent_ui/fluent_ui.dart';
import 'package:pixes/foundation/app.dart';

class TitleBar extends StatelessWidget {
  const TitleBar(
      {required this.title, this.action, this.onRefresh, super.key});

  final String title;

  final Widget? action;

  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: Row(
        children: [
          Text(title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),),
          if (onRefresh != null) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: "Refresh",
              child: IconButton(
                icon: const Icon(FluentIcons.refresh, size: 16),
                onPressed: onRefresh,
              ),
            ),
          ],
          const Spacer(),
          if(action != null)
            action!
        ],
      ).paddingHorizontal(16).paddingVertical(8),
    );
  }
}

class SliverTitleBar extends StatelessWidget {
  const SliverTitleBar(
      {required this.title, this.action, this.onRefresh, super.key});

  final String title;

  final Widget? action;

  final VoidCallback? onRefresh;


  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SizedBox(
        child: Row(
          children: [
            Text(title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),),
            if (onRefresh != null) ...[
              const SizedBox(width: 8),
              Tooltip(
                message: "Refresh",
                child: IconButton(
                  icon: const Icon(FluentIcons.refresh, size: 16),
                  onPressed: onRefresh,
                ),
              ),
            ],
            const Spacer(),
            if(action != null)
              action!
          ],
        ).paddingHorizontal(16).paddingVertical(8),
      ),
    );
  }
}
