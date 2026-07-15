import 'package:bimobondapp/app/countries/data/models/country_model.dart';
import 'package:bimobondapp/core/error/dio_handler.dart';
import 'package:bimobondapp/core/error/exceptions.dart';
import 'package:bimobondapp/core/network/api_client.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:dio/dio.dart';

class CountriesRemoteDataSource {
  CountriesRemoteDataSource({required this.apiClient});

  final ApiClient apiClient;

  List<dynamic> _extractList(dynamic body) {
    if (body is List) return body;
    if (body is Map) {
      final data = body['data'];
      if (data is List) return data;
    }
    return const [];
  }

  Future<List<CountryModel>> getCountries() async {
    try {
      final response = await apiClient.dio.get(ApiConstants.countries);
      if (response.statusCode == 200) {
        return _extractList(response.data)
            .whereType<Map>()
            .map(
              (json) => CountryModel.fromJson(Map<String, dynamic>.from(json)),
            )
            .where((c) => c.code.isNotEmpty && c.name.isNotEmpty)
            .toList();
      }
      throw ServerException(message: 'Failed to load countries');
    } on DioException catch (error) {
      throw DioHandler.handle(error);
    } catch (error) {
      throw DioHandler.handle(error);
    }
  }

  Future<CountryCitiesResultModel> getCities(String code) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.countryCities(code),
      );
      if (response.statusCode == 200 && response.data is Map) {
        return CountryCitiesResultModel.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
      throw ServerException(message: 'Failed to load cities');
    } on DioException catch (error) {
      throw DioHandler.handle(error);
    } catch (error) {
      throw DioHandler.handle(error);
    }
  }
}
