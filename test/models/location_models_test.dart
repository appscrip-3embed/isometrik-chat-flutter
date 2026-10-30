import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Covers every model under `lib/src/models/location_models/`:
/// [IsmChatLatLongModel], [IsmChatViewportModel], [IsmChatGeometry],
/// [IsmChatMatchedSubstring], [IsmChatTerm], [IsmChatStructuredFormatting]
/// and [IsmChatPrediction] (Google Places responses).
void main() {
  final northeast = IsmChatLatLongModel(lat: 13.0, lng: 78.0);
  final southwest = IsmChatLatLongModel(lat: 12.0, lng: 77.0);
  final viewport =
      IsmChatViewportModel(northeast: northeast, southwest: southwest);
  final geometry = IsmChatGeometry(location: southwest, viewport: viewport);

  group('IsmChatLatLongModel', () {
    test('map / json round-trip, latlng getter, copyWith', () {
      final model = IsmChatLatLongModel.fromJson(northeast.toJson());
      expect(model, northeast);
      expect(model.hashCode, northeast.hashCode);
      expect(model.toMap(), {'lat': 13.0, 'lng': 78.0});
      expect(model.latlng, const LatLng(13.0, 78.0));
      expect(model.copyWith(), model);
      expect(model.copyWith(lat: 1, lng: 2),
          IsmChatLatLongModel(lat: 1, lng: 2));
      expect(identical(model, model) && model == model, isTrue);
      expect(model.toString(), 'LatLongModel(lat: 13.0, lng: 78.0)');
    });
  });

  group('IsmChatViewportModel', () {
    test('map / json round-trip, copyWith, equality', () {
      final model = IsmChatViewportModel.fromJson(viewport.toJson());
      expect(model, viewport);
      expect(model == model, isTrue);
      expect(model.hashCode, viewport.hashCode);
      expect(model.copyWith(), viewport);
      expect(model.copyWith(northeast: southwest, southwest: northeast),
          isNot(viewport));
      expect(model.toString(), contains('ViewportModle('));
    });
  });

  group('IsmChatGeometry', () {
    test('full map / json round-trip', () {
      final model = IsmChatGeometry.fromJson(geometry.toJson());
      expect(model, geometry);
      expect(model == model, isTrue);
      expect(model.hashCode, geometry.hashCode);
      expect(model.toString(), contains('Geometry(location:'));
    });

    test('empty map gives null fields; copyWith fills them', () {
      final empty = IsmChatGeometry.fromMap({});
      expect(empty.location, isNull);
      expect(empty.viewport, isNull);
      expect(empty.toMap(), isEmpty);
      expect(empty.copyWith(), empty);
      expect(empty.copyWith(location: southwest, viewport: viewport),
          geometry);
    });
  });

  group('IsmChatMatchedSubstring / IsmChatTerm', () {
    test('MatchedSubstring full and empty maps', () {
      final model = IsmChatMatchedSubstring(length: 3, offset: 1);
      final copy = IsmChatMatchedSubstring.fromJson(model.toJson());
      expect(copy, model);
      expect(copy == copy, isTrue);
      expect(copy.hashCode, model.hashCode);
      expect(copy.toString(), 'MatchedSubstring(length: 3, offset: 1)');
      final empty = IsmChatMatchedSubstring.fromMap({});
      expect(empty.length, isNull);
      expect(empty.offset, isNull);
      expect(empty.copyWith(), empty);
      expect(empty.copyWith(length: 3, offset: 1), model);
    });

    test('Term full and empty maps', () {
      final model = IsmChatTerm(offset: 2, value: 'MG Road');
      final copy = IsmChatTerm.fromJson(model.toJson());
      expect(copy, model);
      expect(copy == copy, isTrue);
      expect(copy.hashCode, model.hashCode);
      expect(copy.toString(), 'Term(offset: 2, value: MG Road)');
      final empty = IsmChatTerm.fromMap({});
      expect(empty.value, isNull);
      expect(empty.copyWith(), empty);
      expect(empty.copyWith(offset: 2, value: 'MG Road'), model);
    });
  });

  group('IsmChatStructuredFormatting', () {
    test('scalar fields round-trip; copyWith; equality', () {
      final model = IsmChatStructuredFormatting(
        mainText: 'Office',
        secondaryText: 'Bangalore',
        matchedString: [IsmChatMatchedSubstring(length: 1, offset: 0)],
      );
      expect(model.toMap()['matchedString'], [
        {'length': 1, 'offset': 0}
      ]);
      final scalar = IsmChatStructuredFormatting.fromMap(
          {'mainText': 'Office', 'secondaryText': 'Bangalore'});
      expect(scalar.copyWith(matchedString: model.matchedString), model);
      expect(model == model, isTrue);
      expect(model.hashCode, isA<int>());
      expect(model.toString(), contains('StructuredFormatting(mainText'));
      expect(scalar.copyWith(), scalar);
      final empty = IsmChatStructuredFormatting.fromJson('{}');
      expect(empty.mainText, isNull);
      expect(empty.secondaryText, isNull);
      expect(empty.matchedString, isNull);
    });

    // BUG: fromMap casts `matchedString` to `List<int>`, so any JSON list
    // (List<dynamic>) throws. Only a typed List<int> passes the cast, and
    // then each element fails the `Map` cast.
    test('matchedString parsing is broken for real JSON (documented bug)', () {
      expect(
        () => IsmChatStructuredFormatting.fromJson(
            IsmChatStructuredFormatting(
              matchedString: [IsmChatMatchedSubstring(length: 1, offset: 0)],
            ).toJson()),
        throwsA(isA<TypeError>()),
      );
      expect(
        IsmChatStructuredFormatting.fromMap({'matchedString': <int>[]})
            .matchedString,
        isEmpty,
      );
      expect(
        () => IsmChatStructuredFormatting.fromMap({
          'matchedString': <int>[1]
        }),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('IsmChatPrediction', () {
    Map<String, dynamic> placeMap() => {
          'description': 'Office, MG Road',
          'placeId': 'place-1',
          'reference': 'ref-1',
          'structuredFormatting': {'mainText': 'Office'},
          'types': ['establishment'],
          'geometry': geometry.toMap(),
          'distance': 1.5,
          'businessStatus': 'OPERATIONAL',
          'icon': 'icon.png',
          'iconBackgroundColor': '#fff',
          'iconMaskBaseUri': 'mask',
          'name': 'Office',
          'rating': 4.5,
          'scope': 'GOOGLE',
          'userRatingsTotal': 10,
          'vicinity': 'Bangalore',
        };

    test('fromMap reads every scalar field', () {
      final model = IsmChatPrediction.fromMap(placeMap());
      expect(model.description, 'Office, MG Road');
      expect(model.placeId, 'place-1');
      expect(model.reference, 'ref-1');
      expect(model.structuredFormatting?.mainText, 'Office');
      expect(model.types, ['establishment']);
      expect(model.geometry, geometry);
      expect(model.distance, 1.5);
      expect(model.businessStatus, 'OPERATIONAL');
      expect(model.icon, 'icon.png');
      expect(model.iconBackgroundColor, '#fff');
      expect(model.iconMaskBaseUri, 'mask');
      expect(model.name, 'Office');
      expect(model.rating, 4.5);
      expect(model.scope, 'GOOGLE');
      expect(model.userRatingsTotal, 10);
      expect(model.vicinity, 'Bangalore');
      expect(model.toString(), startsWith('Prediction(description:'));
      expect(model == model, isTrue);
      expect(model.hashCode, isA<int>());
    });

    test('fromMap with latlng computes the distance to the location', () {
      final model = IsmChatPrediction.fromMap(placeMap(),
          latlng: const LatLng(12.0, 77.0));
      expect(model.distance, 0);
    });

    test('empty map gives null fields', () {
      final model = IsmChatPrediction.fromMap({});
      expect(model.description, isNull);
      expect(model.matchedSubstrings, isNull);
      expect(model.terms, isNull);
      expect(model.types, isNull);
      expect(model.geometry, isNull);
      expect(model.distance, isNull);
      expect(model.rating, isNull);
    });

    test('toMap / toJson with terms, copyWith and equality', () {
      final model = IsmChatPrediction.fromMap(placeMap()).copyWith(
        matchedSubstrings: [IsmChatMatchedSubstring(length: 1, offset: 0)],
        terms: [IsmChatTerm(offset: 0, value: 'Office')],
      );
      expect(model.toMap()['terms'], [
        {'offset': 0, 'value': 'Office'}
      ]);
      expect(model.toJson(), contains('"placeId":"place-1"'));
      final copy = model.copyWith();
      expect(copy, model);
      final changed = model.copyWith(
        description: 'd',
        placeId: 'p',
        reference: 'r',
        structuredFormatting: IsmChatStructuredFormatting(mainText: 'm'),
        types: ['t'],
        geometry: IsmChatGeometry(),
        distance: 9,
        businessStatus: 'b',
        icon: 'i',
        iconBackgroundColor: 'c',
        iconMaskBaseUri: 'u',
        name: 'n',
        rating: 1,
        scope: 's',
        userRatingsTotal: 1,
        vicinity: 'v',
      );
      expect(changed == model, isFalse);
      expect(changed.vicinity, 'v');
    });

    // BUG: toMap force-unwraps `terms`, so a prediction without terms
    // cannot be serialised.
    test('toMap throws when terms is null (documented bug)', () {
      expect(() => IsmChatPrediction(rating: null).toMap(),
          throwsA(isA<TypeError>()));
    });

    // BUG: like IsmChatStructuredFormatting, the list fields are cast to
    // `List<int>`, so real JSON lists cannot be parsed. fromJson therefore
    // only works when those keys are absent.
    test('matchedSubstrings / terms parsing is broken (documented bug)', () {
      expect(
        IsmChatPrediction.fromJson('{"placeId":"p"}').placeId,
        'p',
      );
      expect(
        () => IsmChatPrediction.fromJson('{"terms":[{"offset":0}]}'),
        throwsA(isA<TypeError>()),
      );
      final typed = IsmChatPrediction.fromMap({
        'matchedSubstrings': <int>[],
        'terms': <int>[],
      });
      expect(typed.matchedSubstrings, isEmpty);
      expect(typed.terms, isEmpty);
      expect(
        () => IsmChatPrediction.fromMap({'matchedSubstrings': <int>[1]}),
        throwsA(isA<TypeError>()),
      );
      expect(
        () => IsmChatPrediction.fromMap({'terms': <int>[1]}),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
