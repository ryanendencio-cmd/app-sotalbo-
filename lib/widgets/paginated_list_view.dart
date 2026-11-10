import 'package:flutter/material.dart';

class PaginatedListView extends StatefulWidget {
  const PaginatedListView.builder({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding,
    this.physics,
    this.shrinkWrap = false,
    this.reverse = false,
    this.scrollDirection = Axis.vertical,
    this.leadingItemCount = 0,
    this.pageSize = 20,
  }) : separatorBuilder = null;

  const PaginatedListView.separated({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.separatorBuilder,
    this.padding,
    this.physics,
    this.shrinkWrap = false,
    this.reverse = false,
    this.scrollDirection = Axis.vertical,
    this.leadingItemCount = 0,
    this.pageSize = 20,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final IndexedWidgetBuilder? separatorBuilder;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final bool reverse;
  final Axis scrollDirection;
  final int leadingItemCount;
  final int pageSize;

  @override
  State<PaginatedListView> createState() => _PaginatedListViewState();
}

class _PaginatedListViewState extends State<PaginatedListView> {
  static const _controlHeight = 56.0;
  late final ScrollController _scrollController;
  int _pageIndex = 0;

  int get _leadingCount =>
      widget.leadingItemCount.clamp(0, widget.itemCount).toInt();

  int get _recordCount => widget.itemCount - _leadingCount;

  int get _pageCount => (_recordCount / widget.pageSize).ceil();

  bool get _hasPagination => _pageCount > 1;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void didUpdateWidget(covariant PaginatedListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemCount != widget.itemCount ||
        oldWidget.leadingItemCount != widget.leadingItemCount) {
      _pageIndex = _pageIndex
          .clamp(0, (_pageCount - 1).clamp(0, _pageCount))
          .toInt();
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    if (page < 0 || page >= _pageCount || page == _pageIndex) return;
    setState(() => _pageIndex = page);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleCount = _hasPagination
        ? (_recordCount - _pageIndex * widget.pageSize)
              .clamp(0, widget.pageSize)
              .toInt()
        : _recordCount;
    final renderedCount =
        _leadingCount + visibleCount + (_hasPagination ? 1 : 0);

    Widget buildItem(BuildContext context, int localIndex) {
      if (_hasPagination && localIndex == _leadingCount + visibleCount) {
        return _buildControls(context);
      }
      if (localIndex < _leadingCount) {
        return widget.itemBuilder(context, localIndex);
      }
      final recordIndex =
          localIndex -
          _leadingCount +
          (_hasPagination ? _pageIndex * widget.pageSize : 0);
      return widget.itemBuilder(context, _leadingCount + recordIndex);
    }

    if (widget.separatorBuilder == null) {
      return ListView.builder(
        controller: _scrollController,
        padding: widget.padding,
        physics: widget.physics,
        shrinkWrap: widget.shrinkWrap,
        reverse: widget.reverse,
        scrollDirection: widget.scrollDirection,
        itemCount: renderedCount,
        itemBuilder: buildItem,
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: widget.padding,
      physics: widget.physics,
      shrinkWrap: widget.shrinkWrap,
      reverse: widget.reverse,
      scrollDirection: widget.scrollDirection,
      itemCount: renderedCount,
      separatorBuilder: (context, localIndex) {
        if (_hasPagination && localIndex == _leadingCount + visibleCount - 1) {
          return const SizedBox(height: 8);
        }
        final sourceIndex = localIndex < _leadingCount
            ? localIndex
            : _leadingCount +
                  localIndex -
                  _leadingCount +
                  (_hasPagination ? _pageIndex * widget.pageSize : 0);
        return widget.separatorBuilder!(context, sourceIndex);
      },
      itemBuilder: buildItem,
    );
  }

  Widget _buildControls(BuildContext context) {
    final first = _pageIndex * widget.pageSize + 1;
    final last = (first + widget.pageSize - 1).clamp(0, _recordCount);
    final theme = Theme.of(context);
    return SizedBox(
      height: _controlHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Previous page',
            onPressed: _pageIndex == 0 ? null : () => _goToPage(_pageIndex - 1),
            icon: const Icon(Icons.chevron_left_rounded),
            visualDensity: VisualDensity.compact,
          ),
          Flexible(
            child: Text(
              '$first–$last of $_recordCount  •  ${_pageIndex + 1} of $_pageCount',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next page',
            onPressed: _pageIndex >= _pageCount - 1
                ? null
                : () => _goToPage(_pageIndex + 1),
            icon: const Icon(Icons.chevron_right_rounded),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
