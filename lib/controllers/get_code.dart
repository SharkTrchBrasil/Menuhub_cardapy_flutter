import 'package:flutter/material.dart'; // Importe o pacote fundamental para ChangeNotifier

class InboxController extends ChangeNotifier {
  int pageselecter = 0;
  bool drwar = false;

  void setvalue(){ // Métodos em Provider devem ser void e notificar ouvintes
    drwar = !drwar;
    notifyListeners(); // Substitui update() do GetX
  }

  // A lista page12 não precisa de modificação se for apenas um dado.
  // Se for usada para construir widgets, certifique-se de que os widgets comentados
  // sejam devidamente importados ou removidos.
  List page12 = [
    // const laout(),                         //0
    // const Inbox(),                         //1
    // const Projct(),                        //2
    // const comoponet(),                     //3
    // const tabs(),                          //4
    // const Button(),                        //5
    // const Drop_Down(),                     //6
    // const Form_Elemente(),                 //7
    // const Floating_Lables(),               //8
    // const Select_Screen(),                 //9
    // const Checkbox_and_Radio(),            //10
    // const InputScreen(),                   //11
    // const Vertical_Horizontal(),           //12
    // const Inline_Form(),                   //13
    // const Pricing_Screen(),                //14
    // const Avater_SCreen(),                 //15
    // const CAROUSEL_screen(),               //16
    // const Zig_and_Zag_Screen(),            //17
    // const MAP_SCREEN(),                    //18
    // const FAQ_Screen(),                    //19
    // const Chat_Screen(),                   //20
    // const Widget_Screen_1(),               //21
    // const Auth_Screen(),                   //22
    // const Login_Screen(),                  //23
    // const ForgotScreen(),                  //24
    // const Forgot_Screen_2(),               //25
    // const OTP_Screen(),                    //26
    // const OTP_Screen(),                    //27
    // const Charyt_Screen(),                 //28
    // const Project_Create(),                //29
    // const invoice_screen(),                //30
    // const Invoid_Table(),                  //31
    // const Error_Screen_1(),                //32
    // const Error_Screen_2(),                //33
    // const Started_Screen_1(),              //34
    // const Comming_soon(),                  //35
    // const multi_level(),                   //36
    // const Validation(),                    //37
    // const kanban_screen_1(),               //38
    // const Product_screen_1(),              //39
    // const Product_Screen_11(),             //40
    // const Cart_screen_1(),                 //41
    // const Check_out_1(),                   //42
    // const Order_Screen_1(),                //43
    // const Add_Product_screen_1(),          //44
    // const Invoices(),                      //45
    // const crm_dashboard(),                 //46
    // const Contact_Details_Screen(),        //47
    // const Opportunitie_Screen(),           //48
    // const Task_Screen(),                   //49
    // const Contact_Screen_2(),              //50
    // const Profile_Details(),               //51
    // const auto_complete_select(),          //52
    // const File_Uploade(),                  //53
  ];

  void setTextIsTrue(int value) { // Métodos em Provider devem ser void e notificar ouvintes
    pageselecter = value;
    notifyListeners(); // Substitui update() do GetX
  }
}