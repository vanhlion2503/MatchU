import 'package:get/get.dart';

class MainController extends GetxController{
  final RxInt currentIndex = 2.obs;
  
  void changePage(int index){
    currentIndex.value = index;
  }
}