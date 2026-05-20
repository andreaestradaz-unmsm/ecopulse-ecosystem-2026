class ApiConfig {
  static String serverIp = "127.0.0.1"; 
  static String port = "8000";
  static String? token; 
  static String? userLogged;

  static String get baseUrl => "http://$serverIp:$port";
}