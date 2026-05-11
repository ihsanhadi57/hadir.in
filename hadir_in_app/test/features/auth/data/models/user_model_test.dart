import 'package:flutter_test/flutter_test.dart';
import 'package:hadir_in_app/features/auth/data/models/user_model.dart';

void main() {
  group('UserModel', () {
    final tUserModel = const UserModel(
      id: '123',
      name: 'Test User',
      email: 'test@example.com',
      role: 'organizer',
      emailQuota: 100,
      totalEmailsSent: 10,
      avatarUrl: 'https://example.com/avatar.png',
    );

    test('should be a valid model', () {
      expect(tUserModel, isA<UserModel>());
      expect(tUserModel.name, 'Test User');
    });

    group('fromJson', () {
      test('should return a valid model when JSON is valid', () {
        // arrange
        final Map<String, dynamic> jsonMap = {
          'id': '123',
          'name': 'Test User',
          'email': 'test@example.com',
          'role': 'organizer',
          'emailQuota': 100,
          'totalEmailsSent': 10,
          'avatarUrl': 'https://example.com/avatar.png',
        };
        // act
        final result = UserModel.fromJson(jsonMap);
        // assert
        expect(result.id, tUserModel.id);
        expect(result.name, tUserModel.name);
        expect(result.email, tUserModel.email);
        expect(result.emailQuota, tUserModel.emailQuota);
        expect(result.avatarUrl, tUserModel.avatarUrl);
      });

      test('should handle missing or null fields gracefully with default values', () {
        // arrange
        final Map<String, dynamic> jsonMap = {
          'email': 'test@example.com',
          // name, id, and others are missing
        };
        // act
        final result = UserModel.fromJson(jsonMap);
        // assert
        expect(result.id, '');
        expect(result.name, '');
        expect(result.email, 'test@example.com');
        expect(result.role, 'organizer');
        expect(result.emailQuota, 50); // Default is 50
        expect(result.totalEmailsSent, 0); // Default is 0
        expect(result.avatarUrl, null);
      });
    });

    group('toJson', () {
      test('should return a JSON map containing the proper data', () {
        // act
        final result = tUserModel.toJson();
        // assert
        final expectedMap = {
          'id': '123',
          'name': 'Test User',
          'email': 'test@example.com',
          'role': 'organizer',
          'emailQuota': 100,
          'totalEmailsSent': 10,
          'avatarUrl': 'https://example.com/avatar.png',
        };
        expect(result, expectedMap);
      });
    });

    group('copyWith', () {
      test('should return a new model with updated properties', () {
        // act
        final result = tUserModel.copyWith(
          name: 'Updated Name',
          emailQuota: 200,
        );
        // assert
        expect(result.name, 'Updated Name');
        expect(result.emailQuota, 200);
        // Ensure other properties remain unchanged
        expect(result.id, tUserModel.id);
        expect(result.email, tUserModel.email);
      });
    });
  });
}
