import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// The built-in, themeable "Manage Storage" screen (WhatsApp/Teams style).
///
/// Shows the user's storage usage and their charged media, with multi-select
/// delete and "delete all in this conversation". Everything is driven by
/// [IsmChatStorageQuotaController]; host apps can push this screen with
/// [IsmChat.openStorageManagement] or embed/restyle it as needed.
///
/// Customize copy and empty UI via [IsmChatProperties.storageManagementProperties]
/// and typography via [IsmChatThemeData.storageTheme].
///
/// Pass [conversationId] to open scoped to a single conversation.
class IsmChatStorageView extends StatefulWidget {
  const IsmChatStorageView({this.conversationId, super.key});

  /// When set, the list opens scoped to this conversation and exposes the
  /// "delete all in this conversation" action.
  final String? conversationId;

  @override
  State<IsmChatStorageView> createState() => _IsmChatStorageViewState();
}

class _IsmChatStorageViewState extends State<IsmChatStorageView> {
  final _scrollController = ScrollController();
  late final IsmChatStorageQuotaController _controller;

  IsmChatStorageManagementProperties get _props =>
      IsmChatProperties.storageManagementProperties;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<IsmChatStorageQuotaController>()) {
      IsmChatStorageQuotaBinding().dependencies();
    }
    _controller = Get.find<IsmChatStorageQuotaController>();
    // Scope (if asked) then load usage + first page.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _controller.clearSelection();
      if (widget.conversationId != null &&
          widget.conversationId!.isNotEmpty) {
        await _controller.setConversationFilter(widget.conversationId);
        await _controller.loadUsage();
      } else {
        await _controller.initialize();
      }
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 240) {
      _controller.loadMore();
    }
  }

  Color _primary(BuildContext context) =>
      IsmChatConfig.chatTheme.primaryColor ?? IsmChatColors.primaryColorLight;

  Color get _headerIconColor =>
      IsmChatConfig.chatTheme.chatPageHeaderTheme?.iconColor ??
      IsmChatColors.whiteColor;

  TextStyle get _headerTitleStyle =>
      IsmChatConfig.chatTheme.chatPageHeaderTheme?.titleStyle ??
      IsmChatStyles.w600White18;

  Widget _appBarIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    String? tooltip,
  }) =>
      IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: _headerIconColor),
      );

  @override
  Widget build(BuildContext context) {
    final theme = IsmChatThemeResolver.storageFromConfig(context);
    return Obx(
      () {
        final selectionMode = _controller.isSelectionMode;
        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: _appBar(context, selectionMode),
          body: Column(
            children: [
              IsmChatStorageUsageHeader(
                usage: _controller.usage,
                isLoading: _controller.isLoadingUsage,
              ),
              if (widget.conversationId != null &&
                  widget.conversationId!.isNotEmpty)
                _conversationActions(context, theme),
              _toolbar(context, theme),
              Expanded(child: _mediaList(context, theme)),
            ],
          ),
          bottomNavigationBar:
              selectionMode ? _selectionBar(context, theme) : null,
        );
      },
    );
  }

  PreferredSizeWidget _appBar(BuildContext context, bool selectionMode) {
    if (selectionMode) {
      return IsmChatAppBar(
        leading: _appBarIconButton(
          icon: _props.closeIcon ?? Icons.close,
          onPressed: _controller.clearSelection,
        ),
        title: Text(
          _props.resolveSelectionTitle(
            context,
            _controller.selectedMediaIds.length,
          ),
          style: _headerTitleStyle,
        ),
        action: [
          _appBarIconButton(
            icon: _props.selectAllIcon ?? Icons.done_all,
            tooltip: _props.resolveSelectAllTooltip(),
            onPressed: _controller.selectAllVisible,
          ),
        ],
      );
    }
    final sortBySize = _controller.sortBySizeDesc;
    return IsmChatAppBar(
      title: Text(
        _props.resolveTitle(),
        style: _headerTitleStyle,
      ),
      action: [
        _appBarIconButton(
          icon: sortBySize
              ? (_props.sortByDateIcon ?? Icons.schedule)
              : (_props.sortIcon ?? Icons.sort),
          tooltip: sortBySize
              ? _props.resolveSortNewestFirstTooltip()
              : _props.resolveSortLargestFirstTooltip(),
          onPressed: _controller.toggleSortBySize,
        ),
      ],
    );
  }

  Widget _conversationActions(
    BuildContext context,
    IsmChatStorageTheme theme,
  ) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _props.resolveConversationScopeLabel(),
                style: theme.scopeHintStyle,
              ),
            ),
            TextButton.icon(
              onPressed: () => _controller.confirmDeleteAllInConversation(
                context,
                widget.conversationId!,
              ),
              icon: const Icon(Icons.delete_sweep_outlined, size: 18),
              style: TextButton.styleFrom(
                foregroundColor: IsmChatColors.redColor,
              ),
              label: Text(_props.resolveDeleteAllLabel()),
            ),
          ],
        ),
      );

  Widget _toolbar(BuildContext context, IsmChatStorageTheme theme) {
    // Build a simple set of type filters from what is loaded.
    final types = <IsmChatMediaType>{
      for (final m in _controller.media) m.attachmentType,
    }.toList();
    if (types.isEmpty && _controller.typeFilter == null) {
      return const SizedBox(height: 4);
    }
    final primary = _primary(context);
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _filterChip(
            context,
            theme,
            primary,
            _props.resolveFilterAllLabel(),
            _controller.typeFilter == null,
            () => _controller.setTypeFilter(null),
          ),
          for (final t in types)
            _filterChip(
              context,
              theme,
              primary,
              _props.resolveTypeLabel(t),
              _controller.typeFilter == t,
              () => _controller.setTypeFilter(t),
            ),
        ],
      ),
    );
  }

  Widget _filterChip(
    BuildContext context,
    IsmChatStorageTheme theme,
    Color primary,
    String label,
    bool selected,
    VoidCallback onTap,
  ) =>
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          selectedColor: primary.withValues(alpha: 0.15),
          labelStyle: theme.filterChipLabelStyle.copyWith(
            color: selected ? primary : theme.filterChipLabelStyle.color,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
          showCheckmark: false,
        ),
      );

  Widget _mediaList(BuildContext context, IsmChatStorageTheme theme) {
    final items = _controller.visibleMedia;
    if (_controller.isLoadingMedia && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return _emptyState(context, theme);
    }
    return RefreshIndicator(
      onRefresh: _controller.reloadAll,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: items.length + (_controller.isPaginating ? 1 : 0),
        separatorBuilder: (_, __) => Divider(
          height: 1,
          thickness: 0.4,
          indent: 74,
          color: theme.dividerColor,
        ),
        itemBuilder: (_, index) {
          if (index >= items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final media = items[index];
          return IsmChatStorageMediaTile(
            media: media,
            selectionMode: _controller.isSelectionMode,
            selected: _controller.isSelected(media.mediaId),
            onTap: () => _controller.toggleSelection(media.mediaId),
            onLongPress: () => _controller.enterSelectionMode(media.mediaId),
          );
        },
      ),
    );
  }

  Widget _emptyState(BuildContext context, IsmChatStorageTheme theme) {
    final placeholder = _props.emptyPlaceholder;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (placeholder != null)
          placeholder
        else ...[
          SizedBox(height: IsmChatDimens.percentHeight(0.1)),
          Icon(
            _props.emptyIcon ?? Icons.folder_open_outlined,
            size: 64,
            color: theme.emptyIconColor,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _props.resolveEmptyTitle(quotaEnabled: _controller.quotaEnabled),
              style: _props.emptyTitleStyle ?? theme.emptyTextStyle,
            ),
          ),
        ],
      ],
    );
  }

  Widget _selectionBar(BuildContext context, IsmChatStorageTheme theme) {
    final count = _controller.selectedMediaIds.length;
    final bytes = _controller.selectedBytes;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                bytes > 0
                    ? '$count selected · ${IsmChatUtility.formatBytesDecimal(bytes)}'
                    : '$count selected',
                style: theme.selectionSummaryStyle,
              ),
            ),
            ElevatedButton.icon(
              onPressed: count == 0
                  ? null
                  : () => _controller.confirmDeleteSelected(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.deleteButtonBackgroundColor,
                foregroundColor: theme.deleteButtonForegroundColor,
              ),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text(
                _props.resolveDeleteSelectedLabel(),
                style: theme.deleteButtonTextStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
