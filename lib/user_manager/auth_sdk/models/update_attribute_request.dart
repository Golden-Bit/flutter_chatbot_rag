import 'user_attribute.dart';

class UpdateAttributesRequest {
  final String accessToken;
  final List<UserAttribute> attributes;

  UpdateAttributesRequest({
    required this.accessToken,
    required this.attributes,
  });

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'attributes': attributes.map((attr) => attr.toJson()).toList(),
    };
  }
}
