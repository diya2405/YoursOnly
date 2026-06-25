import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'Homescreen.dart';
import 'Onboarding.dart';


class Splashscreen extends StatefulWidget {
  const Splashscreen({super.key});

  static const String KEYLOGIN = "Login";

  @override
  State<Splashscreen> createState() => _SplashscreenState();
}

class _SplashscreenState extends State<Splashscreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(
        Duration(
          seconds: 2,
        ),
            (){
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => Homescreen()));
        }
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            height: 150,
            width: 150,
            child: Lottie.asset("assets/images/LotieFiles/SplashScreen.json"),
          ),
        ),
      ),
    );
  }

  void WhereToGo() async{
    var pref = await SharedPreferences.getInstance();
    var isLogedIn = pref.getBool(Splashscreen.KEYLOGIN);

    if (isLogedIn != null){
      if (isLogedIn){
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => Homescreen(),));
        //.OFF is similar to pushReplacement
        // Get.off(Homescreen());
      }
      else{
        // Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => Onboarding(),));
        Get.off(Onboarding());
      }
    }
    else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => Onboarding(),));
      // Get.off(Onboarding());
    }
  }
}
