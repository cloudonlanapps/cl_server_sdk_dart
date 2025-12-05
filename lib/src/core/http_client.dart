import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'exceptions.dart';

/// HTTP client wrapper for making requests to CL Server services
class HttpClientWrapper {
  HttpClientWrapper({required this.baseUrl, this.token, this.httpClient});
  final String baseUrl;
  final String? token;
  final http.Client? httpClient;

  http.Client get _httpClient => httpClient ?? http.Client();

  /// Make a GET request
  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? queryParameters,
  }) async {
    try {
      final uri = _buildUri(endpoint, queryParameters);
      final response = await _httpClient.get(uri, headers: _buildHeaders());
      return _handleResponse(response);
    } on CLServerException {
      rethrow;
    } catch (e) {
      throw NetworkException(message: 'Network error: $e');
    }
  }

  /// Make a POST request
  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParameters,
    bool isFormData = false,
    List<File>? files,
  }) async {
    try {
      final uri = _buildUri(endpoint, queryParameters);
      late final http.Response response;

      if (isFormData) {
        // Handle form data
        final request = http.MultipartRequest('POST', uri);
        request.headers.addAll(_buildHeaders());
        if (body != null) {
          body.forEach((key, value) {
            // Convert all values to String for form data
            if (value != null) {
              request.fields[key] = value.toString();
            }
          });
        }
        // Add files if provided
        if (files != null && files.isNotEmpty) {
          for (final file in files) {
            final fileName = file.path.split('/').last;
            request.files.add(
              http.MultipartFile(
                'upload_files',
                file.openRead(),
                await file.length(),
                filename: fileName,
              ),
            );
          }
        }
        final streamResponse = await _httpClient.send(request);
        response = await http.Response.fromStream(streamResponse);
      } else {
        // Handle JSON body
        response = await _httpClient.post(
          uri,
          headers: _buildHeaders(),
          body: body != null ? jsonEncode(body) : null,
        );
      }

      return _handleResponse(response);
    } on CLServerException {
      rethrow;
    } catch (e) {
      throw NetworkException(message: 'Network error: $e');
    }
  }

  /// Make a PUT request
  Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParameters,
    bool isFormData = false,
  }) async {
    try {
      final uri = _buildUri(endpoint, queryParameters);
      late final http.Response response;

      if (isFormData) {
        // Handle form data
        final request = http.MultipartRequest('PUT', uri);
        request.headers.addAll(_buildHeaders());
        if (body != null) {
          body.forEach((key, value) {
            // Convert all values to String for form data
            if (value != null) {
              request.fields[key] = value.toString();
            }
          });
        }
        final streamResponse = await _httpClient.send(request);
        response = await http.Response.fromStream(streamResponse);
      } else {
        // Handle JSON body
        response = await _httpClient.put(
          uri,
          headers: _buildHeaders(),
          body: body != null ? jsonEncode(body) : null,
        );
      }

      return _handleResponse(response);
    } on CLServerException {
      rethrow;
    } catch (e) {
      throw NetworkException(message: 'Network error: $e');
    }
  }

  /// Make a PATCH request
  Future<Map<String, dynamic>> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParameters,
    bool isFormData = false,
  }) async {
    try {
      final uri = _buildUri(endpoint, queryParameters);
      late final http.Response response;

      if (isFormData) {
        // Handle form data
        final request = http.MultipartRequest('PATCH', uri);
        request.headers.addAll(_buildHeaders());
        if (body != null) {
          body.forEach((key, value) {
            // Convert all values to String for form data
            if (value != null) {
              request.fields[key] = value.toString();
            }
          });
        }
        final streamResponse = await _httpClient.send(request);
        response = await http.Response.fromStream(streamResponse);
      } else {
        // Handle JSON body
        response = await _httpClient.patch(
          uri,
          headers: _buildHeaders(),
          body: body != null ? jsonEncode(body) : null,
        );
      }

      return _handleResponse(response);
    } on CLServerException {
      rethrow;
    } catch (e) {
      throw NetworkException(message: 'Network error: $e');
    }
  }

  /// Make a DELETE request
  Future<Map<String, dynamic>> delete(
    String endpoint, {
    Map<String, String>? queryParameters,
  }) async {
    try {
      final uri = _buildUri(endpoint, queryParameters);
      final response = await _httpClient.delete(uri, headers: _buildHeaders());
      return _handleResponse(response);
    } on CLServerException {
      rethrow;
    } catch (e) {
      throw NetworkException(message: 'Network error: $e');
    }
  }

  /// Build request headers
  Map<String, String> _buildHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Build URI with query parameters
  Uri _buildUri(String endpoint, Map<String, String>? queryParameters) {
    final url = baseUrl + endpoint;
    return Uri.parse(url).replace(queryParameters: queryParameters);
  }

  /// Handle HTTP response and convert to Map
  Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      final dynamic responseBody = jsonDecode(response.body);

      // Handle different status codes
      switch (response.statusCode) {
        case 200:
        case 201:
        case 204:
          // Success responses
          if (response.body.isEmpty) {
            return {'statusCode': response.statusCode};
          }
          if (responseBody is Map<String, dynamic>) {
            return responseBody;
          }
          if (responseBody is List) {
            return {'data': responseBody};
          }
          return {'data': responseBody};

        case 400:
          throw ValidationException(
            message: _extractErrorMessage(responseBody),
            statusCode: 400,
            details: responseBody,
          );

        case 401:
          throw AuthException(
            message: _extractErrorMessage(responseBody),
          );

        case 403:
          throw PermissionException(
            message: _extractErrorMessage(responseBody),
          );

        case 404:
          throw ResourceNotFoundException(
            message: _extractErrorMessage(responseBody),
          );

        case 422:
          throw ValidationException(
            message: _extractErrorMessage(responseBody),
            details: responseBody,
          );

        case >= 500:
          throw ServerException(
            message: _extractErrorMessage(responseBody),
            statusCode: response.statusCode,
          );

        default:
          throw CLServerException(
            message: 'Unexpected status code: ${response.statusCode}',
            statusCode: response.statusCode,
          );
      }
    } on CLServerException {
      rethrow;
    } on FormatException {
      // If response body is not valid JSON
      return _handleNonJsonResponse(response);
    }
  }

  /// Handle non-JSON responses
  Map<String, dynamic> _handleNonJsonResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return {'statusCode': response.statusCode, 'body': response.body};
    } else if (response.statusCode == 401) {
      throw AuthException(message: response.body);
    } else if (response.statusCode == 403) {
      throw PermissionException(message: response.body);
    } else if (response.statusCode == 404) {
      throw ResourceNotFoundException(message: response.body);
    } else if (response.statusCode >= 500) {
      throw ServerException(
        message: response.body,
        statusCode: response.statusCode,
      );
    } else {
      throw CLServerException(
        message: response.body,
        statusCode: response.statusCode,
      );
    }
  }

  /// Extract error message from response body
  String _extractErrorMessage(dynamic responseBody) {
    if (responseBody is Map<String, dynamic>) {
      if (responseBody.containsKey('detail')) {
        final detail = responseBody['detail'];
        if (detail is String) {
          return detail;
        } else if (detail is List) {
          return detail.isNotEmpty ? detail.toString() : 'Validation error';
        }
      }
      if (responseBody.containsKey('message')) {
        return responseBody['message'] as String;
      }
    }
    return 'An error occurred';
  }
}
