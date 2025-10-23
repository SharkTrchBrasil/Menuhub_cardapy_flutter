import 'package:dio/dio.dart';
import 'package:either_dart/either.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';


import '../core/di.dart';
import '../models/banners.dart';
import '../models/product.dart';
import '../models/store_city.dart';
import '../models/store_neig.dart';


class StoreRepository {
  StoreRepository(this._dio, this._secureStorage);

  final Dio _dio;
  final FlutterSecureStorage _secureStorage;



  // ✅ CORREÇÃO: Método renomeado e com retorno ajustado
  /// Busca os detalhes completos de um único produto.
  Future<Product> fetchProductDetails(int productId) async {
    try {
      final storeUrl = getIt<String>(instanceName: 'initialSubdomain');
      final response = await _dio.get(
        '/products/$storeUrl/$productId',
        options: Options(headers: {'Accept': 'application/json'}),
      );
      // Retorna o produto diretamente em caso de sucesso
      return Product.fromJson(response.data);
    } catch (e) {
      debugPrint('Erro ao buscar detalhes do produto: $e');
      // Lança uma exceção em caso de erro, que será capturada pelo Cubit
      throw Exception('Não foi possível carregar os detalhes do produto.');
    }
  }

  Future<Either<void, Product>> getProduct(int productId) async {
    try {

      final storeUrl = getIt<String>(instanceName: 'initialSubdomain');


      final response = await _dio.get(
        '/products/$storeUrl/$productId',
        options: Options(
          headers: {
            'Accept': 'application/json', // <--- Adicione esta linha
          },
        ),
      );



      return Right(Product.fromJson(response.data));
    } catch (e) {
      debugPrint('$e');
      return const Left(null);
    }
  }

  Future<Either<void, BannerModel>> getBanners() async {
    try {
      final token = await _secureStorage.read(key: 'totem_token');

      final response = await _dio.get(
        '/banners',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      return Right(BannerModel.fromJson(response.data));
    } catch (e) {
      debugPrint('$e');
      return const Left(null);
    }
  }


  Future<Either<void, List<StoreCity>>> getStoreCities(int storeId) async {
    try {
      final response = await _dio.get('/stores/$storeId/cities');
      final data = response.data as List;
      final cities = data.map((json) => StoreCity.fromJson(json)).toList();
      return Right(cities);
    } catch (e) {
      print('Erro ao buscar cidades da loja: $e');
      return Left(null);
    }
  }

  Future<Either<void, List<StoreNeighborhood>>> getStoreNeighborhoods({
    required int cityId,
  }) async {
    try {
      final response = await _dio.get('/stores/cities/$cityId/neighborhoods');
      final data = response.data as List;
      final neighborhoods = data.map((json) => StoreNeighborhood.fromJson(json)).toList();
      return Right(neighborhoods);
    } catch (e) {
      print('Erro ao buscar bairros da cidade: $e');
      return Left(null);
    }
  }



}
