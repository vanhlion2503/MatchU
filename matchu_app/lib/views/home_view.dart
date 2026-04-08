import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:matchu_app/views/feed/feed_screen.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key, this.onBottomNavigationVisibilityChanged});

  final ValueChanged<bool>? onBottomNavigationVisibilityChanged;

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  static const double _toggleScrollThreshold = 24;

  bool _isBottomNavigationVisible = true;
  ScrollDirection _lastScrollDirection = ScrollDirection.idle;
  double _scrollDeltaSinceLastToggle = 0;

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
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
    if (_isBottomNavigationVisible == isVisible) return;

    _isBottomNavigationVisible = isVisible;
    widget.onBottomNavigationVisibilityChanged?.call(isVisible);
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: const FeedScreen(),
    );
  }
}
