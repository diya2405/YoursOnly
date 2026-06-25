import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'Home_Cart.dart';
import 'home_type.dart';


class Homescreen extends StatefulWidget {
  const Homescreen({super.key});

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  Widget build(BuildContext context) {
    var mq = MediaQuery.sizeOf(context);

    return Scaffold(
      appBar: AppBar(

        title: const Text(
          "AI Assistant",
        ),
        actions: [
          IconButton(
              padding: const EdgeInsets.only(right: 10),
              onPressed: () {},
              icon: const Icon(
                Icons.brightness_4_rounded,
                color: Colors.blue,
                size: 30,
              ))
        ],
      ),

      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: mq.width * 0.035 , vertical: mq.height * 0.015),
        children: HomeType.values.map((e) => HomeCard(homeType: e)).toList(),
      ),
    );
  }
}
