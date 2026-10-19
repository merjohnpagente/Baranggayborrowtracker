# Barangay Borrow Tracker — Image Assets

This package contains image files cropped from the generated visual asset concept sheet. They are illustrative UI/demo assets, not official barangay photographs or government branding. Review image quality and replace with approved local photographs before production use.

## Included
- `assets/images/`: sample facility, vehicle, and equipment photographs; default images; logo/splash concept; background images.
- `assets/icons/`: simple category icon PNGs and a UI icon reference sheet.

## Add to Flutter
Copy the `assets/` folder into the root of your Flutter project, beside `lib/` and `pubspec.yaml`. Add this to `pubspec.yaml` under the top-level `flutter:` key:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/images/
    - assets/icons/
```

Then run in GitHub Actions or any Flutter environment:

```bash
flutter pub get
```

## Example
```dart
Image.asset(
  'assets/images/service_vehicle.jpg',
  fit: BoxFit.cover,
  errorBuilder: (context, error, stackTrace) =>
      Image.asset('assets/images/default_asset.jpg', fit: BoxFit.cover),
)
```

Note: this ZIP contains actual cropped image files, not the complete Flutter source code. The generated collage itself is not a set of full-resolution original photographs, so use it as a prototype pack and replace images with locally approved high-quality images for a production app.
