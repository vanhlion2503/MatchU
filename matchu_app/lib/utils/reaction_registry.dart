import 'package:flutter/material.dart';
import 'package:matchu_app/models/reaction_icon.dart';

class ReactionRegistry {
  static final Map<String, ReactionIcon> map = {
    "like": ReactionIcon(
      id: "like",
      icon: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.blue,
            width: 1.5,
          ),
          color: Colors.blue,
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.thumb_up,
          size: 10,
          color: Colors.white,
        ),
      ),
    ),

    "love": ReactionIcon(
      id: "love",
      icon: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.red,
            width: 1.5,
          ),
          color: Colors.red,
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.favorite,
          size: 10,
          color: Colors.white,
        ),
      ),
    ),

    "haha": ReactionIcon(
      id: "haha",
      icon: const Text("😂", style: TextStyle(fontSize: 16)),
    ),

    "wow": ReactionIcon(
      id: "wow",
      icon: const Text("😮", style: TextStyle(fontSize: 16)),
    ),

    "lo": ReactionIcon(
      id: "lo",
      icon: const Text("😢", style: TextStyle(fontSize: 16)),
    ),

    "gian": ReactionIcon(
      id: "gian",
      icon: const Text("😡", style: TextStyle(fontSize: 16)),
    ),
  };

  static ReactionIcon? get(String id) => map[id];
}
