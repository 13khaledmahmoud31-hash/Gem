import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ZadApp());
}

class ZadApp extends StatefulWidget {
  const ZadApp({super.key});

  @override
  State<ZadApp> createState() => _ZadAppState();
}

class _ZadAppState extends State<ZadApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZAD',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2E7D6B),
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF5F7F6),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2E7D6B),
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1210),
      ),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: DashboardScreen(
        onToggleTheme: _toggleTheme,
        isDark: _themeMode == ThemeMode.dark,
      ),
    );
  }
}

// ==================== التخزين المحلي (Offline Storage) ====================
class ZadStorage {
  static Future<int> getXp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('zad_xp') ?? 0;
  }

  static Future<int> addXp(int points) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt('zad_xp') ?? 0;
    final updated = current + points;
    await prefs.setInt('zad_xp', updated);
    return updated;
  }

  static Future<int> getWater() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('zad_water') ?? 0;
  }

  static Future<void> setWater(int ml) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('zad_water', ml);
  }

  static Future<List<String>> getHabits() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('zad_habits') ?? [];
  }

  static Future<void> setHabits(List<String> habits) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('zad_habits', habits);
  }

  static Future<List<String>> getJournal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('zad_journal') ?? [];
  }

  static Future<void> setJournal(List<String> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('zad_journal', entries);
  }

  static Future<String?> getPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('zad_pin');
  }

  static Future<void> setPin(String? pin) async {
    final prefs = await SharedPreferences.getInstance();
    if (pin == null) {
      await prefs.remove('zad_pin');
    } else {
      await prefs.setString('zad_pin', pin);
    }
  }
}

// ==================== الشاشة الرئيسية (Bento Dashboard) ====================
class DashboardScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;

  const DashboardScreen({
    super.key,
    required this.onToggleTheme,
    required this.isDark,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _xp = 0;
  int _waterMl = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final xp = await ZadStorage.getXp();
    final water = await ZadStorage.getWater();
    if (mounted) {
      setState(() {
        _xp = xp;
        _waterMl = water;
      });
    }
  }

  Future<void> _openScreen(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    final level = (_xp ~/ 100) + 1;
    final progress = (_xp % 100) / 100.0;

    final modules = [
      _ModuleCard('اللياقة والتمارين', 'تمارين منزلية بمؤقت', Icons.fitness_center, Colors.orange, const FitnessScreen()),
      _ModuleCard('التغذية والوصفات', 'السعرات، الماء، والثلاجة', Icons.restaurant_menu, Colors.green, const NutritionScreen()),
      _ModuleCard('الإنتاجية والعادات', 'بومودورو وعادات يومية', Icons.timer, Colors.indigo, const ProductivityScreen()),
      _ModuleCard('الصحة النفسية', 'تنفس، يوميات، ديتوكس', Icons.self_improvement, Colors.teal, const WellnessScreen()),
      _ModuleCard('التعلم السريع', 'بطاقات حفظ واقتباسات', Icons.style, Colors.purple, const LearningScreen()),
      _ModuleCard('الطوارئ والإسعاف', 'إسعافات أولية و CPR', Icons.medical_services, Colors.red, const EmergencyScreen()),
      _ModuleCard('التحديات والـ QR', 'الأوسمة ومشاركة الأصدقاء', Icons.qr_code_2, Colors.amber.shade800, const GamificationScreen()),
      _ModuleCard('عن ZAD وتواصل', 'خالد محمود حسن', Icons.info_outline, Colors.blueGrey, const AboutScreen()),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ZAD', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            Text('100% أوفلاين • بياناتك على جهازك 🔒', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'طوارئ',
            icon: const Icon(Icons.emergency, color: Colors.redAccent),
            onPressed: () => _openScreen(const EmergencyScreen()),
          ),
          IconButton(
            tooltip: 'تبديل المظهر',
            icon: Icon(widget.isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            tooltip: 'عن التطبيق وتواصل معنا',
            icon: const Icon(Icons.person_pin),
            onPressed: () => _openScreen(const AboutScreen()),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // بطاقة الحالة والمستوى
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E7D6B), Color(0xFF194B40)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('المستوى $level • $_xp نقطة',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('💧 $_waterMl مل', style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 7,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.amberAccent),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('مطور البرنامج: خالد محمود حسن',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text('أقسام زاد الشاملة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: GridView.builder(
                itemCount: modules.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.12,
                ),
                itemBuilder: (context, index) {
                  final item = modules[index];
                  return Card(
                    elevation: 0.6,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _openScreen(item.screen),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            CircleAvatar(
                              backgroundColor: item.color.withValues(alpha: 0.15),
                              child: Icon(item.icon, color: item.color),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                const SizedBox(height: 3),
                                Text(item.subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleCard {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget screen;
  _ModuleCard(this.title, this.subtitle, this.icon, this.color, this.screen);
}

// ==================== 1. قسم اللياقة البدنية ====================
class FitnessScreen extends StatefulWidget {
  const FitnessScreen({super.key});

  @override
  State<FitnessScreen> createState() => _FitnessScreenState();
}

class _FitnessScreenState extends State<FitnessScreen> {
  String _level = 'مبتدئ';
  int _secondsLeft = 30;
  bool _running = false;
  Timer? _timer;
  int _activeIndex = 0;

  final Map<String, List<Map<String, String>>> _workouts = {
    'مبتدئ': [
      {'name': 'المشي في المكان (إحماء)', 'sec': '30', 'steps': 'ارفع ركبتيك بالتبادل مع تحريك الذراعين بانتظام والتنفس بعمق.'},
      {'name': 'ضغط على الحائط', 'sec': '30', 'steps': 'قف على بعد ذراع من الحائط، ضع كفيك وادفع جسمك للأمام ثم للخلف.'},
      {'name': 'سكوات الكرسي (نصف قرفصاء)', 'sec': '30', 'steps': 'اجلس ببطء حتى تلامس الكرسي ثم قف مع الحفاظ على استقامة الظهر.'},
    ],
    'متوسط': [
      {'name': 'قفز النجمة (Jumping Jacks)', 'sec': '40', 'steps': 'اقفز مع فتح الساقين ورفع اليدين فوق الرأس ثم العودة للوضع الأساسي.'},
      {'name': 'تمرين الضغط الكلاسيكي', 'sec': '40', 'steps': 'حافظ على استقامة الجسم من الرأس للكعبين وانزل بصدرك قرب الأرض.'},
      {'name': 'بلانك (Plank)', 'sec': '45', 'steps': 'ارتكز على الساعدين وأطراف الأصابع واشدد عضلات البطن دون هبوط الظهر.'},
    ],
    'متقدم': [
      {'name': 'تمرين بيربي (Burpees)', 'sec': '45', 'steps': 'انزل لوضع الضغط ثم اقفز للأعلى مع التصفيق فوق الرأس بأقصى سرعة.'},
      {'name': 'الطعن القافز (Jump Lunges)', 'sec': '45', 'steps': 'بدّل الساقين في الهواء أثناء القفز من وضع الطعن مع توازن الجذع.'},
      {'name': 'ضغط الماس (Diamond Pushups)', 'sec': '45', 'steps': 'قرّب اليدين على شكل ماسة أسفل الصدر لاستهداف الترايسبس والصدر.'},
    ],
  };

  void _selectWorkout(int index) {
    _timer?.cancel();
    final list = _workouts[_level]!;
    setState(() {
      _activeIndex = index;
      _running = false;
      _secondsLeft = int.parse(list[index]['sec']!);
    });
  }

  void _toggleTimer() {
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
    } else {
      setState(() => _running = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
        if (_secondsLeft > 1) {
          setState(() => _secondsLeft--);
        } else {
          t.cancel();
          HapticFeedback.heavyImpact();
          await ZadStorage.addXp(25);
          if (mounted) {
            setState(() {
              _running = false;
              _secondsLeft = 0;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('أحسنت! أتممت التمرين وحصلت على +25 نقطة 💪')),
            );
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = _workouts[_level]!;
    final current = list[_activeIndex];

    return Scaffold(
      appBar: AppBar(title: const Text('اللياقة البدنية (بدون نت)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Wrap(
              spacing: 8,
              children: ['مبتدئ', 'متوسط', 'متقدم'].map((lvl) {
                return ChoiceChip(
                  label: Text(lvl),
                  selected: _level == lvl,
                  onSelected: (_) {
                    _timer?.cancel();
                    setState(() {
                      _level = lvl;
                      _activeIndex = 0;
                      _running = false;
                      _secondsLeft = int.parse(_workouts[lvl]![0]['sec']!);
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // بطاقة المؤقت النشط
            Card(
              color: Colors.orange.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Text(current['name']!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('$_secondsLeft ثانية', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.orange)),
                    const SizedBox(height: 8),
                    Text(current['steps']!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _toggleTimer,
                          icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                          label: Text(_running ? 'إيقاف مؤقت' : 'ابدأ التمرين'),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: () => _selectWorkout(_activeIndex),
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Align(alignment: Alignment.centerRight, child: Text('مكتبة تمارين المستوى:', style: TextStyle(fontWeight: FontWeight.bold))),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final ex = list[i];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Text('${i + 1}')),
                      title: Text(ex['name']!),
                      subtitle: Text('المدة: ${ex['sec']} ثانية'),
                      trailing: const Icon(Icons.play_circle_outline),
                      selected: i == _activeIndex,
                      onTap: () => _selectWorkout(i),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 2. قسم التغذية والصحة الذكية ====================
class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  final _weightCtrl = TextEditingController(text: '75');
  final _heightCtrl = TextEditingController(text: '175');
  final _ageCtrl = TextEditingController(text: '26');
  bool _isMale = true;
  int _waterMl = 0;
  double? _dailyCalories;
  final Set<String> _selectedIngredients = {'بيض', 'طماطم'};

  final List<Map<String, dynamic>> _recipes = [
    {
      'title': 'أومليت بالخضار السريع',
      'cal': '290 سعرة',
      'time': '7 دقائق',
      'ingredients': ['بيض', 'طماطم'],
      'steps': 'اخفق بيضتين مع طماطم مقطعة ورشة فلفل واطهها في مقلاة غير لاصقة.',
    },
    {
      'title': 'شوفان بالموز والعسل',
      'cal': '340 سعرة',
      'time': '5 دقائق',
      'ingredients': ['شوفان', 'موز'],
      'steps': 'اغلي الشوفان في ماء أو حليب 4 دقائق ثم أضف شرائح الموز.',
    },
    {
      'title': 'سلطة تونة صحية',
      'cal': '310 سعرة',
      'time': '5 دقائق',
      'ingredients': ['تونة', 'طماطم'],
      'steps': 'صفِّ التونة واخلطها مع الطماطم وعصير الليمون والكمون.',
    },
    {
      'title': 'زبادي بالشوفان والموز',
      'cal': '270 سعرة',
      'time': '3 دقائق',
      'ingredients': ['زبادي', 'شوفان', 'موز'],
      'steps': 'اخلط علبة زبادي مع ملعقتي شوفان وموزة مقطعة لوجبة مشبعة.',
    },
    {
      'title': 'صدور دجاج مشوية بالبهارات',
      'cal': '380 سعرة',
      'time': '15 دقيقة',
      'ingredients': ['دجاج', 'طماطم'],
      'steps': 'تبل الدجاج بالليمون والبهارات واشوِه على طاسة ساخنة مع طماطم مشوية.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadWater();
    _calculateCalories();
  }

  Future<void> _loadWater() async {
    final w = await ZadStorage.getWater();
    if (mounted) setState(() => _waterMl = w);
  }

  Future<void> _addWater(int ml) async {
    final updated = _waterMl + ml;
    await ZadStorage.setWater(updated);
    await ZadStorage.addXp(5);
    setState(() => _waterMl = updated);
  }

  void _calculateCalories() {
    final w = double.tryParse(_weightCtrl.text) ?? 70;
    final h = double.tryParse(_heightCtrl.text) ?? 170;
    final a = double.tryParse(_ageCtrl.text) ?? 25;
    final bmr = (10 * w) + (6.25 * h) - (5 * a) + (_isMale ? 5 : -161);
    setState(() => _dailyCalories = bmr * 1.45);
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = double.tryParse(_weightCtrl.text) ?? 70;
    final targetWater = (w * 35).round();
    final filteredRecipes = _recipes.where((r) {
      final req = List<String>.from(r['ingredients'] as List);
      return req.any((ing) => _selectedIngredients.contains(ing));
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('التغذية والصحة الذكية')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // متعقب الماء
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('متعقب شرب الماء 💧', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('$_waterMl / $targetWater مل', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (_waterMl / (targetWater > 0 ? targetWater : 2500)).clamp(0.0, 1.0),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ElevatedButton(onPressed: () => _addWater(250), child: const Text('+250 مل')),
                      const SizedBox(width: 8),
                      ElevatedButton(onPressed: () => _addWater(500), child: const Text('+500 مل')),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          await ZadStorage.setWater(0);
                          setState(() => _waterMl = 0);
                        },
                        child: const Text('تصفير'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // حاسبة السعرات
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('حاسبة السعرات الحرارية المحلية 🔥', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: _weightCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الوزن (كجم)', border: OutlineInputBorder()))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: _heightCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الطول (سم)', border: OutlineInputBorder()))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: _ageCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'العمر', border: OutlineInputBorder()))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ChoiceChip(label: const Text('ذكر'), selected: _isMale, onSelected: (_) => setState(() { _isMale = true; _calculateCalories(); })),
                      const SizedBox(width: 8),
                      ChoiceChip(label: const Text('أنثى'), selected: !_isMale, onSelected: (_) => setState(() { _isMale = false; _calculateCalories(); })),
                      const Spacer(),
                      FilledButton(onPressed: _calculateCalories, child: const Text('احسب')),
                    ],
                  ),
                  if (_dailyCalories != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'احتياجك اليومي التقريبي: ${_dailyCalories!.round()} سعرة حرارية',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 15),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // وصفات الثلاجة
          const Text('وصفات سريعة بمكونات متوفرة في منزلك 🥗', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: ['بيض', 'شوفان', 'تونة', 'طماطم', 'زبادي', 'دجاج', 'موز'].map((ing) {
              return FilterChip(
                label: Text(ing),
                selected: _selectedIngredients.contains(ing),
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      _selectedIngredients.add(ing);
                    } else {
                      _selectedIngredients.remove(ing);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          ...filteredRecipes.map((r) => Card(
                child: ListTile(
                  title: Text('${r['title']} (${r['cal']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('الوقت: ${r['time']}\n${r['steps']}'),
                  isThreeLine: true,
                ),
              )),
        ],
      ),
    );
  }
}

// ==================== 3. قسم الإنتاجية وتنظيم الوقت ====================
class ProductivityScreen extends StatefulWidget {
  const ProductivityScreen({super.key});

  @override
  State<ProductivityScreen> createState() => _ProductivityScreenState();
}

class _ProductivityScreenState extends State<ProductivityScreen> {
  int _focusMinutes = 25;
  int _secondsRemaining = 25 * 60;
  bool _running = false;
  bool _ambientOn = false;
  Timer? _timer;
  List<String> _doneHabits = [];

  final List<String> _allHabits = [
    'قراءة 10 صفحات يومياً',
    'تنظيم المهام الصباحية',
    'التمرين لمدة 20 دقيقة',
    'ترك الهاتف قبل النوم بساعة',
    'شرب 2 لتر ماء',
  ];

  @override
  void initState() {
    super.initState();
    _loadHabits();
  }

  Future<void> _loadHabits() async {
    final h = await ZadStorage.getHabits();
    if (mounted) setState(() => _doneHabits = h);
  }

  void _setDuration(int mins) {
    _timer?.cancel();
    setState(() {
      _focusMinutes = mins;
      _secondsRemaining = mins * 60;
      _running = false;
    });
  }

  void _toggleTimer() {
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
    } else {
      setState(() => _running = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
        if (_secondsRemaining > 0) {
          setState(() => _secondsRemaining--);
          if (_ambientOn && _secondsRemaining % 4 == 0) {
            HapticFeedback.selectionClick();
          }
        } else {
          t.cancel();
          HapticFeedback.heavyImpact();
          await ZadStorage.addXp(20);
          if (mounted) {
            setState(() => _running = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('انتهت جلسة البومودورو! +20 نقطة تركيز 🎯')),
            );
          }
        }
      });
    }
  }

  Future<void> _toggleHabit(String habit) async {
    setState(() {
      if (_doneHabits.contains(habit)) {
        _doneHabits.remove(habit);
      } else {
        _doneHabits.add(habit);
        ZadStorage.addXp(10);
      }
    });
    await ZadStorage.setHabits(_doneHabits);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mins = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final secs = (_secondsRemaining % 60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(title: const Text('الإنتاجية وتنظيم الوقت')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.indigo.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text('مؤقت بومودورو للتركيز ⏱️', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [15, 25, 50].map((m) {
                      return ChoiceChip(
                        label: Text('$m دقيقة'),
                        selected: _focusMinutes == m,
                        onSelected: (_) => _setDuration(m),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text('$mins:$secs', style: const TextStyle(fontSize: 52, fontWeight: FontWeight.bold, color: Colors.indigo)),
                  SwitchListTile(
                    title: const Text('إيقاع تركيز هادئ (نبضات لمسية)', style: TextStyle(fontSize: 13)),
                    value: _ambientOn,
                    onChanged: (v) => setState(() => _ambientOn = v),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: _toggleTimer,
                        icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                        label: Text(_running ? 'إيقاف' : 'ابدأ التركيز'),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: () => _setDuration(_focusMinutes),
                        child: const Text('إعادة'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('متعقب العادات اليومية ✅', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('${_doneHabits.length} / ${_allHabits.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          ..._allHabits.map((h) {
            final done = _doneHabits.contains(h);
            return Card(
              child: CheckboxListTile(
                title: Text(h, style: TextStyle(decoration: done ? TextDecoration.lineThrough : null)),
                value: done,
                onChanged: (_) => _toggleHabit(h),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ==================== 4. قسم الصحة النفسية والذهنية ====================
class WellnessScreen extends StatefulWidget {
  const WellnessScreen({super.key});

  @override
  State<WellnessScreen> createState() => _WellnessScreenState();
}

class _WellnessScreenState extends State<WellnessScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _breathCtrl;
  String _breathPhase = 'اضغط للبدء';
  bool _breathingActive = false;

  List<String> _entries = [];
  String? _savedPin;
  bool _unlocked = false;
  final _journalCtrl = TextEditingController();

  bool _detoxActive = false;
  int _detoxSeconds = 0;
  Timer? _detoxTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _breathCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _loadData();
  }

  Future<void> _loadData() async {
    final e = await ZadStorage.getJournal();
    final pin = await ZadStorage.getPin();
    if (mounted) {
      setState(() {
        _entries = e;
        _savedPin = pin;
        _unlocked = pin == null;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_detoxActive && state == AppLifecycleState.paused) {
      _detoxTimer?.cancel();
      setState(() {
        _detoxActive = false;
        _detoxSeconds = 0;
      });
    }
  }

  void _toggleBreathing() {
    if (_breathingActive) {
      _breathCtrl.stop();
      setState(() {
        _breathingActive = false;
        _breathPhase = 'اضغط للبدء';
      });
    } else {
      setState(() {
        _breathingActive = true;
        _breathPhase = 'شهيق عميق (4 ث)...';
      });
      _breathCtrl.repeat(reverse: true);
      _breathCtrl.addStatusListener((status) {
        if (!_breathingActive || !mounted) return;
        HapticFeedback.lightImpact();
        setState(() {
          _breathPhase = status == AnimationStatus.forward ? 'شهيق عميق...' : 'زفير هادئ...';
        });
      });
    }
  }

  Future<void> _addJournalEntry() async {
    final txt = _journalCtrl.text.trim();
    if (txt.isEmpty) return;
    final now = DateTime.now();
    final formatted = '${now.year}-${now.month}-${now.day} | $txt';
    setState(() {
      _entries.insert(0, formatted);
      _journalCtrl.clear();
    });
    await ZadStorage.setJournal(_entries);
    await ZadStorage.addXp(15);
  }

  Future<void> _promptPinSetupOrUnlock() async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(_savedPin == null ? 'تعيين رمز قفل (PIN)' : 'إدخال رمز القفل'),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
            decoration: const InputDecoration(hintText: 'أدخل 4 أرقام'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                if (_savedPin == null && ctrl.text.length == 4) {
                  await ZadStorage.setPin(ctrl.text);
                  setState(() {
                    _savedPin = ctrl.text;
                    _unlocked = true;
                  });
                } else if (_savedPin == ctrl.text) {
                  setState(() => _unlocked = true);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('تأكيد'),
            ),
          ],
        ),
      ),
    );
  }

  void _startDetox(int minutes) {
    _detoxTimer?.cancel();
    setState(() {
      _detoxActive = true;
      _detoxSeconds = minutes * 60;
    });
    _detoxTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (_detoxSeconds > 0) {
        setState(() => _detoxSeconds--);
      } else {
        t.cancel();
        await ZadStorage.addXp(30);
        if (mounted) {
          setState(() => _detoxActive = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('رائع! أتممت تحدي الديتوكس الرقمي +30 نقطة 🌿')),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _breathCtrl.dispose();
    _journalCtrl.dispose();
    _detoxTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dm = (_detoxSeconds ~/ 60).toString().padLeft(2, '0');
    final ds = (_detoxSeconds % 60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(title: const Text('الصحة النفسية والذهنية')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // التنفس الموجه
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  const Text('تمرين التنفس الموجه لتقليل التوتر 🌬️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  AnimatedBuilder(
                    animation: _breathCtrl,
                    builder: (_, __) {
                      final size = 80 + (_breathCtrl.value * 60);
                      return Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.teal.withValues(alpha: 0.25 + (_breathCtrl.value * 0.3)),
                          border: Border.all(color: Colors.teal, width: 3),
                        ),
                        child: const Icon(Icons.air, color: Colors.teal, size: 34),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(_breathPhase, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.teal)),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: _toggleBreathing,
                    child: Text(_breathingActive ? 'إيقاف التنفس' : 'ابدأ تمرين التنفس'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // الديتوكس الرقمي
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('تحدي الديتوكس الرقمي (صيام الشاشات) 📵', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 6),
                  const Text('اترك الهاتف أو ابقَ هنا بدون الخروج لتطبيقات أخرى.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 10),
                  if (_detoxActive)
                    Center(
                      child: Column(
                        children: [
                          Text('$dm:$ds', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.teal)),
                          TextButton(
                            onPressed: () {
                              _detoxTimer?.cancel();
                              setState(() => _detoxActive = false);
                            },
                            child: const Text('إلغاء التحدي'),
                          ),
                        ],
                      ),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(onPressed: () => _startDetox(15), child: const Text('15 دقيقة')),
                        ElevatedButton(onPressed: () => _startDetox(30), child: const Text('30 دقيقة')),
                        ElevatedButton(onPressed: () => _startDetox(60), child: const Text('60 دقيقة')),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // دفتر الامتنان المحمي
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('دفتر الامتنان واليوميات 🔒', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      TextButton.icon(
                        onPressed: _promptPinSetupOrUnlock,
                        icon: Icon(_savedPin == null ? Icons.lock_open : Icons.lock, size: 18),
                        label: Text(_savedPin == null ? 'تعيين قفل' : (_unlocked ? 'مفتوح' : 'فتح القفل')),
                      ),
                    ],
                  ),
                  if (!_unlocked)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: FilledButton(onPressed: _promptPinSetupOrUnlock, child: const Text('أدخل الرمز لعرض يومياتك')),
                      ),
                    )
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _journalCtrl,
                            decoration: const InputDecoration(hintText: 'اكتب شيء ممتن له اليوم...', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(onPressed: _addJournalEntry, icon: const Icon(Icons.add)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ..._entries.take(5).map((e) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.favorite, color: Colors.teal, size: 18),
                          title: Text(e),
                        )),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== 5. قسم التطوير الشخصي والتعلم السريع ====================
class LearningScreen extends StatefulWidget {
  const LearningScreen({super.key});

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  bool _showAnswer = false;
  int _cardIndex = 0;
  int _quoteIndex = 0;

  final List<Map<String, String>> _cards = [
    {'q': 'Resilience', 'a': 'المرونة النفسية والقدرة على التعافي سريعاً من الصعوبات.'},
    {'q': 'Consistency', 'a': 'الاستمرارية والالتزام اليومي (أهم من الحماس المؤقت).'},
    {'q': 'قاعدة الدقيقتين', 'a': 'إذا كانت المهمة تستغرق أقل من دقيقتين، أنجزها فوراً دون تأجيل.'},
    {'q': 'Deep Work', 'a': 'العمل العميق بتركيز تام دون مشتتات لإنتاج أعلى قيمة في وقت أقل.'},
  ];

  final List<String> _quotes = [
    'قليلٌ دائم خيرٌ من كثيرٍ منقطع.',
    'الانضباط هو الجسر بين الأهداف والإنجازات.',
    'صحتك النفسية والجسدية هي رأس مالك الحقيقي، استثمر فيها كل يوم.',
    'لا تنتظر الظروف المثالية، ابدأ بما تملك ومن حيث أنت.',
  ];

  void _rateCard(bool hard) async {
    await ZadStorage.addXp(5);
    setState(() {
      if (hard && _cards.length > 1) {
        final item = _cards.removeAt(_cardIndex);
        _cards.add(item);
      } else {
        _cardIndex = (_cardIndex + 1) % _cards.length;
      }
      _showAnswer = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final card = _cards[_cardIndex];
    return Scaffold(
      appBar: AppBar(title: const Text('التطوير الشخصي والتعلم السريع')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Align(alignment: Alignment.centerRight, child: Text('بطاقات الحفظ بالتكرار المتباعد 🗂️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => setState(() => _showAnswer = !_showAnswer),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: double.infinity,
                height: 200,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _showAnswer ? Colors.purple.withValues(alpha: 0.15) : Colors.purple.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.purple.withValues(alpha: 0.4)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_showAnswer ? 'الإجابة:' : 'اضغط لقلب البطاقة', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 12),
                    Text(
                      _showAnswer ? card['a']! : card['q']!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton(onPressed: () => _rateCard(true), child: const Text('صعبة (أعدها)')),
                FilledButton(onPressed: () => _rateCard(false), child: const Text('سهلة (التالية)')),
              ],
            ),
            const SizedBox(height: 28),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.format_quote, color: Colors.purple),
                        SizedBox(width: 8),
                        Text('حكمة اليوم التحفيزية', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(_quotes[_quoteIndex], textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => setState(() => _quoteIndex = (_quoteIndex + 1) % _quotes.length),
                      child: const Text('حكمة أخرى'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 6. قسم الطوارئ والإسعافات الأولية ====================
class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  bool _cprActive = false;
  bool _beat = false;
  Timer? _cprTimer;

  final List<Map<String, String>> _guides = [
    {
      'title': 'الإنعاش القلبي الرئوي (CPR)',
      'body': '1. تأكد من أمان المكان وفحص الوعي والتنفس.\n2. اطلب الإسعاف (123).\n3. ضع كعب اليد في منتصف الصدر واضغط بقوة وبمعدل 100-120 ضغطة/دقيقة (استخدم النبض بالأسفل).',
    },
    {
      'title': 'الاختناق (مناورة هيمليك)',
      'body': 'قف خلف المصاب، لف ذراعيك حول خصره، اصنع قبضة فوق السرة واضغط للداخل وللأعلى بقوة حتى يخرج الجسم الغريب.',
    },
    {
      'title': 'الحروق البسيطة والمتوسطة',
      'body': 'برّد مكان الحرق بماء فاتر جارٍ لمدة 15-20 دقيقة. ممنوع وضع معجون أسنان أو ثلج أو بن.',
    },
    {
      'title': 'النزيف الحاد',
      'body': 'اضغط مباشرة على الجرح بشاش أو قماش نظيف لمدة 10 دقائق متواصلة دون رفع الشاش، وارفع العضو المصاب للأعلى.',
    },
  ];

  void _toggleCprMetronome() {
    if (_cprActive) {
      _cprTimer?.cancel();
      setState(() {
        _cprActive = false;
        _beat = false;
      });
    } else {
      setState(() => _cprActive = true);
      _cprTimer = Timer.periodic(const Duration(milliseconds: 545), (_) {
        HapticFeedback.heavyImpact();
        setState(() => _beat = !_beat);
      });
    }
  }

  Future<void> _call(String num) async {
    final uri = Uri(scheme: 'tel', path: num);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  void dispose() {
    _cprTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الطوارئ والإسعافات الأولية'),
        backgroundColor: Colors.red.withValues(alpha: 0.15),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => _call('123'), icon: const Icon(Icons.local_hospital), label: const Text('الإسعاف 123'))),
              const SizedBox(width: 8),
              Expanded(child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Colors.blueGrey), onPressed: () => _call('122'), icon: const Icon(Icons.local_police), label: const Text('النجدة 122'))),
              const SizedBox(width: 8),
              Expanded(child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Colors.deepOrange), onPressed: () => _call('180'), icon: const Icon(Icons.fire_truck), label: const Text('المطافئ 180'))),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            color: _beat ? Colors.red.withValues(alpha: 0.25) : Colors.red.withValues(alpha: 0.08),
            child: ListTile(
              leading: Icon(Icons.monitor_heart, color: Colors.red, size: _beat ? 36 : 30),
              title: const Text('بندول الإنعاش القلبي (110 نبضة/دقيقة)', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('يعطي نبضة اهتزاز وضوء لضبط سرعة ضغطات الصدر'),
              trailing: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: _toggleCprMetronome,
                child: Text(_cprActive ? 'إيقاف' : 'تشغيل'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ..._guides.map((g) => Card(
                child: ExpansionTile(
                  leading: const Icon(Icons.medical_information, color: Colors.redAccent),
                  title: Text(g['title']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(g['body']!, style: const TextStyle(height: 1.6)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ==================== 7. قسم التحفيز ومشاركة الـ QR ====================
class GamificationScreen extends StatefulWidget {
  const GamificationScreen({super.key});

  @override
  State<GamificationScreen> createState() => _GamificationScreenState();
}

class _GamificationScreenState extends State<GamificationScreen> {
  int _xp = 0;
  final _challengeCtrl = TextEditingController(text: 'تحدي 7 أيام: 2 لتر ماء + 20 دقيقة رياضة');
  String _qrData = 'ZAD-CHALLENGE|7Days|Water2L+Workout20m';

  @override
  void initState() {
    super.initState();
    ZadStorage.getXp().then((v) {
      if (mounted) setState(() => _xp = v);
    });
  }

  @override
  void dispose() {
    _challengeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badges = [
      {'name': 'بداية زاد', 'req': 10, 'icon': Icons.flag},
      {'name': 'رياضي ملتزم', 'req': 50, 'icon': Icons.fitness_center},
      {'name': 'صانع العادات', 'req': 100, 'icon': Icons.verified},
      {'name': 'سيد التركيز', 'req': 200, 'icon': Icons.workspace_premium},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('الأوسمة ومشاركة التحديات (QR)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('نقاطك الحالية: $_xp XP 🏆', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: badges.map((b) {
                      final unlocked = _xp >= (b['req'] as int);
                      return Chip(
                        avatar: Icon(b['icon'] as IconData, color: unlocked ? Colors.amber : Colors.grey),
                        label: Text('${b['name']} (${b['req']} XP)'),
                        backgroundColor: unlocked ? Colors.amber.withValues(alpha: 0.15) : null,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('مشاركة تحدٍ مع صديق وجهاً لوجه (بدون نت) 📲', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _challengeCtrl,
                    decoration: const InputDecoration(labelText: 'اكتب نص التحدي', border: OutlineInputBorder()),
                    onChanged: (v) => setState(() => _qrData = 'ZAD-CHALLENGE|$v'),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: QrImageView(
                      data: _qrData,
                      version: QrVersions.auto,
                      size: 190,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('اجعل صديقك يمسح الرمز لبدء التحدي معك في نفس اللحظة', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== 8. شاشة عن التطبيق وتواصل معنا ====================
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  final String phone = '01129220696';
  final String whatsapp = '201129220696';

  Future<void> _launch(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('عن التطبيق وتواصل معنا')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 24),
            const Icon(Icons.spa_rounded, size: 80, color: Color(0xFF2E7D6B)),
            const SizedBox(height: 12),
            const Text('ZAD', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 6),
            const Text('مطور البرنامج: خالد محمود حسن', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text(
              'تطبيق شامل لتحسين جودة الحياة ويعمل بالكامل بدون اتصال بالإنترنت لحفظ خصوصيتك.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 32),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 14, right: 16, left: 16),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text('تواصل معنا', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.phone, color: Colors.blue),
                    title: const Text('اتصال هاتفي'),
                    subtitle: Text(phone),
                    onTap: () => _launch(Uri(scheme: 'tel', path: phone)),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.chat, color: Colors.green),
                    title: const Text('تواصل عبر الواتساب'),
                    subtitle: Text(phone),
                    onTap: () => _launch(Uri.parse('https://wa.me/$whatsapp')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
