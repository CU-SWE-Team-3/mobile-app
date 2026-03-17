import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OAuthLoginPage extends ConsumerWidget {
  const OAuthLoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
        backgroundColor: Colors.black12,
        body:
        Container(
          margin: EdgeInsets.only(top: 128),
          child:
          Column(
            children: [

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Image.asset('assets/images/soundcloud_logo.png',width: 100, height: 100),

                  Container(
                    width: 2,        // line thickness
                    height: 100,     // line height
                    color: Colors.white,
                  ),

                  Image.asset('assets/icons/Google_Icon.png',width: 100, height: 100)
                ],
              ),

              Container(
                margin: EdgeInsets.only(top: 75),
                padding: EdgeInsets.symmetric(horizontal: 20),
                width: 500,
                height: 75,
                child: const Text("Your account has successfully been connected with Google",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 25,
                        fontFamily: 'modern sans-serif font'
                    )
                ),
              ),

              Container(
                padding: EdgeInsets.symmetric(horizontal: 20),
                width: 500,
                height: 50,
                child: const Text("Click continue to proceed to BioBeats",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        fontFamily: 'modern sans-serif font'
                    )
                ),
              ),

              GestureDetector(
                  onTap:(){
                    print("Continue"); // checking that its working
                  },
                  child: Container(
                    margin: EdgeInsets.only(top: 35),
                    width:200,
                    height: 50,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10)
                    ),
                    child: const Center(
                      child: Text('Continue',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              fontSize: 16,
                              fontFamily: 'modern sans-serif font'
                          )
                      ),
                    ),
                  )
              )
            ],
          ),
        )
    );
  }
}
