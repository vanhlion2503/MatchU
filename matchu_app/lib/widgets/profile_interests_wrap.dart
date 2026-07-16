import 'package:matchu_app/translations/localized_material.dart';
import 'package:matchu_app/utils/interest_tags.dart';

class ProfileInterestsWrap extends StatelessWidget {
  const ProfileInterestsWrap({
    super.key,
    required this.interests,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.alignment = WrapAlignment.start,
  });

  final List<String> interests;
  final EdgeInsetsGeometry padding;
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) {
    if (interests.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: padding,
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: alignment,
          spacing: 8,
          runSpacing: 8,
          children: interests
              .map(
                (tag) => Chip(
                  label: Text(InterestTags.localizedLabel(tag)),
                  visualDensity: VisualDensity.compact,
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}
