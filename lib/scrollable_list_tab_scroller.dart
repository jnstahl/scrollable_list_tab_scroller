import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:scrolls_to_top/scrolls_to_top.dart';
export 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

part "header_container_props.dart";
part "tab_bar_props.dart";
part "body_container_props.dart";

typedef IndexedActiveStatusWidgetBuilder = Widget Function(
    BuildContext context, int index, bool active);
typedef IndexedVoidCallback = void Function(int index);

typedef HeaderContainerBuilder = Widget Function(
    BuildContext context, Widget child);
typedef BodyContainerBuilder = Widget Function(
    BuildContext context, Widget child);

class ScrollableListTabScroller extends StatefulWidget {
  ScrollableListTabScroller({
    required this.tabIndices,
    required this.itemToTab,
    required this.subItemCount,
    required this.itemBuilder,
    required this.tabBuilder,
    this.headerContainerBuilder,
    @Deprecated(
        "This code is unused and will be removed in the next release. Deprecated since >3.0.1")
    Widget Function(BuildContext context, Widget child)? headerWidgetBuilder,
    this.bodyContainerBuilder,
    this.itemScrollController,
    this.itemPositionsListener,
    this.tabChanged,
    this.earlyChangePositionOffset = 0,
    this.animationDuration = const Duration(milliseconds: 300),
    this.shrinkWrap = false,
    this.initialScrollIndex = 0,
    this.initialAlignment = 0,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.physics,
    this.semanticChildCount,
    this.padding,
    this.addSemanticIndexes = true,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.minCacheExtent,
    this.scrollOffsetController,
    this.scrollOffsetListener,
    @Deprecated(
        "Use 'ScrollableListTabScroller.defaultComponents(tabBarProps: )' instead. Deprecated since >3.0.1")
    TabAlignment? tabAlignment = TabAlignment.start,
  })  : tabBarProps = TabBarProps(tabAlignment: tabAlignment),
        headerContainerProps = HeaderContainerProps();

  const ScrollableListTabScroller.defaultComponents({
    this.headerContainerProps = const HeaderContainerProps(),
    this.tabBarProps = const TabBarProps(),
    required this.tabIndices,
    required this.itemToTab,
    required this.subItemCount,
    required this.itemBuilder,
    required this.tabBuilder,
    this.bodyContainerBuilder,
    this.itemScrollController,
    this.itemPositionsListener,
    this.tabChanged,
    this.earlyChangePositionOffset = 0,
    this.animationDuration = const Duration(milliseconds: 300),
    this.shrinkWrap = false,
    this.initialScrollIndex = 0,
    this.initialAlignment = 0,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.physics,
    this.semanticChildCount,
    this.padding,
    this.addSemanticIndexes = true,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.minCacheExtent,
    this.scrollOffsetController,
    this.scrollOffsetListener,
  }) : headerContainerBuilder = null;

  final List<int> tabIndices;
  final Map<int, int> itemToTab;
  final int subItemCount;
  final IndexedWidgetBuilder itemBuilder;
  final IndexedActiveStatusWidgetBuilder tabBuilder;
  final HeaderContainerBuilder? headerContainerBuilder;
  final BodyContainerBuilder? bodyContainerBuilder;
  final ItemScrollController? itemScrollController;
  final ItemPositionsListener? itemPositionsListener;
  final void Function(int tabIndex)? tabChanged;
  final double earlyChangePositionOffset;
  final Duration animationDuration;

  final HeaderContainerProps headerContainerProps;
  final TabBarProps tabBarProps;

  final ScrollOffsetController? scrollOffsetController;

  final ScrollOffsetListener? scrollOffsetListener;

  /// Index of an item to initially align within the viewport.
  final int initialScrollIndex;

  /// Determines where the leading edge of the item at [initialScrollIndex]
  /// should be placed.
  ///
  /// See [ItemScrollController.jumpTo] for an explanation of alignment.
  final double initialAlignment;

  /// The axis along which the scroll view scrolls.
  ///
  /// Defaults to [Axis.vertical].
  final Axis scrollDirection;

  /// Whether the view scrolls in the reading direction.
  ///
  /// Defaults to false.
  ///
  /// See [ScrollView.reverse].
  final bool reverse;

  /// Whether the extent of the scroll view in the [scrollDirection] should be
  /// determined by the contents being viewed.
  ///
  ///  Defaults to false.
  ///
  /// See [ScrollView.shrinkWrap].
  final bool shrinkWrap;

  /// How the scroll view should respond to user input.
  ///
  /// For example, determines how the scroll view continues to animate after the
  /// user stops dragging the scroll view.
  ///
  /// See [ScrollView.physics].
  final ScrollPhysics? physics;

  /// The number of children that will contribute semantic information.
  ///
  /// See [ScrollView.semanticChildCount] for more information.
  final int? semanticChildCount;

  /// The amount of space by which to inset the children.
  final EdgeInsets? padding;

  /// Whether to wrap each child in an [IndexedSemantics].
  ///
  /// See [SliverChildBuilderDelegate.addSemanticIndexes].
  final bool addSemanticIndexes;

  /// Whether to wrap each child in an [AutomaticKeepAlive].
  ///
  /// See [SliverChildBuilderDelegate.addAutomaticKeepAlives].
  final bool addAutomaticKeepAlives;

  /// Whether to wrap each child in a [RepaintBoundary].
  ///
  /// See [SliverChildBuilderDelegate.addRepaintBoundaries].
  final bool addRepaintBoundaries;

  /// The minimum cache extent used by the underlying scroll lists.
  /// See [ScrollView.cacheExtent].
  ///
  /// Note that the [ScrollablePositionedList] uses two lists to simulate long
  /// scrolls, so using the [ScrollController.scrollTo] method may result
  /// in builds of widgets that would otherwise already be built in the
  /// cache extent.
  final double? minCacheExtent;

  @override
  ScrollableListTabScrollerState createState() =>
      ScrollableListTabScrollerState();
}

class ScrollableListTabScrollerState extends State<ScrollableListTabScroller> {
  late final ItemScrollController itemScrollController;
  late final ItemPositionsListener itemPositionsListener;
  final _selectedTabIndex = ValueNotifier(0);
  Timer? _debounce;
  Size _currentPositionedListSize = Size.zero;

  @override
  void initState() {
    super.initState();
    // try to use user controllers or create them
    itemScrollController =
        widget.itemScrollController ?? ItemScrollController();
    itemPositionsListener =
        widget.itemPositionsListener ?? ItemPositionsListener.create();

    itemPositionsListener.itemPositions.addListener(_itemPositionListener);

    _selectedTabIndex.addListener(onSelectedTabChange);
  }

  void onSelectedTabChange() {
    final selectedTabIndex = _selectedTabIndex.value;
    final debounce = _debounce;

    if (debounce != null && debounce.isActive) {
      debounce.cancel();
    }

    _debounce = Timer(widget.animationDuration, () {
      widget.tabChanged?.call(selectedTabIndex);
    });
  }

  void _triggerScrollInPositionedListIfNeeded(int index) {
    if (getDisplayedPositionFromList() != index &&
        // Prevent operation when length == 0 (Component was rendered outside screen)
        itemPositionsListener.itemPositions.value.isNotEmpty) {
      // disableItemPositionListener = true;
      if (itemScrollController.isAttached) {
        itemScrollController.scrollTo(
            index: index, duration: widget.animationDuration);
      }
    }
  }

  void setCurrentActiveIfDifferent(int currentActive) {
    if (_selectedTabIndex.value != currentActive) {
      _selectedTabIndex.value = currentActive;
    }
  }

  void _itemPositionListener() {
    // Prevent operation when length == 0 (Component was rendered outside screen)
    if (itemPositionsListener.itemPositions.value.isEmpty) {
      return;
    }
    final displayedIdx = getDisplayedPositionFromList();
    if (displayedIdx != null) {
      setCurrentActiveIfDifferent(displayedIdx);
    }
  }

  int? getDisplayedPositionFromList() {
    final value = itemPositionsListener.itemPositions.value;
    if (value.isEmpty) {
      return null;
    }
    final orderedListByPositionIndex = value.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    final renderedMostTopItem = orderedListByPositionIndex.first;

    if (orderedListByPositionIndex.length > 1 &&
        orderedListByPositionIndex.last.index == widget.subItemCount - 1) {
      // I dont know why it's not perfectly 1.0
      // 1.01 LGTM
      const fullBottomEdge = 1.01;
      if (orderedListByPositionIndex.last.itemTrailingEdge < fullBottomEdge) {
        return orderedListByPositionIndex.last.index;
      }
    }
    if (renderedMostTopItem.getBottomOffset(_currentPositionedListSize) <
        widget.earlyChangePositionOffset) {
      if (orderedListByPositionIndex.length > 1) {
        return orderedListByPositionIndex[1].index;
      }
    }
    return renderedMostTopItem.index;
  }

  Widget buildCustomHeaderContainerOrDefault(
      {required BuildContext context, required Widget child}) {
    return widget.headerContainerBuilder?.call(context, child) ??
        SizedBox(
          width: widget.headerContainerProps.width,
          height: widget.headerContainerProps.height,
          child: child,
        );
  }

  Widget buildCustomBodyContainerOrDefault(
      {required BuildContext context, required Widget child}) {
    return widget.bodyContainerBuilder?.call(context, child) ??
        Expanded(
          child: child,
        );
  }

  Future<void> _onScrollsToTop(ScrollsToTopEvent event) async {
    itemScrollController.scrollTo(
        index: 0, duration: event.duration, curve: event.curve);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        buildCustomHeaderContainerOrDefault(
          context: context,
          child: DefaultHeaderWidget(
            key: Key(widget.tabIndices.length.toString()),
            itemCount: widget.tabIndices.length,
            onTapTab: (i) => _triggerScrollInPositionedListIfNeeded(i),
            //TODO: implement callback to handle tab click ,
            selectedTabIndex: _selectedTabIndex,
            tabBuilder: widget.tabBuilder,
            tabBarProps: widget.tabBarProps,
          ),
        ),
        buildCustomBodyContainerOrDefault(
          context: context,
          child: Builder(builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
              final size = context.size;
              if (size != null) {
                _currentPositionedListSize = size;
              }
            });
            return ScrollsToTop(
              onScrollsToTop: _onScrollsToTop,
              child: ScrollablePositionedList.builder(
                itemBuilder: (a, b) {
                  return widget.itemBuilder(a, b);
                },
                itemCount: widget.subItemCount,
                itemScrollController: itemScrollController,
                itemPositionsListener: itemPositionsListener,
                shrinkWrap: widget.shrinkWrap,
                initialScrollIndex: widget.initialScrollIndex,
                initialAlignment: widget.initialAlignment,
                scrollDirection: widget.scrollDirection,
                reverse: widget.reverse,
                physics: widget.physics,
                semanticChildCount: widget.semanticChildCount,
                padding: widget.padding,
                addSemanticIndexes: widget.addSemanticIndexes,
                addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
                addRepaintBoundaries: widget.addRepaintBoundaries,
                minCacheExtent: widget.minCacheExtent,
                scrollOffsetController: widget.scrollOffsetController,
                scrollOffsetListener: widget.scrollOffsetListener,
              ),
            );
          }),
        )
      ],
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    itemPositionsListener.itemPositions.removeListener(_itemPositionListener);
    super.dispose();
  }
}

class DefaultHeaderWidget extends StatefulWidget {
  final ValueNotifier<int> selectedTabIndex;
  final IndexedActiveStatusWidgetBuilder tabBuilder;
  final IndexedVoidCallback onTapTab;
  final int itemCount;
  final TabBarProps tabBarProps;

  DefaultHeaderWidget({
    Key? key,
    required this.selectedTabIndex,
    required this.tabBuilder,
    required this.onTapTab,
    required this.itemCount,
    @Deprecated("Use 'tabBarProps' instead. Deprecated since >3.0.1")
    TabAlignment? tabAlignment,
    TabBarProps? tabBarProps,
  })  : assert(tabAlignment == null || tabBarProps == null,
            "Must use only 'tabBarProps'"),
        tabBarProps = tabAlignment != null
            ? TabBarProps(tabAlignment: tabAlignment)
            : tabBarProps ?? const TabBarProps(),
        super(key: key);

  @override
  State<DefaultHeaderWidget> createState() => _DefaultHeaderWidgetState();
}

class _DefaultHeaderWidgetState extends State<DefaultHeaderWidget>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      initialIndex: widget.selectedTabIndex.value,
      length: widget.itemCount,
      vsync: this,
    );
    _tabController.addListener(tabChangeListener);
    widget.selectedTabIndex.addListener(externalTabChangeListener);
  }

  @override
  void dispose() {
    _tabController.dispose();
    widget.selectedTabIndex.removeListener(externalTabChangeListener);
    super.dispose();
  }

  void tabChangeListener() {
    widget.onTapTab(_tabController.index);
  }

  void externalTabChangeListener() {
    _tabController.index = widget.selectedTabIndex.value;
  }

  void _onTapTab(_) {
    _tabController.index = widget.selectedTabIndex.value;
  }

  @override
  Widget build(BuildContext context) {
    final defaultTextStyle = DefaultTextStyle.of(context);
    final tabList = List.generate(
      widget.itemCount,
      (i) => ValueListenableBuilder(
        valueListenable: widget.selectedTabIndex,
        builder: (context, selectedIndex, child) =>
            widget.tabBuilder(context, i, i == selectedIndex),
      ),
    );
    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: TabBar(
        controller: _tabController,
        onTap: _onTapTab,
        tabs: tabList,
        isScrollable: widget.tabBarProps.isScrollable,
        padding: widget.tabBarProps.padding,
        indicatorColor: widget.tabBarProps.indicatorColor,
        automaticIndicatorColorAdjustment:
            widget.tabBarProps.automaticIndicatorColorAdjustment,
        indicatorWeight: widget.tabBarProps.indicatorWeight,
        indicatorPadding: widget.tabBarProps.indicatorPadding,
        indicator: widget.tabBarProps.indicator,
        indicatorSize: widget.tabBarProps.indicatorSize,
        dividerColor: widget.tabBarProps.dividerColor,
        dividerHeight: widget.tabBarProps.dividerHeight,
        labelColor: widget.tabBarProps.labelColor is _DefaultTextStyleColor
            ? defaultTextStyle.style.color
            : widget.tabBarProps.labelColor,
        labelStyle: widget.tabBarProps.labelStyle,
        labelPadding: widget.tabBarProps.labelPadding,
        unselectedLabelColor: widget.tabBarProps.unselectedLabelColor,
        unselectedLabelStyle: widget.tabBarProps.unselectedLabelStyle,
        dragStartBehavior: widget.tabBarProps.dragStartBehavior,
        overlayColor: widget.tabBarProps.overlayColor,
        mouseCursor: widget.tabBarProps.mouseCursor,
        enableFeedback: widget.tabBarProps.enableFeedback,
        physics: widget.tabBarProps.physics,
        splashFactory: widget.tabBarProps.splashFactory,
        splashBorderRadius: widget.tabBarProps.splashBorderRadius,
        tabAlignment: widget.tabBarProps.tabAlignment,
      ),
    );
  }
}

// Utils

extension _ItemPositionUtilsExtension on ItemPosition {
  double getBottomOffset(Size size) {
    return itemTrailingEdge * size.height;
  }
}
