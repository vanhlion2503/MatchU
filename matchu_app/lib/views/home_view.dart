import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:matchu_app/views/feed/feed_screen.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key, this.bottomNavigationVisibility});

  final ValueNotifier<bool>? bottomNavigationVisibility;

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  static const double _toggleScrollThreshold = 24;

  late final ValueNotifier<bool> _fallbackBottomNavigationVisibility =
      ValueNotifier<bool>(true);
  ScrollDirection _lastScrollDirection = ScrollDirection.idle;
  double _scrollDeltaSinceLastToggle = 0;

  ValueNotifier<bool> get _bottomNavigationVisibility =>
      widget.bottomNavigationVisibility ?? _fallbackBottomNavigationVisibility;

  @override
  void dispose() {
    _fallbackBottomNavigationVisibility.dispose();
    super.dispose();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    // Feed list is wrapped by widgets like RefreshIndicator/TabBarView,
    // so scroll notifications can arrive with depth > 0.
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }

    if (notification.metrics.pixels <= 0) {
      _lastScrollDirection = ScrollDirection.idle;
      _scrollDeltaSinceLastToggle = 0;
      _updateBottomNavigationVisibility(true);
      return false;
    }

    if (notification is! ScrollUpdateNotification) {
      return false;
    }

    final delta = notification.scrollDelta;
    if (delta == null || delta == 0) return false;

    final direction =
        delta > 0 ? ScrollDirection.reverse : ScrollDirection.forward;

    if (_lastScrollDirection != direction) {
      _lastScrollDirection = direction;
      _scrollDeltaSinceLastToggle = 0;
    }

    _scrollDeltaSinceLastToggle += delta.abs();

    if (_scrollDeltaSinceLastToggle < _toggleScrollThreshold) {
      return false;
    }

    _scrollDeltaSinceLastToggle = 0;

    switch (direction) {
      case ScrollDirection.forward:
        _updateBottomNavigationVisibility(true);
        break;
      case ScrollDirection.reverse:
        _updateBottomNavigationVisibility(false);
        break;
      case ScrollDirection.idle:
        break;
    }

    return false;
  }

  void _updateBottomNavigationVisibility(bool isVisible) {
    if (_bottomNavigationVisibility.value == isVisible) return;

    _bottomNavigationVisibility.value = isVisible;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: FeedScreen(
        bottomNavigationVisibility: _bottomNavigationVisibility,
      ),
    );
  }
}
