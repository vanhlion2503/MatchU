import 'package:flutter/material.dart';

class AnonymousAvatar extends StatelessWidget {
  const AnonymousAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 16,
      backgroundColor:
          Theme.of(context).colorScheme.primary.withOpacity(0.15),
      child: Icon(
        Icons.person,
        size: 18,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}