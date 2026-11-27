import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

/// Pull-to-refresh / load-more wrapper that owns **one** [RefreshController]
/// per widget instance.
///
/// Reuse this for any list that needs `SmartRefresher`. Do **not** store a
/// single [RefreshController] on a GetX controller and pass it into
/// [SmartRefresher] — `pull_to_refresh` asserts if that controller is bound to
/// more than one refresher (`_refresherState == null`). That shows up in host
/// apps that put chat inside a [TabBarView] / [IndexedStack] / bottom nav
/// (the SDK example does not, so it never hits the race).
///
/// [child] must be a [ScrollView] (e.g. [ListView]), not [GetX]/[GetBuilder].
/// Put reactive builders **above** this widget and pass a fresh [ListView] when
/// data changes. Wrapping the list in another widget makes [SmartRefresher] nest
/// scrollables and pull-to-refresh will not fire.
class IsmChatPullToRefresh extends StatefulWidget {
  const IsmChatPullToRefresh({
    super.key,
    required this.child,
    this.onRefresh,
    this.onLoading,
    this.enablePullDown = true,
    this.enablePullUp = true,
    this.header,
    this.footer,
    this.physics = const ClampingScrollPhysics(),
  });

  final Widget child;
  final Future<void> Function()? onRefresh;

  /// Return `true` when the server sent no more items (footer shows no-more).
  final Future<bool> Function()? onLoading;
  final bool enablePullDown;
  final bool enablePullUp;
  final Widget? header;
  final Widget? footer;
  final ScrollPhysics physics;

  @override
  State<IsmChatPullToRefresh> createState() => _IsmChatPullToRefreshState();
}

class _IsmChatPullToRefreshState extends State<IsmChatPullToRefresh> {
  late final RefreshController _refreshController;

  @override
  void initState() {
    super.initState();
    _refreshController = RefreshController(
      initialRefresh: false,
      initialLoadStatus: LoadStatus.idle,
    );
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    try {
      await widget.onRefresh?.call();
      if (mounted) {
        _refreshController.refreshCompleted(resetFooterState: true);
      }
    } catch (_) {
      if (mounted) {
        _refreshController.refreshFailed();
      }
    }
  }

  Future<void> _onLoading() async {
    try {
      final noMore = await widget.onLoading?.call() ?? false;
      if (!mounted) {
        return;
      }
      if (noMore) {
        _refreshController.loadNoData();
      } else {
        _refreshController.loadComplete();
      }
    } catch (_) {
      if (mounted) {
        _refreshController.loadFailed();
      }
    }
  }

  @override
  Widget build(BuildContext context) => SmartRefresher(
        physics: widget.physics,
        controller: _refreshController,
        enablePullDown: widget.enablePullDown,
        enablePullUp: widget.enablePullUp,
        header: widget.header,
        footer: widget.footer,
        onRefresh: widget.onRefresh != null ? _onRefresh : null,
        onLoading: widget.onLoading != null ? _onLoading : null,
        child: widget.child,
      );
}

/// Height reserved by [RefreshHeader] / [RefreshFooter].
///
/// Must match the `height` passed to [CustomHeader] / [CustomFooter]. Every
/// indicator state renders a box of exactly this height so the sliver never
/// resizes between idle → loading → complete. A size change there is what made
/// the last conversation "jump" up with the loader on load-more, and the header
/// spinner stretch/pop on pull-to-refresh.
const double _kIndicatorHeight = 60;

class RefreshHeader extends StatelessWidget {
  const RefreshHeader({super.key});

  @override
  Widget build(BuildContext context) => CustomHeader(
        height: _kIndicatorHeight,
        completeDuration: const Duration(milliseconds: 300),
        builder: (_, mode) {
          switch (mode) {
            case RefreshStatus.completed:
            case RefreshStatus.failed:
              // Spring back with an empty (same-size) box instead of a
              // spinner that keeps spinning while the list settles.
              return const SizedBox(height: _kIndicatorHeight);
            default:
              return const _SmartRefreshDialog();
          }
        },
      );
}

class RefreshFooter extends StatelessWidget {
  const RefreshFooter({super.key});

  @override
  Widget build(BuildContext context) => CustomFooter(
        height: _kIndicatorHeight,
        builder: (_, mode) {
          switch (mode) {
            case LoadStatus.loading:
              return const _SmartRefreshDialog();
            case LoadStatus.failed:
              return SizedBox(
                height: _kIndicatorHeight,
                child: Center(
                  child: Text(
                    'Load failed',
                    style: IsmChatStyles.w400Grey14,
                  ),
                ),
              );
            case LoadStatus.noMore:
              // Don't show a "No more data" label at the end of the list.
              // Host apps can still provide a custom footer if they want one.
              return IsmChatProperties.conversationProperties.refreshFooter ??
                  const SizedBox(height: _kIndicatorHeight);
            case LoadStatus.idle:
            case LoadStatus.canLoading:
            default:
              // Same height as the loading state so the list doesn't shift
              // when the spinner appears. Short lists don't get extra blank
              // space because the refresher sets `hideFooterWhenNotFull`.
              return const SizedBox(height: _kIndicatorHeight);
          }
        },
      );
}

class _SmartRefreshDialog extends StatelessWidget {
  const _SmartRefreshDialog();

  @override
  Widget build(BuildContext context) => StatusBarTransparent(
        child: SizedBox(
          height: _kIndicatorHeight,
          child: Center(
            child: IsmChatProperties.conversationProperties.refreshHeader ??
                SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator.adaptive(
                    strokeWidth: 2.5,
                    backgroundColor: IsmChatConfig.chatTheme.primaryColor,
                  ),
                ),
          ),
        ),
      );
}
