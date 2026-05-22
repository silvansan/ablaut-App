import 'package:ablaut_app/services/app_update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizeReleaseVersion strips leading v', () {
    expect(normalizeReleaseVersion('v0.3.1'), '0.3.1');
  });

  test('compareAppVersions orders semver values', () {
    expect(compareAppVersions('0.3.0', '0.3.1'), lessThan(0));
    expect(compareAppVersions('0.3.1', '0.3.0'), greaterThan(0));
    expect(compareAppVersions('0.3.0', '0.3.0'), 0);
  });

  test('compareAppVersions ignores build suffix', () {
    expect(compareAppVersions('0.3.0+3', '0.3.0+9'), 0);
  });
}
