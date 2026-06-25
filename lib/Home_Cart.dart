import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:healthapp/GeminiChatBot.dart';
import 'package:lottie/lottie.dart';

import 'home_type.dart';


class HomeCard extends StatelessWidget {
  final HomeType homeType;

  const HomeCard({
    super.key,
    required this.homeType,
  });

  @override
  Widget build(BuildContext context) {
    Animate.restartOnHotReload = true;
    var mq = MediaQuery.sizeOf(context);
    final textStyle = const TextStyle(
      fontWeight: FontWeight.w400,
      fontSize: 20,
      letterSpacing: 1,
    );

    final double boxSize = mq.width * 0.4;

    return InkWell(

      onTap: (){
        Navigator.push(context, MaterialPageRoute(builder: (context) => Geminichatbot()));
        // Get.to(homeTy);
      },

      child: Card(
        color: Colors.blue.withOpacity(0.2),
        elevation: 0,
        margin: EdgeInsets.only(bottom: mq.height * 0.02),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(25)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: homeType.leftAlign
              ? Row(
                  children: [
                    SizedBox(
                      child: Container(
                        width: mq.width * .35,
                        child: Lottie.asset(
                          "assets/images/LotieFiles/${homeType.lottie}",
                          errorBuilder: (context, error, stackTrace) =>
                              Icon(Icons.error, size: boxSize),
                        ),
                      ).animate().fade(duration: GetNumUtils(3).seconds ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: boxSize,
                      height: boxSize,
                      child: Center(
                        child: Text(
                          homeType.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 25,
                              letterSpacing: 1),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ).animate().fade(duration: GetNumUtils(3).seconds ),
                    const Spacer(flex: 2),
                  ],
                )
              : Row(
                  children: [
                    const Spacer(flex: 2),
                    SizedBox(
                      width: boxSize,
                      height: boxSize,
                      child: Center(
                        child: Text(
                          homeType.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 25,
                              letterSpacing: 1),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ).animate().fade(duration: GetNumUtils(3).seconds ),
                    const Spacer(),
                    SizedBox(
                      width: boxSize,
                      height: boxSize,
                      child: Container(
                        padding:EdgeInsets.all(20),
                        width: mq.width * .35,
                        child: Lottie.asset(
                          "assets/images/LotieFiles/${homeType.lottie}",
                          errorBuilder: (context, error, stackTrace) =>
                              Icon(Icons.error, size: boxSize),
                        ),
                      ).animate().fade(duration: GetNumUtils(3).seconds ),
                    ),
                    const Spacer(flex: 2),
                  ],
                ),
        ),
      ).animate().fade(begin: 0.5,duration: GetNumUtils(3).seconds ),
    );
  }
}
