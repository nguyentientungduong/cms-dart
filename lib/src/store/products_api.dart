import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:teta_cms/src/constants.dart';
import 'package:teta_cms/src/mappers/product_mapper.dart';
import 'package:teta_cms/src/use_cases/get_server_request_headers/get_server_request_headers.dart';
import 'package:teta_cms/teta_cms.dart';

/// Set of apis to control products
@lazySingleton
class TetaStoreProductsApi {
  /// Set of apis to control products
  TetaStoreProductsApi(
    this._productMapper,
    this._getServerRequestHeaders,
    this._dio,
  );

  /// Product mapper
  final ProductMapper _productMapper;

  /// Http headers
  final GetServerRequestHeaders _getServerRequestHeaders;

  /// Client Dio
  final Dio _dio;

  /// Gets all the products.
  /// The products are taken by the project's shop.
  Future<TetaProductsResponse> all() async {
    try {
      final res = await _dio.get<String>(
        '${Constants.shopBaseUrl}/product/list',
        options: Options(
          headers: _getServerRequestHeaders.execute(),
        ),
      );

      if (res.statusCode != 200) {
        return TetaProductsResponse(
          error: TetaErrorResponse(
            code: res.statusCode,
            message: res.data,
          ),
        );
      }
      final decodedList = (jsonDecode(res.data!) as List<dynamic>)
          .map((final dynamic e) => e as Map<String, dynamic>)
          .toList(growable: false);

      return TetaProductsResponse(
        data: _productMapper.mapProducts(decodedList),
      );
    } catch (e) {
      return TetaProductsResponse(
        error: TetaErrorResponse(
          code: 403,
          message: '$e',
        ),
      );
    }
  }

  /// Gets a single product by id.
  /// The product is selected in the project's shop
  Future<TetaProductResponse> get(final String prodId) async {
    final uri = Uri.parse(
      '${Constants.shopBaseUrl}/product/$prodId',
    );

    final res = await http.get(
      uri,
      headers: _getServerRequestHeaders.execute(),
    );

    TetaCMS.printWarning('list products body: ${res.body}');

    if (res.statusCode != 200) {
      return TetaProductResponse(
        error: TetaErrorResponse(
          code: res.statusCode,
          message: res.body,
        ),
      );
    }

    return TetaProductResponse(
      data: _productMapper
          .mapProduct(json.decode(res.body) as Map<String, dynamic>),
    );
  }

  /// Adds a new product on the shop of the project.
  /// 1 prj = 1 shop.
  /// If everything goes ok it returns {'ok': true}
  Future<TetaResponse> insert(final TetaProduct product) async {
    final uri = Uri.parse(
      '${Constants.shopBaseUrl}/product',
    );

    final res = await http.post(
      uri,
      headers: _getServerRequestHeaders.execute(),
      body: json.encode(
        product.toJson(),
      ),
    );

    TetaCMS.printWarning('insert product body: ${res.body}');

    if (res.statusCode != 200) {
      return TetaResponse<dynamic, TetaErrorResponse>(
        error: TetaErrorResponse(
          code: res.statusCode,
          message: res.body,
        ),
        data: null,
      );
    }

    return TetaResponse<String, dynamic>(
      data: json.encode(res.body),
      error: null,
    );
  }

  /// Updates a product by id.
  /// Wants a product object to update all the fields.
  Future<TetaProductResponse> update(final TetaProduct product) async {
    final uri = Uri.parse(
      '${Constants.shopBaseUrl}/product/${product.id}',
    );

    final res = await http.put(
      uri,
      headers: _getServerRequestHeaders.execute(),
      body: json.encode(
        product.toJson(),
      ),
    );

    if (res.statusCode != 200) {
      return TetaProductResponse(
        error: TetaErrorResponse(
          code: res.statusCode,
          message: res.body,
        ),
      );
    }

    return TetaProductResponse(
      data: product,
    );
  }

  /// Deletes a product by id
  Future<TetaResponse> delete(final String prodId) async {
    final uri = Uri.parse(
      '${Constants.shopBaseUrl}/product/$prodId',
    );

    final res = await http.delete(
      uri,
      headers: {
        ..._getServerRequestHeaders.execute(),
        'content-type': 'application/json',
      },
    );

    if (res.statusCode != 200) {
      return TetaResponse<dynamic, TetaErrorResponse>(
        error: TetaErrorResponse(
          code: res.statusCode,
          message: res.body,
        ),
        data: null,
      );
    }

    return TetaResponse<dynamic, dynamic>(
      data: null,
      error: null,
    );
  }
}
