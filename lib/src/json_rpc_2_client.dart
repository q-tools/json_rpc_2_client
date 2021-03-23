import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

// JsonRpc2Client is a JSON-RPC 2.0 standard compliant client.
// It is compatible with both Web and Flutter applications,
// using BrowserClient or Client, respectively, to initialize it.
//
// In case of rpc related error, it returns a JsonRpcException.
//
// Example:
//  _exampleRpcClient = new JsonRpc2Client(httpClient, _exampleURL);
//  _exampleRpcClient.sendRequest("exampleMethod", params: {"exampleParamKey": exampleParamValue})
//    .then((result) => doSomethingWithResult());
//
class JsonRpc2Client {
  final http.Client _httpClient;
  final String _serverURL;

  Map<String, String> _requestHeaders = {'Content-Type': 'application/json'};

  // Sets an header which will be sent with the next requests.
  setRequestHeader(String name, String? value) {
    if (value == null) {
      _requestHeaders.remove(name);
      return;
    }
    _requestHeaders[name] = value;
  }

  JsonRpc2Client(this._httpClient, this._serverURL);

  // Sends a JSON-RPC 2.0 Request object, using given method and params, if present.
  // A JSON-RPC 2.0 Response is a json containing:
  //  - id: A numeric identifier established by the Client, which should not be null.
  //  - jsonrpc: A String specifying the version of the JSON-RPC protocol.
  //  - method: A String containing the name of the method to be invoked.
  //  - params: A Structured value that holds the parameter values to be used
  //    during the invocation of the method.
  //
  // In case of error, returns a JsonRpcError.
  Future sendRequest(String method,
      {Map<String, Object> params: const {}}) async {
    Map<String, Object> request = {
      'id': 1,
      'jsonrpc': '2.0',
      'method': method,
      'params': params,
    };

    final http.Response response = await _executeHttpPostRequest(request);

    // A different status code means server/http error, not a json rpc error
    if (response.statusCode != 200) {
      throw HttpException(response.statusCode, response.reasonPhrase);
    }

    var bodyMap;
    try {
      bodyMap = json.decode(response.body);
    } catch (formatException) {
      throw formatException;
    }

    if (!_isValidJsonRpcResponse(bodyMap)) {
      throw FormatException("invalid JSON-RPC 2.0 response received");
    }

    if (bodyMap.containsKey('error')) {
      var errorMap = bodyMap['error'];

      throw JsonRpcError(
        errorMap['code'],
        errorMap['message'],
        (errorMap.containsKey('data') ? errorMap['data'] : null),
      );
    }

    return bodyMap['result'];
  }

  // Sends a JSON-RPC 2.0 Notification object, using given method and params, if present.
  // A JSON-RPC 2.0 Notification is a Response without the 'id' field.
  // No error or response is returned.
  Future<void> sendNotification(String method,
      {Map<String, Object> params: const {}}) async {
    Map<String, Object> notification = {
      'jsonrpc': '2.0',
      'method': method,
      'params': params,
    };

    final http.Response response = await _executeHttpPostRequest(notification);

    // A different status code means server/http error, not a json rpc error
    if (response.statusCode != 200) {
      throw HttpException(response.statusCode, response.reasonPhrase);
    }
  }

  // Validates if the received response matches the JSON-RPC 2.0 standard.
  // The response should be decoded before validation.
  bool _isValidJsonRpcResponse(Map<String, dynamic> response) {
    if (response.containsKey('jsonrpc') &&
        (response.containsKey('result') ||
            response.containsKey('error') &&
                response['error'].containsKey('code') &&
                response['error'].containsKey('message')) &&
        response.containsKey('id')) {
      return true;
    }

    return false;
  }

  Future<http.Response> _executeHttpPostRequest(Map<String, Object> payload) {
    return _httpClient.post(
      Uri.parse(_serverURL),
      headers: _requestHeaders,
      body: json.encode(payload),
    );
  }
}

// JsonRpcError is the representation of a JSON-RPC 2.0 Error.
// It contains a code which identifies the error, a message which describes it and,
// if present, data which contains additional information.
class JsonRpcError implements Exception {
  int code;
  String message;
  Object? data;

  JsonRpcError(this.code, this.message, [this.data]);

  toString() => "jsonrpc error: $code: '$message'";
}

// HttpException is the representation of an error received when
// something goes wrong with the response of an HTTP request.
// It contains the response status code and the reason phrase describing the error.
class HttpException implements Exception {
  int statusCode;
  String? reasonPhrase;

  HttpException(this.statusCode, this.reasonPhrase);

  toString() => "transport error: $statusCode $reasonPhrase";
}
