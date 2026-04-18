// lib/data/models/product.dart (исправленная версия)
import 'package:isar_community/isar.dart';

part 'product.g.dart';
//TODO: Не забыть добавить все реализаций базы в локальном UI

enum ProductClass {
  unknown(-1, 'Unknown'),
  beerBottle(0, 'Beer Bottle'),
  beerCan(1, 'Beer Can'),
  butterCube(2, 'Butter Cube'),
  chipsPack(3, 'Chips Pack'),
  energyCan(4, 'Energy Can'),
  hygieneProducts(5, 'Hygiene Products'),
  jarRounded(6, 'Jar Rounded'),
  juiceBottle(7, 'Juice Bottle'),
  juiceBox(8, 'Juice Box'),
  milkBottle(9, 'Milk Bottle'),
  milkBox(10, 'Milk Box'),
  oilBottle(11, 'Oil Bottle'),
  ramenBox(12, 'Ramen Box'),
  roundedConserve(13, 'Rounded Conserve'),
  sauceBottle(14, 'Sauce Bottle'),
  snackPack(15, 'Snack Pack'),
  sodaBottle(16, 'Soda Bottle'),
  sodaCan(17, 'Soda Can'),
  teaBox(18, 'Tea Box'),
  tobaccoBox(19, 'Tobacco Box'),
  waterBottle(20, 'Water Bottle');

  final int id;
  final String displayName;

  const ProductClass(this.id, this.displayName);

  static ProductClass fromId(int id) {
    return ProductClass.values.firstWhere(
      (c) => c.id == id,
      orElse: () => ProductClass.unknown,
    );
  }

  static ProductClass fromName(String name) {
    return ProductClass.values.firstWhere(
      (c) => c.name == name,
      orElse: () => ProductClass.unknown,
    );
  }
}

enum ProductCategory {
  unknown('Unknown'),
  beverages('Beverages'),
  snacks('Snacks'),
  pantry('Pantry'),
  instant('Instant Food'),
  household('Household'),
  dairy('Dairy'),
  other('Other');

  final String displayName;
  const ProductCategory(this.displayName);
}

extension ProductClassExtension on ProductClass {
  ProductCategory get category {
    switch (this) {
      case ProductClass.beerBottle:
      case ProductClass.beerCan:
      case ProductClass.energyCan:
      case ProductClass.juiceBottle:
      case ProductClass.juiceBox:
      case ProductClass.sodaBottle:
      case ProductClass.sodaCan:
      case ProductClass.waterBottle:
      case ProductClass.teaBox:
        return ProductCategory.beverages;

      case ProductClass.chipsPack:
      case ProductClass.snackPack:
        return ProductCategory.snacks;

      case ProductClass.butterCube:
      case ProductClass.oilBottle:
      case ProductClass.sauceBottle:
      case ProductClass.roundedConserve:
      case ProductClass.jarRounded:
        return ProductCategory.pantry;

      case ProductClass.ramenBox:
        return ProductCategory.instant;

      case ProductClass.hygieneProducts:
      case ProductClass.tobaccoBox:
        return ProductCategory.household;

      case ProductClass.milkBottle:
      case ProductClass.milkBox:
        return ProductCategory.dairy;

      default:
        return ProductCategory.other;
    }
  }

  String get iconAsset => 'assets/classes/${name}.png';
}

@collection
class Product {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String barcode;

  @Index()
  int? skuId;

  @Index()
  late String name;
  String? description;
  String? brand;

  @enumerated
  ProductClass productClass = ProductClass.unknown;

  // Категория сохраняется как отдельное поле
  @enumerated
  ProductCategory category = ProductCategory.other;

  @ignore
  List<double>? embedding;
  String? embeddingPath;

  List<String> images = [];
  String? thumbnailPath;

  // Срок годности
  DateTime? expiryDate;

  // Количество на складе (приход/уход через историю)
  int stockQuantity = 1;

  // Минимальный остаток для уведомления
  int minStockLevel = 1;

  double? price;
  String? currency;
  String? unit;
  double? weight;
  double? volume;

  List<String> tags = [];
  List<String> aliases = [];

  int scanCount = 0;
  DateTime? lastScannedAt;
  DateTime? firstScannedAt;

  String? externalUserId;
  int? languageId;
  bool isSynced = false;
  String? remoteId;

  @Index()
  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();

  @ignore
  bool get needsSync => !isSynced;

  @ignore
  bool get hasEmbedding => skuId != null;

  @ignore
  String get displayTitle =>
      brand != null && brand!.isNotEmpty ? '$brand $name' : name;

  @ignore
  String get displaySubtitle {
    final parts = <String>[];
    if (price != null && currency != null) {
      parts.add('${price!.toStringAsFixed(0)} $currency');
    }
    if (unit != null && unit != 'pc') {
      parts.add(unit!);
    }
    parts.add(productClass.displayName);
    return parts.join(' • ');
  }

  @ignore
  bool get isExpired =>
      expiryDate != null && expiryDate!.isBefore(DateTime.now());

  @ignore
  bool get isExpiringSoon =>
      expiryDate != null &&
      expiryDate!.isAfter(DateTime.now()) &&
      expiryDate!.difference(DateTime.now()).inDays <= 7;

  @ignore
  bool get isLowStock => stockQuantity <= minStockLevel;

  // Метод для автоматического обновления категории при изменении класса
  void updateCategoryFromClass() {
    category = productClass.category;
  }
}
