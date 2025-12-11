import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:matchu_app/models/queue_user_model.dart';
import 'package:matchu_app/models/temp_chat_room_model.dart';

class MatchingService {
  final db = FirebaseDatabase.instance.ref();
  final firestore = FirebaseFirestore.instance;
}
