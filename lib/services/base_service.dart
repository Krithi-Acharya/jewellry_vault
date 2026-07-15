import 'package:dio/dio.dart';
import 'api_service.dart';

abstract class BaseService {
  Dio get dio => ApiService.instance.client;
}
