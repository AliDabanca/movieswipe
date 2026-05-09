class GenreTranslator {
  static const Map<String, String> _translations = {
    'Action': 'Aksiyon',
    'Adventure': 'Macera',
    'Animation': 'Animasyon',
    'Comedy': 'Komedi',
    'Crime': 'Suç',
    'Documentary': 'Belgesel',
    'Drama': 'Dram',
    'Family': 'Aile',
    'Fantasy': 'Fantastik',
    'History': 'Tarih',
    'Horror': 'Korku',
    'Music': 'Müzik',
    'Mystery': 'Gizem',
    'Romance': 'Romantik',
    'Science Fiction': 'Bilim Kurgu',
    'Sci-Fi': 'Bilim Kurgu',
    'TV Movie': 'TV Filmi',
    'Thriller': 'Gerilim',
    'War': 'Savaş',
    'Western': 'Vahşi Batı',
    'General': 'Genel',
  };

  static String translate(String genre) {
    if (genre.isEmpty) return genre;
    
    // Handle multiple genres separated by commas or dots
    if (genre.contains(',') || genre.contains('·')) {
      final separator = genre.contains('·') ? ' · ' : ', ';
      final parts = genre.split(RegExp(r'[·,]')).map((e) => e.trim());
      return parts.map((p) => _translations[p] ?? p).join(separator);
    }

    return _translations[genre] ?? genre;
  }
}
