class Customer {
  final int? id;
  final String name;
  final String email;
  final String? phone;
  final String? photo;

  Customer( {this.id, required this.name, required this.email, this.phone, this.photo,});

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    id: json['id'],
    name: json['name'],
    email: json['email'],
    phone: json['phone'],
    photo: json['photo'],
  );


  Customer copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    String? photo,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photo: photo ?? this.photo,
    );
  }




  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "email": email,
    "phone": phone,
    "photo": photo
  };



}
