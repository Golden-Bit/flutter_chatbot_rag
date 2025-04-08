class UserAttribute {
  final String name;
  final String value;

  UserAttribute({
    required this.name,
    required this.value,
  });

  Map<String, dynamic> toJson() {
    return {
      'Name': name,
      'Value': value,
    };
  }
}
