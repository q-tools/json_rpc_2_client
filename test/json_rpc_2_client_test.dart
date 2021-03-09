import 'dart:convert';

import 'package:http/http.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:json_rpc_2_client/src/json_rpc_2_client.dart';

import 'json_rpc_2_client_test.mocks.dart';

@GenerateMocks([Client])
void main() {
  const String mockMethod = "mock-method";
  const String mockServerURL = "https://mock-url.net/";
  const Map<String, Object> mockParamsMap = {"mockKey": "mockValue"};
  const Map<String, String> mockHeadersMap = {
    'Content-Type': 'application/json'
  };

  String validResponseJson() =>
      '{"jsonrpc":"2.0","result":[{"ID":"5baa67721752be0001669f73","createdAtISO8601":"2018-09-25T16:50:58.064Z","officeID":"QQST000000051"}],"id":1}';
  String malformedResponseJson() =>
      '{"jsonrpc":"2.0result":[{"ID":"5baa67721752be0001669f73","createdAtISO8601":"2018-09-25T16:50:58.064Z","officeID":"QQST000000051"}],"id":1}';
  String erroredResponseJson() =>
      '{"jsonrpc":"2.0","error":{"code":-32000,"message":"Server error"},"id":1}';
  String invalidJsonRpc2ResponseJson() =>
      '{"jso3nrpc":"2.0","erdror":{"code":-32000,"message":"Server error"},"id":1}';

  Map<String, Object> validRequestObjectMap() => {
        "id": 1,
        "jsonrpc": "2.0",
        "method": "mock-method",
        "params": {"mockKey": "mockValue"},
      };
  Map<String, Object> validNotificationObjectMap() => {
        "jsonrpc": "2.0",
        "method": "mock-method",
        "params": {"mockKey": "mockValue"},
      };

  final MockClient httpClient = MockClient();
  late JsonRpc2Client sut;

  setUp(() {
    sut = JsonRpc2Client(httpClient, mockServerURL);
  });

  group('JsonRpc2Client', () {
    test('Test that JsonRpc2Client uses headers set manually', () async {
      when(httpClient.post(any,
              headers: anyNamed("headers"), body: anyNamed("body")))
          .thenAnswer((_) async => Response(validResponseJson(), 200));

      sut.setRequestHeader("newHeader", "newHeaderValue");

      await sut.sendRequest(mockMethod, params: mockParamsMap);

      Map<String, String> expectedHeaders = new Map<String, String>();
      expectedHeaders..addAll(mockHeadersMap);
      expectedHeaders["newHeader"] = "newHeaderValue";

      verify(httpClient.post(Uri.parse(mockServerURL),
          headers: expectedHeaders,
          body: json.encode(validRequestObjectMap())));
    });

    test('Test that JsonRpc2Client sends a valid notification object',
        () async {
      when(httpClient.post(any,
              headers: anyNamed("headers"), body: anyNamed("body")))
          .thenAnswer((_) async => Response(validResponseJson(), 200));

      await sut.sendNotification(mockMethod, params: mockParamsMap);

      verify(httpClient.post(Uri.parse(mockServerURL),
          headers: mockHeadersMap,
          body: json.encode(validNotificationObjectMap())));
    });

    test('Test that JsonRpc2Client sends a valid request object', () async {
      when(httpClient.post(any,
              headers: anyNamed("headers"), body: anyNamed("body")))
          .thenAnswer((_) async => Response(validResponseJson(), 200));

      await sut.sendRequest(mockMethod, params: mockParamsMap);

      verify(httpClient.post(Uri.parse(mockServerURL),
          headers: mockHeadersMap, body: json.encode(validRequestObjectMap())));
    });

    test(
        'Test that JsonRpc2Client returns a valid result when a valid response is received from server',
        () async {
      when(httpClient.post(any,
              headers: anyNamed("headers"), body: anyNamed("body")))
          .thenAnswer((_) async => Response(validResponseJson(), 200));

      var responseJson =
          await sut.sendRequest(mockMethod, params: mockParamsMap);

      var expectedResult = [
        {
          "ID": "5baa67721752be0001669f73",
          "createdAtISO8601": "2018-09-25T16:50:58.064Z",
          "officeID": "QQST000000051"
        }
      ];

      expect(responseJson, equals(expectedResult));
    });

    test(
        'Test that JsonRpc2Client throws a FormatException when a malformed response is received',
        () async {
      when(httpClient.post(any,
              headers: anyNamed("headers"), body: anyNamed("body")))
          .thenAnswer((_) async => Response(malformedResponseJson(), 200));

      expect(() => sut.sendRequest(mockMethod, params: mockParamsMap),
          throwsFormatException);
    });

    test(
        'Test that JsonRpc2Client throws a FormatException when an invalid JSON-RPC 2.0 response is received',
        () async {
      when(httpClient.post(any,
              headers: anyNamed("headers"), body: anyNamed("body")))
          .thenAnswer(
              (_) async => Response(invalidJsonRpc2ResponseJson(), 200));

      expect(() => sut.sendRequest(mockMethod, params: mockParamsMap),
          throwsFormatException);
    });

    test(
        'Test that JsonRpc2Client throws a HttpException if something goes wrong during http request when sending a Request Object',
        () async {
      when(httpClient.post(any,
              headers: anyNamed("headers"), body: anyNamed("body")))
          .thenAnswer((_) async => Response(malformedResponseJson(), 500));

      expect(() => sut.sendRequest(mockMethod, params: mockParamsMap),
          throwsA(TypeMatcher<HttpException>()));
    });

    test(
        'Test that JsonRpc2Client throws a HttpException if something goes wrong during http request when sending a Notification Object',
        () async {
      when(httpClient.post(any,
              headers: anyNamed("headers"), body: anyNamed("body")))
          .thenAnswer((_) async => Response("", 500));

      expect(() => sut.sendNotification(mockMethod, params: mockParamsMap),
          throwsA(TypeMatcher<HttpException>()));
    });

    test(
        'Test that JsonRpc2Client throws a JsonRpcError when an errored jsonrpc response is received',
        () async {
      when(httpClient.post(any,
              headers: anyNamed("headers"), body: anyNamed("body")))
          .thenAnswer((_) async => Response(erroredResponseJson(), 200));

      expect(() => sut.sendRequest(mockMethod, params: mockParamsMap),
          throwsA(TypeMatcher<JsonRpcError>()));
    });
  });
}
