/// Every bundled image and icon, in one place.
///
/// Paths are plain strings, so a typo here is a runtime "unable to load asset"
/// in a release build rather than a compile error. Routing every reference
/// through this class means the editor autocompletes them, and — more usefully
/// — that the mapping from an asset *code* to a picture lives in one file
/// instead of being hard-coded at each call site.
///
/// Photographs come from Wikimedia Commons (freely licensed; see
/// `assets/ATTRIBUTION.md`) and icons are SVGs authored for this app.
class AppAssets {
  const AppAssets._();

  // ---- Photographs --------------------------------------------------------
  static const String serviceVehicle = 'assets/images/service_vehicle.jpg';
  static const String coveredCourt = 'assets/images/covered_court.jpg';
  static const String multipurposeHall = 'assets/images/multipurpose_hall.jpg';
  static const String barangayHall = 'assets/images/barangay_hall.jpg';
  static const String soundSystem = 'assets/images/sound_system.jpg';
  static const String foldingTable = 'assets/images/folding_table.jpg';
  static const String plasticChair = 'assets/images/plastic_chair.jpg';
  static const String eventTent = 'assets/images/event_tent.jpg';
  static const String projector = 'assets/images/projector.jpg';
  static const String generator = 'assets/images/generator.jpg';
  static const String basketballEquipment =
      'assets/images/basketball_equipment.jpg';

  // ---- Launcher / branding ------------------------------------------------
  /// Source of the Android launcher icon, rendered by CI.
  ///
  /// Not bundled into the Dart asset manifest on purpose: at 1024x1024 it
  /// would be dead weight in the APK. It is consumed by
  /// `flutter_launcher_icons` during the build.
  static const String launcherIconSource = 'assets/icon/app_icon_1024.png';

  static const String appIcon = 'assets/icons/app_icon.svg';
  static const String brandMark = 'assets/icons/brand_mark.svg';
  static const String logo = 'assets/icons/logo.svg';
  static const String emptyAsset = 'assets/icons/empty_asset.svg';

  static const String categoryVehicle = 'assets/icons/category_vehicle.svg';
  static const String categoryFacility = 'assets/icons/category_facility.svg';
  static const String categoryEquipment = 'assets/icons/category_equipment.svg';
  static const String categoryFurniture = 'assets/icons/category_furniture.svg';
  static const String categoryShelter = 'assets/icons/category_shelter.svg';
  static const String categoryElectronics =
      'assets/icons/category_electronics.svg';
  static const String categoryPower = 'assets/icons/category_power.svg';
  static const String categoryOther = 'assets/icons/category_other.svg';

  /// Photograph for a demo record, keyed on its asset code.
  ///
  /// The mapping is **exact** and deliberately short: a picture of a folding
  /// table next to a box of cables would be worse than a category icon. Codes
  /// that are not listed return null, and the UI falls back to the category
  /// glyph. The demo seed uses a `BRGY-` prefix, which is stripped first.
  static String? photoForAssetCode(String assetCode) {
    var code = assetCode.trim().toUpperCase();
    if (code.startsWith('BRGY-')) code = code.substring(5);
    return switch (code) {
      'VEH-001' => serviceVehicle,
      'FAC-001' => coveredCourt,
      'FAC-002' => multipurposeHall,
      'EQP-001' => soundSystem,
      'FUR-001' => plasticChair,
      'FUR-002' => foldingTable,
      'SHL-001' => eventTent,
      'ELE-001' => projector,
      'PWR-001' => generator,
      _ => null,
    };
  }

  /// Icon for an asset category, given the category's wire value
  /// (`vehicle`, `facility`, ...).
  static String iconForCategory(String? categoryWire) =>
      switch (categoryWire) {
        'vehicle' => categoryVehicle,
        'facility' => categoryFacility,
        'equipment' => categoryEquipment,
        'furniture' => categoryFurniture,
        'shelter' => categoryShelter,
        'electronics' => categoryElectronics,
        'power' => categoryPower,
        _ => categoryOther,
      };
}