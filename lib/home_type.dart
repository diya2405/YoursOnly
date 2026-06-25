
import 'package:flutter/cupertino.dart';

import 'GeminiChatBot.dart';

enum HomeType { aiChatBot}

extension MyHomeType on HomeType {
  String get title => switch (this) {
    HomeType.aiChatBot => "AI ChatBot",
  };

  String get lottie => switch (this) {
    HomeType.aiChatBot => "Hand_Waving_Robot.json",
  };

  bool get leftAlign => switch (this) {
    HomeType.aiChatBot => true,
  };

  Object get pages => switch (this) {
    HomeType.aiChatBot => Geminichatbot()
  };
}
