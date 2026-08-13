import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import 'catalogue_models.dart';

abstract interface class CatalogueRemoteDataSource {
  Future<CatalogueManifest> fetchManifest(Uri manifestUri);

  Future<CatalogueSnapshot> fetchCatalogue(
    Uri manifestUri,
    CatalogueManifest manifest,
  );
}

class DioCatalogueRemoteDataSource implements CatalogueRemoteDataSource {
  const DioCatalogueRemoteDataSource(this._dio);

  final Dio _dio;

  @override
  Future<CatalogueManifest> fetchManifest(Uri manifestUri) async {
    final bytes = await _getBytes(manifestUri);
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on Object catch (error) {
      throw CatalogueValidationException(
        'Catalogue manifest is not valid UTF-8 JSON.',
        error,
      );
    }
    return CatalogueManifest.fromJson(decoded);
  }

  @override
  Future<CatalogueSnapshot> fetchCatalogue(
    Uri manifestUri,
    CatalogueManifest manifest,
  ) async {
    final catalogueUri = manifestUri.resolve(manifest.catalogueUrl);
    if (catalogueUri.scheme != 'https' && catalogueUri.scheme != 'http') {
      throw const CatalogueValidationException(
        'Resolved catalogue URL must use HTTP or HTTPS.',
      );
    }
    final bytes = await _getBytes(catalogueUri);
    final checksum = sha256.convert(bytes).toString();
    if (checksum != manifest.sha256) {
      throw const CatalogueValidationException(
        'Catalogue checksum does not match the manifest.',
      );
    }
    return CatalogueSnapshot.fromBytes(manifest: manifest, bytes: bytes);
  }

  Future<List<int>> _getBytes(Uri uri) async {
    final response = await _dio.getUri<List<int>>(
      uri,
      options: Options(
        responseType: ResponseType.bytes,
        headers: const {'Cache-Control': 'no-cache'},
      ),
    );
    final data = response.data;
    if (data == null) {
      throw const CatalogueValidationException(
        'Catalogue server returned an empty response.',
      );
    }
    return data;
  }
}
