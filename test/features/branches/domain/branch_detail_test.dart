import 'package:flutter_test/flutter_test.dart';
import 'package:vz_food/features/branches/domain/branch_detail.dart';

void main() {
  group('BranchDetailPayload.fromJson', () {
    test('parses a fully populated branch', () {
      final payload = BranchDetailPayload.fromJson({
        'branch': {
          'id': 'branch-1',
          'name': 'Centro',
          'heroImageUrl': 'https://cdn.test/branch.jpg',
          'addressLine1': 'Av. Principal 123',
          'city': 'Caracas',
          'state': 'Distrito Capital',
          'postalCode': '1010',
          'countryCode': 'VE',
          'latitude': 10.5,
          'longitude': -66.9,
          'isActive': true,
          'storefrontHref': 'https://vzfood.test/app/acme?branch=branch-1',
          'tenant': {
            'id': 'tenant-1',
            'name': 'Acme',
            'slug': 'acme',
            'logoImageUrl': 'https://cdn.test/logo.png',
            'heroImageUrl': null,
            'storefrontEnabled': true,
          },
        },
      });

      final branch = payload.branch;
      expect(branch.id, 'branch-1');
      expect(branch.latitude, 10.5);
      expect(branch.longitude, -66.9);
      expect(
        branch.locationLabel,
        'Av. Principal 123, Caracas, Distrito Capital',
      );
      expect(branch.tenant.slug, 'acme');
      expect(branch.canOpenStorefront, isTrue);
    });

    test('defaults missing fields safely', () {
      final payload = BranchDetailPayload.fromJson(const {});

      final branch = payload.branch;
      expect(branch.id, '');
      expect(branch.name, '');
      expect(branch.latitude, isNull);
      expect(branch.longitude, isNull);
      expect(branch.isActive, isFalse);
      expect(branch.locationLabel, '');
      expect(branch.tenant.storefrontEnabled, isFalse);
      expect(branch.canOpenStorefront, isFalse);
    });

    test('canOpenStorefront is false when active but storefront disabled', () {
      final payload = BranchDetailPayload.fromJson({
        'branch': {
          'id': 'branch-1',
          'name': 'Centro',
          'isActive': true,
          'tenant': {
            'id': 'tenant-1',
            'name': 'Acme',
            'slug': 'acme',
            'storefrontEnabled': false,
          },
        },
      });

      expect(payload.branch.isActive, isTrue);
      expect(payload.branch.canOpenStorefront, isFalse);
    });

    test('locationLabel skips blank address parts', () {
      final payload = BranchDetailPayload.fromJson({
        'branch': {
          'id': 'branch-1',
          'name': 'Centro',
          'addressLine1': '  ',
          'city': 'Caracas',
          'state': null,
          'tenant': {'id': 't', 'name': 'Acme', 'slug': 'acme'},
        },
      });

      expect(payload.branch.locationLabel, 'Caracas');
    });
  });
}
