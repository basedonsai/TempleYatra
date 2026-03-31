// Temple data for Hyderabad and Telangana region
import '../models/temple_model.dart';
import '../utils/distance_calculator.dart';

// Pre-defined temple data (used for offline demo and fallback)
final List<Temple> allTemples = [
  Temple(
    id: 'chilkur_balaji',
    placeId: 'ChIJChilkurBalaji_placeholder',
    name: 'Chilkur Balaji Temple',
    latitude: 17.3975,
    longitude: 78.2833,
    address: 'Chilkur Village, Moinabad Mandal, Hyderabad, Telangana 501504',
    distinctiveFeatures: 'Famous "Visa Balaji" temple near Osman Sagar Lake. Known for its simple rituals without priests accepting donations, traditional worship practices, and prasadam distribution.',
    festivals: 'Vaikuṇṭha Ekādaśi, Rāma Navami, Kṛṣṇa Janmāṣṭamī, Annual Brahmotsavam',
    prasadamInfo: 'Free prasadam available after darshan. Tirupati Laddu on special occasions.',
    darshanTimings: '6:00 AM - 8:00 PM (All days)',
    rating: 4.6,
    userRatingsTotal: 1892,
    openingHours: '6:00 AM - 8:00 PM (All days)',
    // NEW: Cultural content fields
    primaryLanguage: 'te',
    region: 'Telangana',
    deityInfo: 'Lord Venkateswara (Balaji) - Form of Vishnu',
    sthalaPuranam: 'చిల్కూర్ బాలాజీ గుడి హైదరాబాద్ సమీపంలోని చిల్కూర్ గ్రామంలో ఉంది. ఇది ఒక ప్రసిద్ధ వైష్ణవ దేవాలయం. ఈ గుడి 500 సంవత్సరాల చరిత్ర కలిగి ఉన్నదని చెబుతారు. ఇక్కడి ప్రధాన దేవత శ్రీ బాలాజీ (వేంకటేశ్వరుడు). ఈ గుడి "విసా బాలాజీ" గా కూడా ప్రసిద్ధి చెందినది, ఎందుకంటే భక్తులు తమ వీసా సమస్యలు పరిష్కరించుకోవడానికి ఇక్కడ ప్రార్థన చేస్తారు.',
    sthalaPuranamEnglish: 'Chilkur Balaji Temple is located in Chilkur village near Hyderabad. This is a famous Vaishnavite temple believed to be over 500 years old. The main deity is Lord Balaji (Venkateswara). The temple is also known as "Visa Balaji" because devotees pray here for their visa-related issues to be resolved. The temple follows a unique tradition where priests do not accept any donations or offerings - all contributions are purely voluntary.',
    sthalaPuranamHindi: 'चिल्कूर बालाजी मंदिर हैदराबाद के निकट चिल्कूर गाँव में स्थित है। यह एक प्रसिद्ध वैष्णव मंदिर है जो 500 वर्षों से अधिक पुराना माना जाता है। मुख्य देवता भगवान बालाजी (वेंकटेश्वर) हैं। यह मंदिर "वीसा बालाजी" के नाम से भी प्रसिद्ध है क्योंकि भक्त यहाँ अपने वीसा संबंधी समस्याओं के समाधान के लिए प्रार्थना करते हैं।',
    sthalaPuranamTamil: 'சில்கூர் பாலாஜி கோயில் ஹைதராபாத்திற்கு அருகிலுள்ள சில்கூர் கிராமத்தில் அமைந்துள்ளது. இது 500 ஆண்டுகளுக்கும் மேல் பழமையானதாகக் கருதப்படும் புகழ்பெற்ற வைணவ கோயிலாகும். முதன்மை தெய்வம் ஸ்ரீ பாலாஜி (வெங்கடேஸ்வரர்) ஆவார்.',
    sthalaPuranamTelugu: 'చిల్కూర్ బాలాజీ గుడి హైదరాబాద్ సమీపంలోని చిల్కూర్ గ్రామంలో ఉంది. ఇది 500 సంవత్సరాల చరిత్ర కలిగి ఉన్నదని చెబుతారు. ఇక్కడి ప్రధాన దేవత శ్రీ బాలాజీ (వేంకటేశ్వరుడు).',
    rituals: 'అభిషేకం, ఆలింగనం, నైవేద్యం, ప్రదక్షిణం, ప్రణవం. ప్రతిరోజు ఉదయం 6 గంటలకు గుడి తెరిచి, స్వామివారిని జపమాలతో పూజించెదరు. గుడిలో పూజారులు ఎటువంటి దక్షిణం స్వీకరించరు.',
    ritualsEnglish: 'Daily rituals include Abhishekam (sacred bath), Alinganam (embracing the deity), Naivedyam (food offering), Pradakshina (circumambulation), and Pranavam (sacred chanting). The temple opens at 6 AM daily. Unique to this temple, priests do not accept any donations - all offerings are purely voluntary.',
    mantras: 'ఓం నమో వేంకటేశాయ - Om Namo Venkatesaya\nశ్రీ వేంకటేశాయ నమః - Sri Venkatesaya Namah\nఓం విష్ణవే నమః - Om Vishnave Namah',
    significance: 'చిల్కూర్ బాలాజీ గుడి భారతదేశంలోని పురాతన వైష్ణవ కేంద్రాలలో ఒకటి. ఇది "విసా బాలాజీ" గా ప్రసిద్ధి చెందినది. లక్షల్లో భక్తులు తమ వీసా, ఉద్యోగ, వ్యాపార సమస్యలు పరిష్కరించుకోవడానికి ఇక్కడ ప్రార్థన చేస్తారు.',
    bestTimeToVisit: 'ఉదయం 6-9 గంటల మధ్య లేదా సాయంత్రం 5-7 గంటల మధ్య. శుక్రవారాలు మరియు పండుగల సమయంలో భక్తులు ఎక్కువగా ఉంటారు.',
    dressCode: 'ధర్మపు పాత్రలు ధరించడం శ్రేయస్కరం. పురుషులు ధోవతి, షర్టు, వెస్ట్ ధరించవచ్చు. మహిళలు స saree, cholis, లేదా సల్వార్ కమీజ్ ధరించవచ్చు.',
  ),
  
  Temple(
    id: 'jagannath_hyderabad',
    placeId: 'ChIJJagannathTemple_placeholder',
    name: 'Jagannath Temple, Hyderabad',
    latitude: 17.4236,
    longitude: 78.4538,
    address: 'Road No. 72, Near Jubliee Hills, Hyderabad, Telangana 500033',
    distinctiveFeatures: 'Beautiful replica of the Puri Jagannath temple in Banjara Hills. Features authentic Odia architectural style, daily Rath Yatra celebrations.',
    festivals: 'Rath Yatra (July), Rāma Navami, Kṛṣṇa Janmāṣṭamī, Navaratri, Ganesha Chaturthi',
    prasadamInfo: 'Traditional Mahaprasadam available. Special rice offerings during festivals.',
    darshanTimings: '6:00 AM - 12:00 PM, 5:00 PM - 9:00 PM (All days)',
    rating: 4.7,
    userRatingsTotal: 2341,
    openingHours: '6:00 AM - 12:00 PM, 5:00 PM - 9:00 PM (All days)',
    // Cultural content fields
    primaryLanguage: 'or',
    region: 'Telangana',
    deityInfo: 'Lord Jagannath (Lord of the Universe) with Subhadra and Balabhadra',
    sthalaPuranamEnglish: 'Jagannath Temple in Hyderabad is a beautiful replica of the famous Jagannath Temple of Puri, Odisha. The temple was built to bring the divine blessings of Lord Jagannath to the Telugu-speaking population of Hyderabad. The temple complex features the main shrine dedicated to Lord Jagannath along with temples of Subhadra and Balabhadra. The temple follows the same rituals and traditions as the original Puri temple, including the famous Rath Yatra festival which draws thousands of devotees.',
    sthalaPuranamHindi: 'हैदराबाद का जगन्नाथ मंदिर ओडिशा के berühmten जगन्नाथ मंदिर का एक सुंदर प्रतिकृति है। इस मंदिर का निर्माण हैदराबाद की तेलुगु-भाषी जनता को भगवान जगन्नाथ के दैवी आशीर्वाद लाने के लिए किया गया था। मंदिर परिसर में भगवान जगन्नाथ, सुभद्रा और बलभद्रा के मंदिर शामिल हैं।',
    rituals: 'Daily Abhishekam, Dhupa (incense offering), Alankara (decoration), and Mahaprasadam distribution. The temple follows the Odia tradition of serving Mahaprasadam to all devotees.',
    mantras: 'ఓం జగన్నాథాయ నమః - Om Jagannathaya Namah\nశ్రీ జగన్నాథం భజేమః - Sri Jagannatham Bhajamah',
    significance: 'This temple serves as a spiritual center for Odia devotees living in Hyderabad and Telangana. It preserves the rich cultural and religious traditions of Odisha in South India.',
    bestTimeToVisit: 'Early morning (6-8 AM) for peaceful darshan or during evening aarti (5-6 PM). Rath Yatra festival in July is particularly special.',
    dressCode: 'Traditional Indian attire recommended. White or light-colored clothing is appropriate.',
  ),
  
  Temple(
    id: 'peddamma_thalli',
    placeId: 'ChIJPeddammaThalli_placeholder',
    name: 'Sri Peddamma Thalli Temple',
    latitude: 17.4225,
    longitude: 78.4088,
    address: 'Jubilee Hills, Hyderabad, Telangana 500033',
    distinctiveFeatures: 'Ancient goddess temple in Jubilee Hills popular during Bonalu festival with thousands offering potu (pot) offerings.',
    festivals: 'Bonalu (July/August), Śivarātri, Navaratri, Kārtikai Deepam',
    prasadamInfo: 'Bonalu specials, rice offerings, coconut Prasad during festivals.',
    darshanTimings: '6:00 AM - 12:00 PM, 4:00 PM - 8:00 PM (All days)',
    rating: 4.5,
    userRatingsTotal: 1523,
    openingHours: '6:00 AM - 12:00 PM, 4:00 PM - 8:00 PM (All days)',
  ),
  
  Temple(
    id: 'birla_mandir_hyderabad',
    placeId: 'ChIJBirlaMandir_placeholder',
    name: 'Birla Mandir, Hyderabad',
    latitude: 17.4064,
    longitude: 78.4691,
    address: 'Naubat Pahad, Khairatabad, Hyderabad, Telangana 500004',
    distinctiveFeatures: 'White marble temple dedicated to Lord Venkateswara. Offers panoramic views of Hyderabad city. Known for its serene atmosphere and beautiful architecture.',
    festivals: 'Janmāṣṭamī, Rāma Navami, Śivarātri, Vaikuṇṭha Ekādaśi',
    prasadamInfo: 'Free prasadam available. Naivedyam includes sweets and fruits.',
    darshanTimings: '7:00 AM - 12:00 PM, 3:00 PM - 9:00 PM (All days)',
    rating: 4.8,
    userRatingsTotal: 4521,
    openingHours: '7:00 AM - 12:00 PM, 3:00 PM - 9:00 PM (All days)',
  ),
  
  Temple(
    id: 'laknavaram',
    placeId: 'ChIJLaknavaram_placeholder',
    name: 'Sri Lakshmi Narasimha Swamy Temple, Laknavaram',
    latitude: 17.9833,
    longitude: 79.4667,
    address: 'Laknavaram, Warrangal District, Telangana 506342',
    distinctiveFeatures: 'Ancient temple surrounded by lush greenery. Features intricate stone carvings and a peaceful environment away from city crowds.',
    festivals: 'Brahmotsavam (March-April), Rāma Navami, Kṛṣṇa Janmāṣṭamī',
    prasadamInfo: 'Traditional Telugu prasadam available. Annadanam during festivals.',
    darshanTimings: '6:00 AM - 12:00 PM, 4:00 PM - 7:00 PM (All days)',
    rating: 4.4,
    userRatingsTotal: 892,
    openingHours: '6:00 AM - 12:00 PM, 4:00 PM - 7:00 PM (All days)',
  ),
  
  Temple(
    id: ' Thousand Pillar Temple',
    placeId: 'ChIJThousandPillar_placeholder',
    name: 'Sri Rudreshwara Swamy Temple (Thousand Pillar Temple)',
    latitude: 18.0006,
    longitude: 79.4861,
    address: 'Warangal, Telangana 506001',
    distinctiveFeatures: '13th century Kakatiya temple featuring a thousand carved pillars, star-shaped platform, and unique architectural fusion of Hindu and Islamic styles.',
    festivals: 'Shivratri, Rāma Navami, Vaikuṇṭha Ekādaśi, Sankranti',
    prasadamInfo: 'Prasadam available. Special offerings during festivals.',
    darshanTimings: '6:00 AM - 6:00 PM (All days)',
    rating: 4.6,
    userRatingsTotal: 2156,
    openingHours: '6:00 AM - 6:00 PM (All days)',
  ),
  
  Temple(
    id: 'keesaragutta',
    placeId: 'ChIJKeesaraTemple_placeholder',
    name: 'Shri Keesara Sri Venkateswara Swamy Temple',
    latitude: 17.5324,
    longitude: 78.3837,
    address: 'Keesara, Keesara Mandal, Medchal Malkajgiri District, Telangana 501301',
    distinctiveFeatures: 'Ancient temple dedicated to Lord Venkateswara situated on Keesara Gutta hill. Known for its serene location, beautiful architecture, and spiritual significance.',
    festivals: 'Brahmotsavam (March-April), Rāma Navami, Kṛṣṇa Janmāṣṭamī, Śivarātri, Vaikuṇṭha Ekādaśi',
    prasadamInfo: 'Free prasadam available. Naivedyam includes sweets, fruits, and traditional offerings.',
    darshanTimings: '6:00 AM - 12:00 PM, 4:00 PM - 8:00 PM (All days)',
    rating: 4.7,
    userRatingsTotal: 2156,
    openingHours: '6:00 AM - 12:00 PM, 4:00 PM - 8:00 PM (All days)',
  ),
  
  Temple(
    id: 'vijayawada',
    placeId: 'ChIJVijayawada_placeholder',
    name: 'Sri Kanaka Durga Temple, Vijayawada',
    latitude: 16.5062,
    longitude: 80.6480,
    address: 'Indrakeeladri Hill, Vijayawada, Andhra Pradesh 520001',
    distinctiveFeatures: 'Sacred Hindu temple dedicated to Goddess Kanaka Durga on Indrakeeladri Hill. Famous for Pushkaralu festival and evening aarti.',
    festivals: 'Brahmotsavam (October-November), Navaratri, Śivarātri, Varuna Lacchmi Vratam',
    prasadamInfo: 'Prasadam includes Laddu, Pongal, and other traditional offerings.',
    darshanTimings: '6:00 AM - 1:00 PM, 4:00 PM - 9:00 PM (All days)',
    rating: 4.7,
    userRatingsTotal: 3245,
    openingHours: '6:00 AM - 1:00 PM, 4:00 PM - 9:00 PM (All days)',
  ),
  
  Temple(
    id: 'tadepalli',
    placeId: 'ChIJTadepalli_placeholder',
    name: 'Sri Swamy Swamy Temple, Tadepalli',
    latitude: 16.4833,
    longitude: 80.6000,
    address: 'Tadepalli, Guntur District, Andhra Pradesh 522001',
    distinctiveFeatures: 'Ancient temple with unique "Gajaprathishta" (elephant statue). Known for its peaceful location and traditional rituals.',
    festivals: 'Shivratri, Rāma Navami, Ganesha Chaturthi, Sankranti',
    prasadamInfo: 'Prasadam available. Special offerings during festivals.',
    darshanTimings: '6:00 AM - 12:00 PM, 5:00 PM - 8:00 PM (All days)',
    rating: 4.3,
    userRatingsTotal: 678,
    openingHours: '6:00 AM - 12:00 PM, 5:00 PM - 8:00 PM (All days)',
  ),
  
  Temple(
    id: 'srisailam',
    placeId: 'ChIJSrisailam_placeholder',
    name: 'Sri Mallikarjuna Swamy Temple, Srisailam',
    latitude: 16.0743,
    longitude: 78.8668,
    address: 'Srisailam, Kurnool District, Andhra Pradesh 518101',
    distinctiveFeatures: 'Sacred Shaivite temple, one of the 12 Jyotirlingas (Rudra Jyotirlinga). Features Adi Shankaracharya monastery and stunning forest surroundings.',
    festivals: 'Mahashivaratri, Brahmotsavam, Navaratri, Karthika Masam',
    prasadamInfo: 'Prasadam includes Rice, Dal, Curry, and special sweets.',
    darshanTimings: '4:30 AM - 1:00 PM, 3:30 PM - 9:00 PM (All days)',
    rating: 4.9,
    userRatingsTotal: 7654,
    openingHours: '4:30 AM - 1:00 PM, 3:30 PM - 9:00 PM (All days)',
  ),
];

/// Filter temples by distance from a center point
List<Temple> filterTemplesByDistance(
  List<Temple> temples,
  double centerLat,
  double centerLng,
  double maxDistanceKm,
) {
  return temples.where((temple) {
    final distance = calculateDistance(
      centerLat,
      centerLng,
      temple.latitude,
      temple.longitude,
    );
    return distance <= maxDistanceKm;
  }).toList()
  ..sort((a, b) {
    final distA = calculateDistance(
      centerLat,
      centerLng,
      a.latitude,
      a.longitude,
    );
    final distB = calculateDistance(
      centerLat,
      centerLng,
      b.latitude,
      b.longitude,
    );
    return distA.compareTo(distB);
  });
}
