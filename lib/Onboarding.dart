import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'Homescreen.dart';
import 'OnBoard.dart';

class Onboarding extends StatefulWidget {
  const Onboarding({super.key});

  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  @override
  Widget build(BuildContext context) {
    var mq = MediaQuery.sizeOf(context);
    var pageController = PageController();

    var list = [
      Onboard(
          title: "Ask Me Anything",
          subtitle:
          "Got a question? I'm here to help. No matter the topic, just ask. Your answers are just a tap away!",
          image: "ChatBot.json"),
      Onboard(
          title: "Imagination to Reality",
          subtitle:
          "Transform your words into stunning visuals. From imagination to reality, watch your ideas come to life!",
          image: "ImageGenerator.json"),
      Onboard(
          title: "Ease Translation",
          subtitle:
          "QuickTranslate! Easily translate text in seconds and communicate without limits. Your bridge to any language is just a tap away.",
          image: "LanguageTranslator.json"),
    ];

    return Scaffold(
        body: PageView.builder(
          controller: pageController,
          itemCount: list.length,
          itemBuilder: (ctx, ind) {
            final islast = ind == list.length - 1;

            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                // mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Lottie.asset("assets/images/LotieFiles/${list[ind].image}",
                      height: mq.height * .45),
                  Text(
                    "${list[ind].title}",
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 28,
                        letterSpacing: .5),
                  ),
                  SizedBox(
                    height: mq.height * .03,
                  ),
                  SizedBox(
                    width: mq.width * 0.85,
                    child: Text(
                      "${list[ind].subtitle}",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w300,
                          letterSpacing: .3,
                          color: Colors.black54),
                    ),
                  ),
                  const Spacer(),
                  Wrap(
                    spacing: 10,
                    children: List.generate(
                        list.length,
                            (i) => Container(
                          width: i == ind ? 25 : 10,
                          height: 10,
                          decoration: BoxDecoration(
                              color: i == ind ? Colors.blue : Colors.grey,
                              borderRadius:
                              BorderRadius.all(Radius.circular(4))),
                        )
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () {
                      if (islast) {
                        // Navigator.pushReplacement(
                        //     context,
                        //     MaterialPageRoute(
                        //       builder: (context) => Homescreen(),
                        //     ));
                        Get.off(Homescreen());
                      } else {
                        pageController.nextPage(
                            duration: Duration(milliseconds: 600),
                            curve: Curves.linear);
                      }
                    },
                    child: Text(
                      islast ? "Finish" : "Next",
                    ),
                    style: ElevatedButton.styleFrom(
                        elevation: 0,
                        foregroundColor: Colors.white,
                        textStyle: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 20),
                        shape: StadiumBorder(),
                        minimumSize: Size(mq.width * 0.4, 50),
                        backgroundColor: Colors.blue),
                  ),
                  const Spacer(
                    flex: 2,
                  ),
                ],
              ),
            );
          },
        ));
  }
}
