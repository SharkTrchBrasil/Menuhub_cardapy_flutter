import 'package:dio/dio.dart';
import 'package:either_dart/either.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:totem/models/category.dart'; // Importando o Category que faltava
import 'package:totem/models/menu/menu_response.dart'; // ✅ NOVO: Formato de menu
import '../core/di.dart';
import '../models/banners.dart';
import '../models/product.dart';
import '../models/store_city.dart';
import '../models/store_neig.dart';

class StoreRepository {
  StoreRepository(this._dio, this._secureStorage);

  final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  // ✅ CORRIGIDO: Backend usa Host header para identificar a loja
  // Endpoint: GET /products/{product_id}
  Future<Product> fetchProductDetails({
    required int productId,
    required String storeSlug, // Mantido para compatibilidade, mas não usado na URL
  }) async {
    try {
      final response = await _dio.get(
        '/products/$productId',
        options: Options(headers: {'Accept': 'application/json'}),
      );
      return Product.fromJson(response.data);
    } catch (e) {
      debugPrint('Erro ao buscar detalhes do produto: $e');
      throw Exception('Não foi possível carregar os detalhes do produto.');
    }
  }

  // ⚠️ NOTA: Endpoint /categories/{id} não existe no backend
  // As categorias são carregadas junto com o menu da loja
  // Este método é mantido para compatibilidade, mas lança exceção
  Future<Category> fetchCategoryDetails({
    required int categoryId,
    required String storeSlug,
  }) async {
    // Categorias devem ser obtidas do StoreCubit (já carregadas com o menu)
    throw Exception(
      'Categoria não encontrada. Use StoreCubit.state.categories para obter categorias já carregadas.'
    );
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

  /// ✅ NOVO: Busca menu no novo formato (com estrutura de pizzas por tamanhos)
  /// Endpoint: GET /menu ou similar (verificar endpoint exato no backend)
  Future<Either<String, MenuResponse>> fetchMenu() async {
    try {
      final response = await _dio.get(
        '/menu', // ✅ Ajustar endpoint conforme backend
        options: Options(headers: {'Accept': 'application/json'}),
      );
      
      final menuResponse = MenuResponse.fromJson(response.data);
      return Right(menuResponse);
    } catch (e) {
      debugPrint('Erro ao buscar menu: $e');
      return Left('Não foi possível carregar o menu.');
    }
  }
}