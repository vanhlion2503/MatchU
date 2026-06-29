import 'package:flutter/material.dart';

class ProfileInterestsWrap extends StatelessWidget {
  const ProfileInterestsWrap({
    super.key,
    required this.interests,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  final List<String> interests;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (interests.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: padding,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: interests
            .map(
              (tag) =>
                  Chip(label: Text(tag), visualDensity: VisualDensity.compact),
            )
            .toList(growable: false),
      ),
    );
  }
}
