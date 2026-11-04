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

  Color get _primary =>
      IsmChatConfig.chatTheme.primaryColor ?? IsmChatColors.primaryColorLight;

  @override
  Widget build(BuildContext context) => Obx(
        () {
          final selectionMode = _controller.isSelectionMode;
          return Scaffold(
            appBar: _appBar(selectionMode),
            body: Column(
              children: [
                IsmChatStorageUsageHeader(
                  usage: _controller.usage,
                  isLoading: _controller.isLoadingUsage,
                ),
                if (widget.conversationId != null &&
                    widget.conversationId!.isNotEmpty)
                  _conversationActions(),
                _toolbar(),
                Expanded(child: _mediaList()),
              ],
            ),
            bottomNavigationBar:
                selectionMode ? _selectionBar(context) : null,
          );
        },
      );

  PreferredSizeWidget _appBar(bool selectionMode) {
    if (selectionMode) {
      return IsmChatAppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _controller.clearSelection,
        ),
        title: Text(
          '${_controller.selectedMediaIds.length} selected',
          style: IsmChatConfig.chatTheme.chatPageHeaderTheme?.titleStyle ??
              IsmChatStyles.w600White18,
        ),
        action: [
          IconButton(
            tooltip: 'Select all',
            icon: const Icon(Icons.done_all),
            onPressed: _controller.selectAllVisible,
          ),
        ],
      );
    }
    return IsmChatAppBar(
      title: Text(
        'Storage',
        style: IsmChatConfig.chatTheme.chatPageHeaderTheme?.titleStyle ??
            IsmChatStyles.w600White18,
      ),
      action: [
        IconButton(
          tooltip: _controller.sortBySizeDesc ? 'Newest first' : 'Largest first',
          icon: Icon(
            _controller.sortBySizeDesc
                ? Icons.schedule
                : Icons.sort,
          ),
          onPressed: _controller.toggleSortBySize,
        ),
      ],
    );
  }

  Widget _conversationActions() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Showing one conversation',
                style: TextStyle(
                  fontSize: 12.5,
                  color: IsmChatColors.greyColor,
                ),
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
              label: const Text('Delete all'),
            ),
          ],
        ),
      );

  Widget _toolbar() {
    // Build a simple set of type filters from what is loaded.
    final types = <IsmChatMediaType>{
      for (final m in _controller.media) m.attachmentType,
    }.toList();
    if (types.isEmpty && _controller.typeFilter == null) {
      return const SizedBox(height: 4);
    }
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _filterChip('All', _controller.typeFilter == null,
              () => _controller.setTypeFilter(null)),
          for (final t in types)
            _filterChip(
              _typeLabel(t),
              _controller.typeFilter == t,
              () => _controller.setTypeFilter(t),
            ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) =>
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          selectedColor: _primary.withValues(alpha: 0.15),
          labelStyle: TextStyle(
            fontSize: 12.5,
            color: selected ? _primary : null,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
          showCheckmark: false,
        ),
      );

  Widget _mediaList() {
    final items = _controller.visibleMedia;
    if (_controller.isLoadingMedia && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return _emptyState();
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
          color: IsmChatColors.greyColorLight.withValues(alpha: 0.4),
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

  Widget _emptyState() => ListView(
        // ListView so pull-to-refresh still works on an empty list.
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: IsmChatDimens.percentHeight(0.1)),
          const Icon(
            Icons.folder_open_outlined,
            size: 64,
            color: IsmChatColors.greyColorLight,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _controller.quotaEnabled
                  ? 'No media uses your storage yet'
                  : 'No media to show',
              style: const TextStyle(color: IsmChatColors.greyColor),
            ),
          ),
        ],
      );

  Widget _selectionBar(BuildContext context) {
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
                    ? '$count selected · ${IsmChatUtility.formatBytes(bytes)}'
                    : '$count selected',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            ElevatedButton.icon(
              onPressed: count == 0
                  ? null
                  : () => _controller.confirmDeleteSelected(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: IsmChatColors.redColor,
                foregroundColor: IsmChatColors.whiteColor,
              ),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(IsmChatMediaType type) {
    switch (type) {
      case IsmChatMediaType.image:
        return 'Images';
      case IsmChatMediaType.video:
        return 'Videos';
      case IsmChatMediaType.audio:
        return 'Audio';
      case IsmChatMediaType.file:
        return 'Documents';
      case IsmChatMediaType.gif:
        return 'GIFs';
      case IsmChatMediaType.sticker:
        return 'Stickers';
      case IsmChatMediaType.location:
        return 'Location';
      case IsmChatMediaType.adminMessage:
        return 'Files';
    }
  }
}
