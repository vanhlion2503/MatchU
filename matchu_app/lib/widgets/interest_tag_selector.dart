import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/utils/interest_tags.dart';

class InterestTagSelector extends StatefulWidget {
  const InterestTagSelector({
    super.key,
    required this.controller,
    required this.selectedTags,
    required this.onAddTag,
    required this.onRemoveTag,
    this.enabled = true,
  });

  final TextEditingController controller;
  final List<String> selectedTags;
  final ValueChanged<String> onAddTag;
  final ValueChanged<String> onRemoveTag;
  final bool enabled;

  @override
  State<InterestTagSelector> createState() => _InterestTagSelectorState();
}

class _InterestTagSelectorState extends State<InterestTagSelector> {
  List<String> _suggestions = const [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleTextChanged);
    _query = widget.controller.text;
    _suggestions = InterestTags.search(_query, excluding: widget.selectedTags);
  }

  @override
  void didUpdateWidget(covariant InterestTagSelector oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleTextChanged);
      widget.controller.addListener(_handleTextChanged);
    }

    if (oldWidget.selectedTags != widget.selectedTags ||
        oldWidget.controller != widget.controller) {
      _refreshSuggestions();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedCount = widget.selectedTags.length;
    final hasQuery = _query.trim().isNotEmpty;
    final hasReachedLimit = selectedCount >= InterestTags.maxSelected;
    final shouldShowSuggestionArea =
        hasReachedLimit || hasQuery || _suggestions.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          enabled: widget.enabled && !hasReachedLimit,
          textInputAction: TextInputAction.done,
          onSubmitted: _submitFirstSuggestion,
          decoration: InputDecoration(
            labelText: 'Nhập sở thích',
            prefixIcon: const Icon(Iconsax.heart),
            suffixText: '$selectedCount/${InterestTags.maxSelected}',
          ),
        ),
        if (widget.selectedTags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.selectedTags
                .map(
                  (tag) => InputChip(
                    label: Text(tag),
                    onDeleted:
                        widget.enabled ? () => widget.onRemoveTag(tag) : null,
                  ),
                )
                .toList(growable: false),
          ),
        ],
        if (shouldShowSuggestionArea) ...[
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 120),
            child:
                _suggestions.isEmpty
                    ? Text(
                      hasReachedLimit
                          ? 'Bạn đã chọn tối đa ${InterestTags.maxSelected} sở thích'
                          : 'Không tìm thấy tag phù hợp',
                      key: const ValueKey('interest-empty'),
                      style: theme.textTheme.bodySmall,
                    )
                    : Wrap(
                      key: ValueKey(_suggestions.join('|')),
                      spacing: 8,
                      runSpacing: 8,
                      children: _suggestions
                          .map(
                            (tag) => ActionChip(
                              label: Text(tag),
                              onPressed:
                                  widget.enabled
                                      ? () => widget.onAddTag(tag)
                                      : null,
                            ),
                          )
                          .toList(growable: false),
                    ),
          ),
        ],
      ],
    );
  }

  void _handleTextChanged() {
    _refreshSuggestions();
  }

  void _refreshSuggestions() {
    final nextQuery = widget.controller.text;
    final nextSuggestions = InterestTags.search(
      nextQuery,
      excluding: widget.selectedTags,
    );

    if (_query == nextQuery && _listEquals(_suggestions, nextSuggestions)) {
      return;
    }

    if (!mounted) {
      _query = nextQuery;
      _suggestions = nextSuggestions;
      return;
    }

    setState(() {
      _query = nextQuery;
      _suggestions = nextSuggestions;
    });
  }

  void _submitFirstSuggestion(String _) {
    if (_suggestions.isNotEmpty) {
      widget.onAddTag(_suggestions.first);
    }
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
