/// Cultural content knowledge base for temples
/// This file contains structured cultural content for RAG retrieval
library;

import '../models/cultural_content.dart';

/// All cultural content for temples (used for RAG knowledge base)
final List<CulturalContent> allCulturalContent = [
  // ===== CHILKUR BALAJI TEMPLE =====
  CulturalContent(
    id: 'chilkur_sp_001',
    templeId: 'chilkur_balaji',
    type: ContentType.sthalaPuranam,
    title: 'The Legend of Chilkur Balaji',
    content: 'Chilkur Balaji Temple is located in Chilkur village near Hyderabad. It is one of the most ancient Vaishnavite temples in Telangana, believed to be over 500 years old. The temple is dedicated to Lord Venkateswara, known locally as Balaji. What makes this temple unique is its spiritual tradition that has remained unchanged for centuries. Unlike most temples, the priests here do not accept any donations or offerings from devotees. All contributions are purely voluntary. The temple gained popularity as the Visa Balaji temple because devotees pray here for visa-related issues.',
    language: 'en',
    source: 'Temple Archives',
    tags: ['legend', 'history', 'visa', 'blessings'],
    validatedDate: DateTime.now(),
    validatorName: 'Temple Priest',
  ),
  
  CulturalContent(
    id: 'chilkur_sp_002',
    templeId: 'chilkur_balaji',
    type: ContentType.sthalaPuranam,
    title: 'Chilkur Balaji Temple History Telugu',
    content: 'Chilkur Balaji Gudi Hyderabad sambidhanlo Chillur gramanlo undi. Idhi samaksham 2000 varsha puratanamani ani antaru. Idhi prathisiddha Vaishnavite devasthana. Pradhan devata Shri Balaji. Idhi Visa Balaji gudi ga prasiddham chesarindi. Chillur prasthanlo prasadam kanna dhanam kaligi vunte vadilenu.',
    language: 'te',
    source: 'Temple Archives Telugu',
    tags: ['charithra', 'puranam', 'visa', 'balaji'],
    validatedDate: DateTime.now(),
    validatorName: 'Temple Priest',
  ),
  
  CulturalContent(
    id: 'chilkur_ritual_001',
    templeId: 'chilkur_balaji',
    type: ContentType.ritual,
    title: 'Daily Rituals and Worship',
    content: 'Morning rituals start at 6 AM with Suprabhata Seva. Abhishekam is performed with milk and panchamrita. Naivedyam offering includes pongal and fruits. Evening rituals include Dhupa and Deepa with aarti at 7 PM. Temple closes at 8 PM. What makes this temple unique is that no special sevas can be booked. Prasadam is distributed freely.',
    language: 'en',
    source: 'Temple Administration',
    tags: ['rituals', 'daily', 'worship', 'schedule'],
    validatedDate: DateTime.now(),
    validatorName: 'Head Priest',
  ),
  
  CulturalContent(
    id: 'chilkur_mantra_001',
    templeId: 'chilkur_balaji',
    type: ContentType.mantra,
    title: 'Sacred Mantras for Chilkur Balaji',
    content: 'Primary Mantra: Om Namo Venkatesaya. Prayer for Visa Success: Om Vishnave Namah. Benefits of chanting include mental peace, career advancement, and divine blessings. Chant at least 108 times using a tulsi mala.',
    language: 'en',
    source: 'Vedic Traditions',
    tags: ['mantra', 'prayer', 'chanting', 'visa'],
    validatedDate: DateTime.now(),
    validatorName: 'Temple Scholar',
  ),
  
  CulturalContent(
    id: 'chilkur_sig_001',
    templeId: 'chilkur_balaji',
    type: ContentType.significance,
    title: 'Spiritual Significance',
    content: 'Chilkur Balaji Temple is one of the ancient temples preserving original spiritual traditions. Known as Visa Balaji where devotees pray for career and visa blessings. Devotees visit for visa interview success, resolution of obstacles, financial prosperity, and spiritual enlightenment.',
    language: 'en',
    source: 'Spiritual Scholars',
    tags: ['significance', 'spiritual', 'visa', 'blessings'],
    validatedDate: DateTime.now(),
    validatorName: 'Religious Expert',
  ),
  
  // ===== JAGANNATH TEMPLE =====
  CulturalContent(
    id: 'jagannath_sp_001',
    templeId: 'jagannath_hyderabad',
    type: ContentType.sthalaPuranam,
    title: 'The Story of Hyderabad Jagannath Temple',
    content: 'Jagannath Temple in Hyderabad is a replica of the famous Jagannath Temple of Puri, Odisha. Built to bring divine blessings to the Telugu-speaking population. The temple complex includes Lord Jagannath, Subhadra and Balabhadra. The annual Rath Yatra festival draws thousands of devotees.',
    language: 'en',
    source: 'Temple Records',
    tags: ['legend', 'history', 'rath yatra', 'odisha'],
    validatedDate: DateTime.now(),
    validatorName: 'Temple Administrator',
  ),
  
  CulturalContent(
    id: 'jagannath_ritual_001',
    templeId: 'jagannath_hyderabad',
    type: ContentType.ritual,
    title: 'Daily Worship and Mahaprasadam',
    content: 'Temple opens 6 AM. Morning Aarti at 7 AM. Evening Aarti at 7 PM. Closes 9 PM. The famous Mahaprasadam is served to all devotees including rice, dal, vegetables and sweets. The temple serves food to ALL visitors regardless of caste or creed.',
    language: 'en',
    source: 'Temple Administration',
    tags: ['rituals', 'prasadam', 'aarti', 'schedule'],
    validatedDate: DateTime.now(),
    validatorName: 'Head Priest',
  ),
  
  // ===== SRISAILAM TEMPLE =====
  CulturalContent(
    id: 'srisailam_sp_001',
    templeId: 'srisailam',
    type: ContentType.sthalaPuranam,
    title: 'The Sacred Legend of Srisailam',
    content: 'Srisailam is located in Nallamala Forest, Andhra Pradesh. Home to Sri Mallikarjuna Swamy Temple dedicated to Lord Shiva. One of the 12 Jyotirlingas and one of the 18 Shakti Peethas. Lord Shiva and Parvati chose this as their divine abode.',
    language: 'en',
    source: 'Ancient Texts Puranas',
    tags: ['legend', 'jyotirlinga', 'shiva', 'sakti peetha'],
    validatedDate: DateTime.now(),
    validatorName: 'Religious Scholar',
  ),
  
  CulturalContent(
    id: 'srisailam_ritual_001',
    templeId: 'srisailam',
    type: ContentType.ritual,
    title: 'Sacred Rituals at Srisailam',
    content: 'Daily rituals include Bela Prabha at 4:30 AM, Abhishekam, Rudrabhishekam, Lingodbhava Darshan. Mahashivaratri includes strict fasting, special abhishekams throughout the night, and thousands of lit lamps.',
    language: 'en',
    source: 'Temple Traditions',
    tags: ['rituals', 'mahashivaratri', 'shaiva', 'abhishekam'],
    validatedDate: DateTime.now(),
    validatorName: 'Head Priest',
  ),
  
  CulturalContent(
    id: 'srisailam_mantra_001',
    templeId: 'srisailam',
    type: ContentType.mantra,
    title: 'Powerful Shiva Mantras',
    content: 'Namah Shivaya - The five-syllable mantra for Shiva worship. Mrigendra Sevana - Salutations to Lord of the Mountains. Benefits: removes negative energies, brings inner peace, accelerates spiritual growth. Chant minimum 108 times daily using Rudraksha mala before sunrise.',
    language: 'en',
    source: 'Vedic Traditions',
    tags: ['mantra', 'shiva', 'namah shivaya', 'rudraksha'],
    validatedDate: DateTime.now(),
    validatorName: 'Shiva Scholar',
  ),

  // ===== BIRLA MANDIR HYDERABAD =====
  CulturalContent(
    id: 'birla_sp_001',
    templeId: 'birla_mandir_hyderabad',
    type: ContentType.sthalaPuranam,
    title: 'The Story of Birla Mandir Hyderabad',
    content: 'Birla Mandir in Hyderabad is a stunning white marble temple dedicated to Lord Venkateswara (Balaji), built by the Birla Foundation in 1976. It stands atop Naubat Pahad hill and offers panoramic views of Hyderabad city including Hussain Sagar lake. The temple is built entirely from Rajasthani white marble and took 10 years to complete. It blends South Indian, Rajasthani, and Utkala architectural styles. The temple is open to all regardless of religion.',
    language: 'en',
    source: 'Temple Records',
    tags: ['birla', 'marble', 'venkateswara', 'hyderabad', 'history'],
    validatedDate: DateTime.now(),
    validatorName: 'Temple Administrator',
  ),
  CulturalContent(
    id: 'birla_ritual_001',
    templeId: 'birla_mandir_hyderabad',
    type: ContentType.ritual,
    title: 'Daily Rituals at Birla Mandir',
    content: 'Temple opens at 7 AM. Morning Abhishekam at 7:30 AM. Afternoon break 12 PM to 3 PM. Evening aarti at 6 PM. Closes at 9 PM. Free prasadam distributed after evening aarti. Photography is not allowed inside the sanctum. Dress code: traditional Indian attire preferred.',
    language: 'en',
    source: 'Temple Administration',
    tags: ['rituals', 'aarti', 'prasadam', 'timings'],
    validatedDate: DateTime.now(),
    validatorName: 'Head Priest',
  ),
  CulturalContent(
    id: 'birla_sig_001',
    templeId: 'birla_mandir_hyderabad',
    type: ContentType.significance,
    title: 'Significance of Birla Mandir',
    content: 'Birla Mandir is one of the most visited temples in Hyderabad, attracting over 20,000 devotees daily. The hilltop location symbolizes the divine abode of Lord Venkateswara. The temple also houses a museum with exhibits on Hindu philosophy, the life of Ramanujacharya, and the Bhagavad Gita. It is a center for spiritual learning and cultural preservation.',
    language: 'en',
    source: 'Birla Foundation',
    tags: ['significance', 'museum', 'philosophy', 'venkateswara'],
    validatedDate: DateTime.now(),
    validatorName: 'Religious Expert',
  ),

  // ===== PEDDAMMA THALLI =====
  CulturalContent(
    id: 'peddamma_sp_001',
    templeId: 'peddamma_thalli',
    type: ContentType.sthalaPuranam,
    title: 'The Legend of Sri Peddamma Thalli',
    content: 'Sri Peddamma Thalli Temple in Jubilee Hills, Hyderabad is dedicated to Goddess Peddamma, a powerful village deity worshipped across Telangana. The goddess is considered the protector of the city. The temple is especially famous during the Bonalu festival when thousands of women carry pots of cooked rice on their heads as offerings. The temple is believed to be several centuries old and is one of the most important Shakti shrines in Hyderabad.',
    language: 'en',
    source: 'Temple Archives',
    tags: ['peddamma', 'goddess', 'bonalu', 'shakti', 'telangana'],
    validatedDate: DateTime.now(),
    validatorName: 'Temple Priest',
  ),
  CulturalContent(
    id: 'peddamma_ritual_001',
    templeId: 'peddamma_thalli',
    type: ContentType.ritual,
    title: 'Bonalu and Daily Worship',
    content: 'Daily puja starts at 6 AM with flower offerings and incense. The Bonalu festival (July-August) is the most important event — devotees carry decorated pots (bonam) filled with cooked rice, jaggery, and curd to the goddess. Special processions with music and dance are held. The temple also celebrates Navratri with nine days of special pujas.',
    language: 'en',
    source: 'Temple Administration',
    tags: ['bonalu', 'puja', 'navratri', 'festival'],
    validatedDate: DateTime.now(),
    validatorName: 'Head Priest',
  ),

  // ===== KEESARAGUTTA =====
  CulturalContent(
    id: 'keesaragutta_sp_001',
    templeId: 'keesaragutta',
    type: ContentType.sthalaPuranam,
    title: 'The Legend of Keesara Venkateswara Temple',
    content: 'Shri Keesara Sri Venkateswara Swamy Temple is situated on Keesara Gutta hill in Medchal district, Telangana. The temple is dedicated to Lord Venkateswara and is believed to be over 1000 years old. According to legend, the deity here is a swayambhu (self-manifested) form of Lord Venkateswara. The hilltop location and serene surroundings make it a popular pilgrimage destination. The temple is managed by the Telangana Endowments Department.',
    language: 'en',
    source: 'Temple Records',
    tags: ['venkateswara', 'swayambhu', 'keesara', 'hill temple'],
    validatedDate: DateTime.now(),
    validatorName: 'Temple Administrator',
  ),

  // ===== VIJAYAWADA KANAKA DURGA =====
  CulturalContent(
    id: 'vijayawada_sp_001',
    templeId: 'vijayawada',
    type: ContentType.sthalaPuranam,
    title: 'The Legend of Sri Kanaka Durga Temple',
    content: 'Sri Kanaka Durga Temple in Vijayawada is one of the most powerful Shakti shrines in India, situated on Indrakeeladri Hill on the banks of the Krishna River. The goddess Kanaka Durga is believed to have slain the demon Mahishasura here. The temple is one of the 18 Shakti Peethas. The Brahmotsavam festival during Navratri draws millions of devotees. The temple is managed by the Andhra Pradesh Endowments Department.',
    language: 'en',
    source: 'Temple Archives',
    tags: ['kanaka durga', 'shakti peetha', 'navratri', 'krishna river'],
    validatedDate: DateTime.now(),
    validatorName: 'Religious Scholar',
  ),
  CulturalContent(
    id: 'vijayawada_mantra_001',
    templeId: 'vijayawada',
    type: ContentType.mantra,
    title: 'Kanaka Durga Mantras',
    content: 'Om Aim Hreem Kleem Chamundaye Vichche — the Navarna mantra for Durga worship. Sri Kanaka Durga Ashtottara — 108 names of the goddess. Chanting during Navratri is considered especially powerful. The Lalita Sahasranama is recited daily at the temple.',
    language: 'en',
    source: 'Vedic Traditions',
    tags: ['mantra', 'durga', 'navarna', 'lalita sahasranama'],
    validatedDate: DateTime.now(),
    validatorName: 'Temple Scholar',
  ),

  // ===== THOUSAND PILLAR TEMPLE =====
  CulturalContent(
    id: 'thousand_pillar_sp_001',
    templeId: 'thousand_pillar_temple',
    type: ContentType.sthalaPuranam,
    title: 'The Legend of the Thousand Pillar Temple',
    content: 'Sri Rudreshwara Swamy Temple, popularly known as the Thousand Pillar Temple, is a 12th-century Kakatiya-era temple in Warangal, Telangana. Built by King Rudra Deva of the Kakatiya dynasty around 1163 CE, it is dedicated to Lord Shiva, Lord Vishnu, and Lord Surya. The temple is famous for its 1000 intricately carved pillars, star-shaped platform (stellate plan), and the unique fusion of Chalukyan and Kakatiya architectural styles. It is a protected monument under the Archaeological Survey of India.',
    language: 'en',
    source: 'Archaeological Survey of India',
    tags: ['kakatiya', 'warangal', 'shiva', 'architecture', 'history'],
    validatedDate: DateTime.now(),
    validatorName: 'Archaeological Expert',
  ),
  CulturalContent(
    id: 'thousand_pillar_arch_001',
    templeId: 'thousand_pillar_temple',
    type: ContentType.architecture,
    title: 'Architecture of the Thousand Pillar Temple',
    content: 'The temple features a trikuta (three-shrine) layout with shrines for Shiva, Vishnu, and Surya. The star-shaped platform is a hallmark of Kakatiya architecture. The 1000 pillars are carved from black basalt and feature intricate floral, geometric, and figurative motifs. The Nandi (sacred bull) statue at the entrance is carved from a single black stone. The temple also has a beautiful stepped tank (pushkarini) for ritual bathing.',
    language: 'en',
    source: 'Archaeological Survey of India',
    tags: ['architecture', 'kakatiya', 'pillars', 'basalt', 'nandi'],
    validatedDate: DateTime.now(),
    validatorName: 'Archaeological Expert',
  ),
];

/// CulturalContentData class - wrapper for cultural content functions
class CulturalContentData {
  /// Get cultural content for a specific temple as a Map
  Map<ContentType, CulturalContent> getContentForTemple(String templeId) {
    final result = <ContentType, CulturalContent>{};
    final content = allCulturalContent.where((c) => c.templeId == templeId);
    
    for (final c in content) {
      // Only add if not already present (first occurrence wins)
      if (!result.containsKey(c.type)) {
        result[c.type] = c;
      }
    }
    
    return result;
  }

  /// Get content by type for a temple
  List<CulturalContent> getContentByType(String templeId, ContentType type) {
    return allCulturalContent
        .where((content) => content.templeId == templeId && content.type == type)
        .toList();
  }

  /// Get content by language
  List<CulturalContent> getContentByLanguage(String languageCode) {
    return allCulturalContent
        .where((content) => content.language == languageCode)
        .toList();
  }

  /// Search content by query
  List<CulturalContent> searchContent(String query) {
    final lowerQuery = query.toLowerCase();
    return allCulturalContent
        .where((content) =>
            content.title.toLowerCase().contains(lowerQuery) ||
            content.content.toLowerCase().contains(lowerQuery) ||
            content.tags!.any((tag) => tag.toLowerCase().contains(lowerQuery)))
        .toList();
  }

  /// Get recommended content topics for a temple
  List<String> getRecommendedTopics(String templeId) {
    final content = getAllContentForTemple(templeId);
    final topics = <String>{};
    
    for (final c in content) {
      topics.add(c.typeDisplayName);
    }
    
    return topics.toList()..sort();
  }

  /// Get ALL cultural content for a specific temple (returns list)
  List<CulturalContent> getAllContentForTemple(String templeId) {
    return allCulturalContent.where((content) => content.templeId == templeId).toList();
  }
}

/// Get cultural content for a specific temple (legacy function)
List<CulturalContent> getContentForTemple(String templeId) {
  return allCulturalContent.where((content) => content.templeId == templeId).toList();
}

/// Get content by type for a temple
List<CulturalContent> getContentByType(String templeId, ContentType type) {
  return allCulturalContent
      .where((content) => content.templeId == templeId && content.type == type)
      .toList();
}

/// Get content by language
List<CulturalContent> getContentByLanguage(String languageCode) {
  return allCulturalContent
      .where((content) => content.language == languageCode)
      .toList();
}

/// Search content by query
List<CulturalContent> searchContent(String query) {
  final lowerQuery = query.toLowerCase();
  return allCulturalContent
      .where((content) =>
          content.title.toLowerCase().contains(lowerQuery) ||
          content.content.toLowerCase().contains(lowerQuery) ||
          content.tags!.any((tag) => tag.toLowerCase().contains(lowerQuery)))
      .toList();
}

/// Get recommended content topics for a temple
List<String> getRecommendedTopics(String templeId) {
  final content = getContentForTemple(templeId);
  final topics = <String>{};
  
  for (final c in content) {
    topics.add(c.typeDisplayName);
  }
  
  return topics.toList()..sort();
}
