import 'package:dio/dio.dart';
import 'package:either_dart/either.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:totem/models/category.dart'; // Importando o Category que faltava
import '../core/di.dart';
import '../models/banners.dart';
import '../models/product.dart';
import '../models/store_city.dart';
import '../models/store_neig.dart';

class StoreRepository {
  StoreRepository(this._dio, this._secureStorage);

  final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  // ✅ MÉTODO CORRIGIDO: Agora recebe o slug da loja explicitamente.
  Future<Product> fetchProductDetails({
    required int productId,
    required String storeSlug, // Parâmetro adicionado
  }) async {
    try {
      // Usa o slug fornecido em vez de buscar no GetIt.
      final response = await _dio.get(
        '/products/$storeSlug/$productId',
        options: Options(headers: {'Accept': 'application/json'}),
      );
      return Product.fromJson(response.data);
    } catch (e) {
      debugPrint('Erro ao buscar detalhes do produto: $e');
      throw Exception('Não foi possível carregar os detalhes do produto.');
    }
  }

  // ✅ NOVO MÉTODO: A busca de categoria também precisa do slug da loja.
  Future<Category> fetchCategoryDetails({
    required int categoryId,
    required String storeSlug,
  }) async {
    try {
      final response = await _dio.get(
        '/categories/$storeSlug/$categoryId',
        options: Options(headers: {'Accept': 'application/json'}),
      );
      return Category.fromJson(response.data);
    } catch (e) {
      debugPrint('Erro ao buscar detalhes da categoria: $e');
      throw Exception('Não foi possível carregar os detalhes da categoria.');
    }
  }

  Future<Either<void, BannerModel>> getBanners() async {
    try {
      final token = await _secureStorage.read(key: 'totem_token');
      final response = await _dio.get(
        '/banners',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
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