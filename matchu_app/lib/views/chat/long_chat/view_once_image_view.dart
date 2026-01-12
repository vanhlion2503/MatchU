import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class ViewOnceImageView extends StatefulWidget {
  final String imagePath;
  final bool canDelete;
  final Future<void> Function()? onViewed;
  final Future<void> Function()? onExit;

  const ViewOnceImageView({
    super.key,
    required this.imagePath,
    required this.canDelete,
    this.onViewed,
    this.onExit,
  });

  @override
  State<ViewOnceImageView> createState() => _ViewOnceImageViewState();
}

class _ViewOnceImageViewState extends State<ViewOnceImageView> {
  static const int _maxBytes = 10 * 1024 * 1024;

  Uint8List? _bytes;
  bool _loading = true;
  bool _viewedMarked = false;
  bool _exitHandled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.imagePath.isEmpty) {
      setState(() {
        _loading = false;
        _error = "Ảnh đã bị xóa";
      });
      return;
    }

    try {
      final data = await FirebaseStorage.instance
          .ref(widget.imagePath)
          .getData(_maxBytes);

      if (!mounted) return;

      if (data == null) {
        setState(() {
          _loading = false;
          _error = "Ảnh đã bị xóa";
        });
        return;
      }

      setState(() {
        _bytes = data;
        _loading = false;
      });

      if (widget.canDelete && widget.onViewed != null && !_viewedMarked) {
        _viewedMarked = true;
        await widget.onViewed!();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Không thể tải ảnh";
      });
    }
  }

  Future<bool> _handleExit() async {
    if (_exitHandled) return true;
    _exitHandled = true;

    if (_viewedMarked && widget.onExit != null) {
      try {
        await widget.onExit!();
      } catch (_) {}
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleExit,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            "Ảnh",
            style: TextStyle(color: Colors.white),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              await _handleExit();
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: Center(
          child: _loading
              ? const CircularProgressIndicator(color: Colors.white)
              : _bytes != null
                  ? InteractiveViewer(
                      child: Image.memory(
                        _bytes!,
                        fit: BoxFit.contain,
                      ),
                    )
                  : Text(
                      _error ?? "Ảnh đã bị xóa",
                      style: const TextStyle(color: Colors.white70),
                    ),
        ),
      ),
    );
  }
}
