
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/customer_address.dart';
import '../models/store.dart';
import '../pages/checkout/checkout_page.dart';
import '../pages/address/edit_adress.dart';




class DialogService {




  // Helper ou método estático para mostrar o dialog
  static Future<void> showAddressDialog(
      BuildContext context, {
        required int customerId,
        required Store store,
        CustomerAddress? addressToEdit, // ✅ Renomeado e agora do tipo correto
      }) {
    return showDialog(
      context: context,
      builder: (_) => EditAddressPage(

        addressToEdit: addressToEdit,
      ),
    );
  }





// Adicione mais diálogos aqui conforme necessário
}
