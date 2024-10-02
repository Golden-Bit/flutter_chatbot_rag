// database_model.dart

class Database {
  final String dbName;
  final String host;
  final int port;

  Database({
    required this.dbName,
    required this.host,
    required this.port,
  });

  factory Database.fromJson(Map<String, dynamic> json) {
    return Database(
      dbName: json['db_name'],
      host: json['host'],
      port: json['port'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "db_name": dbName,
      "host": host,
      "port": port,
    };
  }
}

class Collection {
  final String name;

  Collection({required this.name});

  factory Collection.fromJson(Map<String, dynamic> json) {
    return Collection(name: json['name']);
  }

  Map<String, dynamic> toJson() {
    return {"name": name};
  }
}
