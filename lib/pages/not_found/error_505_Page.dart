

import 'package:flutter/material.dart';




class NotFoundPage extends StatefulWidget {
  const NotFoundPage({super.key});

  @override
  State<NotFoundPage> createState() => NotFoundPageState();
}

class NotFoundPageState extends State<NotFoundPage> {

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: SizedBox(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,

        child: LayoutBuilder(builder: (context, constraints) {
          if(constraints.maxWidth<600){
            return  Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [

                const SizedBox(height: 20,),
                const Spacer(),
                centercontain(),
                const Spacer(),
              ],
            );
          }
          else if(constraints.maxWidth<1000){
            return  Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [

                const SizedBox(height: 20,),
                const Spacer(),
                centercontain(),
                const Spacer(),
              ],);
          }
          else{
            return  Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [

                const Spacer(),
                centercontain(),
                const Spacer(),
              ],
            );
          }
        },
        ),
      ),
    );
  }





  Widget centercontain(){
    return  Padding(
      padding: const EdgeInsets.only(left: 10,right: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Image(image: AssetImage('assets/undraw_questions_75e0.png')),
          const SizedBox(height: 10,),
          Text('Nada encontrado',style: TextStyle(fontSize: 30,),),
          const SizedBox(height: 10,),
          Text('Essa página não existe ou endereço errado',style: TextStyle(),),

          const SizedBox(height: 10,),

        ],
      ),
    );
  }



}
