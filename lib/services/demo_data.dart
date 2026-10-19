import '../models/asset.dart';
import '../models/booking.dart';
import '../models/transaction.dart';

/// **DEMO DATA — NOT REAL BARANGAY RECORDS.**
///
/// This is used only when the app is started without Supabase credentials (see
/// `AppConfig.isConfigured`). Every screen that renders these values shows a
/// "Demo data" banner, and nothing here is ever written back to a database.
///
/// It exists so the app is reviewable and usable before anyone has created a
/// Supabase project. It is not a seed script and must not be presented as
/// production data.
class DemoData {
  DemoData._();

  static const DateTime _now = DateTime(2026, 5, 12, 9, 0);

  static DateTime get _today => _now;

  static DateTime _day(int offset, [int hour = 8, int minute = 0]) =>
      DateTime(_now.year, _now.month, _now.day + offset, hour, minute);

  static const _vehicleImg =
      'https://images.unsplash.com/photo-1550355291-bbee04a92027?w=800';
  static const _courtImg =
      'https://images.unsplash.com/photo-1546519638-68e109498ffc?w=800';
  static const _hallImg =
      'https://images.unsplash.com/photo-1517457373958-b7bdd4587205?w=800';
  static const _soundImg =
      'https://images.unsplash.com/photo-1524368535928-5b5e00ddc76b?w=800';
  static const _tentImg =
      'https://images.unsplash.com/photo-1533174072545-7a4b6ad7a6c3?w=800';
  static const _projectorImg =
      'https://images.unsplash.com/photo-1516035069371-29a1b244cc32?w=800';
  static const _generatorImg =
      'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800';

  static final List<Asset> assets = [
    Asset(
      id: 'veh-001',
      assetCode: 'VEH-001',
      name: 'Toyota Hilux (Service Vehicle)',
      category: AssetCategory.vehicle,
      description:
          'Used for official barangay activities and emergency response.',
      imageUrls: const [_vehicleImg],
      location: 'Barangay Hall',
      quantity: 1,
      condition: AssetCondition.good,
      status: AssetStatus.available,
      plateNumber: 'ABC 1234',
      createdAt: _day(-120),
    ),
    Asset(
      id: 'fac-001',
      assetCode: 'FAC-001',
      name: 'Covered Basketball Court',
      category: AssetCategory.facility,
      description:
          'Covered court available for basketball practice and tournaments.',
      imageUrls: const [_courtImg],
      location: 'Barangay Sports Complex',
      quantity: 1,
      condition: AssetCondition.good,
      status: AssetStatus.available,
      createdAt: _day(-200),
    ),
    Asset(
      id: 'eqp-001',
      assetCode: 'EQP-001',
      name: 'Sound System',
      category: AssetCategory.equipment,
      description:
          'Two-way speakers with wireless microphone, used for assemblies.',
      imageUrls: const [_soundImg],
      location: 'Barangay Hall',
      quantity: 1,
      condition: AssetCondition.serviceable,
      status: AssetStatus.borrowed,
      createdAt: _day(-90),
    ),
    Asset(
      id: 'eqp-002',
      assetCode: 'EQP-002',
      name: 'Folding Table',
      category: AssetCategory.furniture,
      description: 'Six-foot folding table with plastic cover.',
      imageUrls: const [
        'https://images.unsplash.com/photo-1533090481720-856c6e3c1fdc?w=800',
      ],
      location: 'Barangay Hall Storage',
      quantity: 12,
      condition: AssetCondition.good,
      status: AssetStatus.available,
      createdAt: _day(-180),
    ),
    Asset(
      id: 'eqp-003',
      assetCode: 'EQP-003',
      name: 'Tent / Canopy',
      category: AssetCategory.shelter,
      description: 'Pavilion tent for community events and evacuation.',
      imageUrls: const [_tentImg],
      location: 'Barangay Hall Storage',
      quantity: 2,
      condition: AssetCondition.good,
      status: AssetStatus.available,
      createdAt: _day(-150),
    ),
    Asset(
      id: 'eqp-004',
      assetCode: 'EQP-004',
      name: 'Projector',
      category: AssetCategory.electronics,
      description: '3500-lumen projector with HDMI and VGA cables.',
      imageUrls: const [_projectorImg],
      location: 'Barangay Hall',
      quantity: 1,
      condition: AssetCondition.good,
      status: AssetStatus.available,
      createdAt: _day(-60),
    ),
    Asset(
      id: 'eqp-005',
      assetCode: 'EQP-005',
      name: 'Generator',
      category: AssetCategory.power,
      description: '5 kVA diesel generator for power interruptions.',
      imageUrls: const [_generatorImg],
      location: 'Barangay Hall',
      quantity: 1,
      condition: AssetCondition.minorDamage,
      status: AssetStatus.maintenance,
      maintenanceNote: 'Scheduled for servicing — oil change pending.',
      createdAt: _day(-240),
    ),
    Asset(
      id: 'fac-002',
      assetCode: 'FAC-002',
      name: 'Multipurpose Hall',
      category: AssetCategory.facility,
      description: 'Indoor hall for assemblies, weddings and events.',
      imageUrls: const [_hallImg],
      location: 'Barangay Center',
      quantity: 1,
      condition: AssetCondition.good,
      status: AssetStatus.reserved,
      createdAt: _day(-300),
    ),
    Asset(
      id: 'eqp-006',
      assetCode: 'EQP-006',
      name: 'Plastic Chair',
      category: AssetCategory.furniture,
      description: 'Stackable plastic chair for events.',
      imageUrls: const [
        'https://images.unsplash.com/photo-1503602642458-232111445657?w=800',
      ],
      location: 'Barangay Hall Storage',
      quantity: 200,
      condition: AssetCondition.good,
      status: AssetStatus.available,
      createdAt: _day(-170),
    ),
    Asset(
      id: 'eqp-007',
      assetCode: 'EQP-007',
      name: 'Wireless Microphone',
      category: AssetCategory.equipment,
      description: 'Handheld UHF wireless microphone with receiver.',
      imageUrls: const [
        'https://images.unsplash.com/photo-1590602847861-f357a9332bbc?w=800',
      ],
      location: 'Barangay Hall',
      quantity: 4,
      condition: AssetCondition.good,
      status: AssetStatus.available,
      createdAt: _day(-80),
    ),
  ];

  static final List<Booking> bookings = [
    Booking(
      id: 'bk-1001',
      requestId: 'BRW-1001',
      assetId: 'veh-001',
      assetName: 'Toyota Hilux (Service Vehicle)',
      assetCode: 'VEH-001',
      borrowerId: 'demo-resident-1',
      borrowerName: 'Juan Dela Cruz',
      borrowerPhone: '0917 000 0001',
      purpose: 'Barangay Outreach Program',
      startTime: _day(1, 8),
      endTime: _day(1, 17),
      expectedReturnTime: _day(1, 17),
      authorizedDriverName: 'Juan Dela Cruz',
      status: BookingStatus.pending,
      submittedAt: _day(0, 7, 30),
    ),
    Booking(
      id: 'bk-1002',
      requestId: 'BRW-1002',
      assetId: 'fac-002',
      assetName: 'Multipurpose Hall',
      assetCode: 'FAC-002',
      borrowerId: 'demo-resident-2',
      borrowerName: 'Maria Santos',
      purpose: 'Barangay Sports Event',
      startTime: _day(2, 13),
      endTime: _day(2, 18),
      expectedReturnTime: _day(2, 18),
      status: BookingStatus.pending,
      submittedAt: _day(0, 8, 15),
    ),
    Booking(
      id: 'bk-1003',
      requestId: 'BRW-1003',
      assetId: 'fac-001',
      assetName: 'Covered Basketball Court',
      assetCode: 'FAC-001',
      borrowerId: 'demo-resident-3',
      borrowerName: 'Pedro Reyes',
      purpose: 'Barangay Sports Event',
      startTime: _day(1, 10),
      endTime: _day(1, 18),
      expectedReturnTime: _day(1, 18),
      status: BookingStatus.approved,
      approvedBy: 'demo-staff-1',
      approvedByName: 'Admin User',
      approvedAt: _day(0, 9),
      submittedAt: _day(-1, 16),
    ),
    Booking(
      id: 'bk-1004',
      requestId: 'BRW-1004',
      assetId: 'eqp-001',
      assetName: 'Sound System',
      assetCode: 'EQP-001',
      borrowerId: 'demo-resident-4',
      borrowerName: 'Ana Cruz',
      purpose: 'Barangay Assembly',
      startTime: _day(-1, 8),
      endTime: _day(-1, 12),
      expectedReturnTime: _day(0, 12),
      status: BookingStatus.released,
      approvedBy: 'demo-staff-1',
      approvedByName: 'Admin User',
      approvedAt: _day(-2, 10),
      submittedAt: _day(-3, 9),
      releasedAt: _day(-1, 8),
    ),
    Booking(
      id: 'bk-1005',
      requestId: 'BRW-1005',
      assetId: 'eqp-003',
      assetName: 'Tent / Canopy',
      assetCode: 'EQP-003',
      borrowerId: 'demo-resident-5',
      borrowerName: 'Liza Fernandez',
      purpose: 'Sangguniang Kabataan Event',
      startTime: _day(3, 8),
      endTime: _day(3, 20),
      expectedReturnTime: _day(3, 20),
      status: BookingStatus.approved,
      approvedBy: 'demo-approver-1',
      approvedByName: 'Approver User',
      approvedAt: _day(0, 11),
      submittedAt: _day(0, 9),
    ),
    Booking(
      id: 'bk-1006',
      requestId: 'BRW-1006',
      assetId: 'eqp-004',
      assetName: 'Folding Table',
      assetCode: 'EQP-002',
      borrowerId: 'demo-resident-6',
      borrowerName: 'Carlo Mendoza',
      purpose: 'Community Feeding Program',
      startTime: _day(-6, 7),
      endTime: _day(-6, 18),
      expectedReturnTime: _day(-5, 18),
      status: BookingStatus.completed,
      approvedBy: 'demo-staff-1',
      approvedByName: 'Admin User',
      approvedAt: _day(-7, 10),
      submittedAt: _day(-8, 9),
      releasedAt: _day(-6, 7),
      returnedAt: _day(-5, 17),
    ),
  ];

  static final List<AssetTransaction> transactions = [
    AssetTransaction(
      id: 'tx-5001',
      bookingId: 'bk-1004',
      assetId: 'eqp-001',
      assetName: 'Sound System',
      assetCode: 'EQP-001',
      borrowerId: 'demo-resident-4',
      borrowerName: 'Ana Cruz',
      bookingCode: 'BRW-1004',
      releasedBy: 'demo-staff-1',
      releasedByName: 'Admin User',
      releasedAt: _day(-1, 8),
      initialCondition: 'good',
      includedItems: const ['2x speaker', '1x wireless mic', '1x tripod'],
      expectedReturnAt: _day(0, 12),
      returnStatus: TransactionReturnStatus.open,
    ),
    AssetTransaction(
      id: 'tx-5002',
      bookingId: 'bk-1006',
      assetId: 'eqp-004',
      assetName: 'Folding Table',
      assetCode: 'EQP-002',
      borrowerId: 'demo-resident-6',
      borrowerName: 'Carlo Mendoza',
      bookingCode: 'BRW-1006',
      releasedBy: 'demo-staff-1',
      releasedByName: 'Admin User',
      releasedAt: _day(-6, 7),
      initialCondition: 'good',
      returnedTo: 'demo-staff-1',
      returnedToName: 'Admin User',
      returnedAt: _day(-5, 17),
      returnCondition: 'good',
      expectedReturnAt: _day(-5, 18),
      returnStatus: TransactionReturnStatus.completed,
    ),
    AssetTransaction(
      id: 'tx-5003',
      bookingId: 'bk-0998',
      assetId: 'eqp-002',
      assetName: 'Folding Table',
      assetCode: 'EQP-002',
      borrowerId: 'demo-resident-7',
      borrowerName: 'Rosa Lim',
      bookingCode: 'BRW-0998',
      releasedBy: 'demo-staff-1',
      releasedByName: 'Admin User',
      releasedAt: _day(-12, 8),
      initialCondition: 'serviceable',
      returnedTo: 'demo-staff-1',
      returnedToName: 'Admin User',
      returnedAt: _day(-11, 16),
      returnCondition: 'minor_damage',
      damageNotes: 'One table has a scratch on the tabletop.',
      expectedReturnAt: _day(-11, 18),
      returnStatus: TransactionReturnStatus.flagged,
      flaggedForInspection: true,
    ),
  ];

  static final List<MaintenanceRecord> maintenance = [
    MaintenanceRecord(
      id: 'mr-01',
      assetId: 'eqp-005',
      assetName: 'Generator',
      assetCode: 'EQP-005',
      issueDescription: 'Scheduled servicing — oil and filter change.',
      status: MaintenanceStatus.inProgress,
      reportedAt: _day(-4),
      reportedByName: 'Admin User',
    ),
  ];
}