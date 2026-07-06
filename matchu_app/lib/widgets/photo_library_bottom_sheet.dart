import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:photo_manager/photo_manager.dart';

class PhotoLibrarySelection {
  const PhotoLibrarySelection({required this.file, required this.fileName});

  final File file;
  final String fileName;
}

enum PhotoLibraryMediaType { image, video }

class PhotoLibraryBottomSheet extends StatefulWidget {
  const PhotoLibraryBottomSheet({
    super.key,
    required this.maxSelection,
    this.mediaType = PhotoLibraryMediaType.image,
    this.title = 'Chọn ảnh',
    this.heightFactor = 0.5,
    this.showCameraTile = false,
    this.onCameraTap,
  });

  final int maxSelection;
  final PhotoLibraryMediaType mediaType;
  final String title;
  final double heightFactor;
  final bool showCameraTile;
  final Future<void> Function()? onCameraTap;

  static Future<List<PhotoLibrarySelection>?> show(
    BuildContext context, {
    required int maxSelection,
    PhotoLibraryMediaType mediaType = PhotoLibraryMediaType.image,
    String title = 'Chọn ảnh',
    double heightFactor = 0.5,
    bool showCameraTile = false,
    Future<void> Function()? onCameraTap,
  }) {
    if (maxSelection <= 0) {
      return Future.value(const <PhotoLibrarySelection>[]);
    }

    return showModalBottomSheet<List<PhotoLibrarySelection>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      builder:
          (_) => PhotoLibraryBottomSheet(
            maxSelection: maxSelection,
            mediaType: mediaType,
            title: title,
            heightFactor: heightFactor,
            showCameraTile: showCameraTile,
            onCameraTap: onCameraTap,
          ),
    );
  }

  @override
  State<PhotoLibraryBottomSheet> createState() =>
      _PhotoLibraryBottomSheetState();
}

class _PhotoLibraryBottomSheetState extends State<PhotoLibraryBottomSheet> {
  static const int _pageSize = 90;

  final ScrollController _scrollController = ScrollController();
  final List<AssetEntity> _assets = [];
  final List<AssetEntity> _selected = [];

  AssetPathEntity? _allPhotosPath;
  PermissionState? _permissionState;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _isResolvingSelection = false;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreIfNeeded);
    _bootstrap();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_loadMoreIfNeeded);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!mounted) return;

    setState(() {
      _permissionState = permission;
      _isLoading = permission.isAuth || permission.hasAccess;
    });

    if (!permission.isAuth && !permission.hasAccess) {
      setState(() => _isLoading = false);
      return;
    }

    final paths = await PhotoManager.getAssetPathList(
      type: widget.mediaType.requestType,
      onlyAll: true,
      filterOption: FilterOptionGroup(
        imageOption: const FilterOption(
          sizeConstraint: SizeConstraint(ignoreSize: true),
        ),
        orders: [
          const OrderOption(type: OrderOptionType.createDate, asc: false),
        ],
      ),
    );

    if (!mounted) return;
    if (paths.isEmpty) {
      setState(() {
        _allPhotosPath = null;
        _isLoading = false;
        _hasMore = false;
      });
      return;
    }

    _allPhotosPath = paths.first;
    await _loadPage(reset: true);
  }

  Future<void> _loadPage({required bool reset}) async {
    final path = _allPhotosPath;
    if (path == null) return;
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
      if (reset) {
        _page = 0;
        _assets.clear();
        _hasMore = true;
      }
    });

    final nextAssets = await path.getAssetListPaged(
      page: _page,
      size: _pageSize,
    );
    if (!mounted) return;

    setState(() {
      _assets.addAll(nextAssets);
      _page += 1;
      _hasMore = nextAssets.length == _pageSize;
      _isLoading = false;
      _isLoadingMore = false;
    });
  }

  void _loadMoreIfNeeded() {
    if (!_hasMore || _isLoadingMore || _isLoading) return;
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 420) return;
    _loadPage(reset: false);
  }

  void _toggleSelection(AssetEntity asset) {
    final index = _selected.indexWhere((item) => item.id == asset.id);
    if (index < 0 && _selected.length >= widget.maxSelection) {
      Get.snackbar(
        'Thông báo',
        'Chỉ có thể chọn tối đa ${widget.maxSelection} ảnh.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
      return;
    }

    setState(() {
      if (index >= 0) {
        _selected.removeAt(index);
        return;
      }

      _selected.add(asset);
    });
  }

  Future<void> _completeSelection() async {
    if (_selected.isEmpty || _isResolvingSelection) return;

    setState(() => _isResolvingSelection = true);
    final result = <PhotoLibrarySelection>[];

    for (final asset in _selected) {
      final file = await asset.file;
      if (file == null) continue;
      result.add(
        PhotoLibrarySelection(
          file: file,
          fileName: _fileNameForAsset(asset, file),
        ),
      );
    }

    if (!mounted) return;
    setState(() => _isResolvingSelection = false);
    Navigator.of(context).pop(result);
  }

  Future<void> _handleCameraTap() async {
    final onCameraTap = widget.onCameraTap;
    if (onCameraTap == null) return;

    Navigator.of(context).pop();
    await onCameraTap();
  }

  String _fileNameForAsset(AssetEntity asset, File file) {
    final title = asset.title?.trim();
    if (title != null && title.isNotEmpty) return title;
    final normalized = file.path.replaceAll('\\', '/');
    final slashIndex = normalized.lastIndexOf('/');
    if (slashIndex >= 0 && slashIndex < normalized.length - 1) {
      return normalized.substring(slashIndex + 1);
    }
    return '${widget.mediaType.filePrefix}_${asset.id}.${widget.mediaType.fallbackExtension}';
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final theme = Theme.of(context);
    final palette = _PhotoLibraryPalette.of(context);
    final sheetHeight =
        mediaQuery.size.height * widget.heightFactor.clamp(0.3, 1.0);

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: sheetHeight,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: palette.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 22,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            children: [
              _Header(
                title: widget.title,
                selectedCount: _selected.length,
                isResolvingSelection: _isResolvingSelection,
                canSubmit: _selected.isNotEmpty,
                palette: palette,
                onClose: () => Navigator.of(context).pop(),
                onSubmit: _completeSelection,
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child:
                      _isLoading
                          ? Center(
                            child: CircularProgressIndicator(
                              color: theme.colorScheme.primary,
                            ),
                          )
                          : _buildContent(context, palette),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, _PhotoLibraryPalette palette) {
    final permission = _permissionState;
    if (permission != null && !permission.isAuth && !permission.hasAccess) {
      return _PermissionStateView(palette: palette);
    }

    if (_assets.isEmpty && !widget.showCameraTile) {
      return _EmptyStateView(palette: palette, mediaType: widget.mediaType);
    }

    return GridView.builder(
      key: const ValueKey('photo_grid'),
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: _gridItemCount,
      itemBuilder: (context, index) {
        if (widget.showCameraTile) {
          if (index == 0) {
            return _CameraTile(
              palette: palette,
              mediaType: widget.mediaType,
              onTap: _handleCameraTap,
            );
          }
          index -= 1;
        }

        if (index >= _assets.length) {
          return Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          );
        }

        final asset = _assets[index];
        final selectedIndex = _selected.indexWhere(
          (item) => item.id == asset.id,
        );
        return _PhotoTile(
          asset: asset,
          selectionIndex: selectedIndex,
          palette: palette,
          mediaType: widget.mediaType,
          onTap: () => _toggleSelection(asset),
        );
      },
    );
  }

  int get _gridItemCount {
    final cameraItemCount = widget.showCameraTile ? 1 : 0;
    final loadingItemCount = _isLoadingMore && _hasMore ? 1 : 0;
    return cameraItemCount + _assets.length + loadingItemCount;
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.selectedCount,
    required this.isResolvingSelection,
    required this.canSubmit,
    required this.palette,
    required this.onClose,
    required this.onSubmit,
  });

  final String title;
  final int selectedCount;
  final bool isResolvingSelection;
  final bool canSubmit;
  final _PhotoLibraryPalette palette;
  final VoidCallback onClose;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: palette.headerBackground,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onClose,
            icon: Icon(Iconsax.close_circle, color: palette.icon),
          ),
          Expanded(
            child: Text(
              selectedCount > 0 ? '$title ($selectedCount)' : title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
          ),
          TextButton(
            onPressed: canSubmit && !isResolvingSelection ? onSubmit : null,
            child:
                isResolvingSelection
                    ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    )
                    : const Icon(Icons.check_rounded),
          ),
        ],
      ),
    );
  }
}

class _CameraTile extends StatelessWidget {
  const _CameraTile({
    required this.palette,
    required this.mediaType,
    required this.onTap,
  });

  final _PhotoLibraryPalette palette;
  final PhotoLibraryMediaType mediaType;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: palette.tileBackground,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(border: Border.all(color: palette.border)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                mediaType == PhotoLibraryMediaType.video
                    ? Iconsax.video
                    : Iconsax.camera,
                size: 28,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 6),
              Text(
                mediaType == PhotoLibraryMediaType.video
                    ? 'Quay video'
                    : 'Chụp ảnh',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.asset,
    required this.selectionIndex,
    required this.palette,
    required this.mediaType,
    required this.onTap,
  });

  final AssetEntity asset;
  final int selectionIndex;
  final _PhotoLibraryPalette palette;
  final PhotoLibraryMediaType mediaType;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = selectionIndex >= 0;

    return Material(
      color: palette.tileBackground,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _AssetThumbnail(asset: asset, palette: palette),
            if (mediaType == PhotoLibraryMediaType.video)
              Positioned(
                left: 6,
                bottom: 6,
                child: _VideoDurationBadge(durationSeconds: asset.duration),
              ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 140),
              opacity: isSelected ? 1 : 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.28),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: _SelectionBadge(
                selectedNumber: isSelected ? selectionIndex + 1 : null,
                palette: palette,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoDurationBadge extends StatelessWidget {
  const _VideoDurationBadge({required this.durationSeconds});

  final int durationSeconds;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Iconsax.play, color: Colors.white, size: 10),
          const SizedBox(width: 3),
          Text(
            _formatAssetDuration(durationSeconds),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssetThumbnail extends StatelessWidget {
  const _AssetThumbnail({required this.asset, required this.palette});

  final AssetEntity asset;
  final _PhotoLibraryPalette palette;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: asset.thumbnailDataWithSize(const ThumbnailSize.square(240)),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) {
          if (snapshot.connectionState != ConnectionState.done) {
            return ColoredBox(color: palette.tileBackground);
          }

          return ColoredBox(
            color: palette.tileBackground,
            child: Icon(Iconsax.gallery_slash, color: palette.icon),
          );
        }

        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder:
              (_, __, ___) => Icon(Iconsax.gallery_slash, color: palette.icon),
        );
      },
    );
  }
}

class _SelectionBadge extends StatelessWidget {
  const _SelectionBadge({required this.selectedNumber, required this.palette});

  final int? selectedNumber;
  final _PhotoLibraryPalette palette;

  @override
  Widget build(BuildContext context) {
    final selectedNumber = this.selectedNumber;
    final isSelected = selectedNumber != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color:
            isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.black.withValues(alpha: 0.28),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.4),
      ),
      alignment: Alignment.center,
      child:
          isSelected
              ? Text(
                '$selectedNumber',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              )
              : const SizedBox.shrink(),
    );
  }
}

class _PermissionStateView extends StatelessWidget {
  const _PermissionStateView({required this.palette});

  final _PhotoLibraryPalette palette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      key: const ValueKey('permission_state'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.gallery_slash, size: 40, color: palette.icon),
            const SizedBox(height: 12),
            Text(
              'Cần cấp quyền truy cập thư viện ảnh',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Mở cài đặt để MatchU hiển thị ảnh trong thư viện.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: PhotoManager.openSetting,
              child: const Text('Mở cài đặt'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyStateView extends StatelessWidget {
  const _EmptyStateView({required this.palette, required this.mediaType});

  final _PhotoLibraryPalette palette;
  final PhotoLibraryMediaType mediaType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      key: const ValueKey('empty_state'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Iconsax.gallery, size: 40, color: palette.icon),
          const SizedBox(height: 10),
          if (mediaType == PhotoLibraryMediaType.video)
            Text(
              'Thư viện chưa có video',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            )
          else
            Text(
              'Thư viện chưa có ảnh',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
        ],
      ),
    );
  }
}

class _PhotoLibraryPalette {
  const _PhotoLibraryPalette({
    required this.background,
    required this.headerBackground,
    required this.tileBackground,
    required this.border,
    required this.icon,
    required this.textPrimary,
    required this.textSecondary,
  });

  final Color background;
  final Color headerBackground;
  final Color tileBackground;
  final Color border;
  final Color icon;
  final Color textPrimary;
  final Color textSecondary;

  factory _PhotoLibraryPalette.of(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return _PhotoLibraryPalette(
      background: theme.colorScheme.surface,
      headerBackground: isDark ? const Color(0xFF171717) : Colors.white,
      tileBackground:
          isDark ? const Color(0xFF262626) : const Color(0xFFF1F3F5),
      border: isDark ? const Color(0xFF2F343A) : const Color(0xFFE9ECEF),
      icon: isDark ? const Color(0xFFB8C1CC) : const Color(0xFF737373),
      textPrimary: theme.colorScheme.onSurface,
      textSecondary: theme.colorScheme.onSurface.withValues(alpha: 0.68),
    );
  }
}

extension on PhotoLibraryMediaType {
  RequestType get requestType {
    switch (this) {
      case PhotoLibraryMediaType.image:
        return RequestType.image;
      case PhotoLibraryMediaType.video:
        return RequestType.video;
    }
  }

  String get filePrefix {
    switch (this) {
      case PhotoLibraryMediaType.image:
        return 'image';
      case PhotoLibraryMediaType.video:
        return 'video';
    }
  }

  String get fallbackExtension {
    switch (this) {
      case PhotoLibraryMediaType.image:
        return 'jpg';
      case PhotoLibraryMediaType.video:
        return 'mp4';
    }
  }
}

String _formatAssetDuration(int seconds) {
  if (seconds <= 0) return '00:00';
  final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
  final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
  return '$minutes:$remainingSeconds';
}
