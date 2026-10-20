class Product {
  const Product({
    required this.title,
    required this.price,
    required this.store,
    this.link,
    this.image,
  });

  final String title;
  final String price;
  final String store;
  final Uri? link;
  final Uri? image;
}
