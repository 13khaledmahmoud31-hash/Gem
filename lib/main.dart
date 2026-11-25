import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
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
        colorSchemeSeed: const Color(0xFF1F7A68),
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF3F6F5),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1F7A68),
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0C1110),
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

// ==================== أدوات الاتصال والواتساب المضمونة ====================
class ContactHelper {
  static Future<void> callNumber(BuildContext context, String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok) return;
    } catch (_) {}
    await Clipboard.setData(ClipboardData(text: phone));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم نسخ الرقم $phone للحافظة')),
      );
    }
  }

  static Future<void> openWhatsApp(BuildContext context, String internationalPhone, String localPhone) async {
    final nativeUri = Uri.parse('whatsapp://send?phone=$internationalPhone');
    final webUri = Uri.parse('https://wa.me/$internationalPhone');
    try {
      final okNative = await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
      if (okNative) return;
    } catch (_) {}
    try {
      final okWeb = await launchUrl(webUri, mode: LaunchMode.externalApplication);
      if (okWeb) return;
    } catch (_) {}
    await Clipboard.setData(ClipboardData(text: localPhone));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر فتح واتساب تلقائياً، تم نسخ الرقم $localPhone')),
      );
    }
  }
}

// ==================== التخزين المحلي الشامل (Offline Storage) ====================
class ZadStorage {
  static Future<Map<String, int>> getStats() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'xp': prefs.getInt('zad_xp') ?? 0,
      'body': prefs.getInt('zad_stat_body') ?? 0,
      'mind': prefs.getInt('zad_stat_mind') ?? 0,
      'calm': prefs.getInt('zad_stat_calm') ?? 0,
      'skill': prefs.getInt('zad_stat_skill') ?? 0,
    };
  }

  static Future<void> addXp(int points, {String pillar = 'body'}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('zad_xp', (prefs.getInt('zad_xp') ?? 0) + points);
    await prefs.setInt('zad_stat_$pillar', (prefs.getInt('zad_stat_$pillar') ?? 0) + points);
  }

  static Future<int> getWater() async => (await SharedPreferences.getInstance()).getInt('zad_water') ?? 0;
  static Future<void> setWater(int ml) async => (await SharedPreferences.getInstance()).setInt('zad_water', ml);

  static Future<List<Map<String, dynamic>>> getJsonList(String key) async {
    final raw = (await SharedPreferences.getInstance()).getString(key);
    if (raw == null || raw.isEmpty) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }

  static Future<void> setJsonList(String key, List<Map<String, dynamic>> list) async {
    await (await SharedPreferences.getInstance()).setString(key, jsonEncode(list));
  }

  static Future<List<String>> getStringList(String key, [List<String> fallback = const []]) async {
    return (await SharedPreferences.getInstance()).getStringList(key) ?? List<String>.from(fallback);
  }

  static Future<void> setStringList(String key, List<String> list) async {
    await (await SharedPreferences.getInstance()).setStringList(key, list);
  }

  static Future<String?> getString(String key) async => (await SharedPreferences.getInstance()).getString(key);
  static Future<void> setString(String key, String? val) async {
    final prefs = await SharedPreferences.getInstance();
    if (val == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, val);
    }
  }
}

// ==================== الشاشة الرئيسية (Bento Dashboard) ====================
class DashboardScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;

  const DashboardScreen({super.key, required this.onToggleTheme, required this.isDark});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _xp = 0;
  int _waterMl = 0;
  int _caloriesToday = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await ZadStorage.getStats();
    final water = await ZadStorage.getWater();
    final meals = await ZadStorage.getJsonList('zad_meals');
    int cal = 0;
    for (final m in meals) {
      cal += (m['cal'] as num?)?.toInt() ?? 0;
    }
    if (mounted) {
      setState(() {
        _xp = stats['xp'] ?? 0;
        _waterMl = water;
        _caloriesToday = cal;
      });
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    final level = (_xp ~/ 100) + 1;
    final progress = (_xp % 100) / 100.0;

    final modules = [
      _ModuleCard('اللياقة والتمارين', 'رسوم متحركة تفاعلية + مؤقت', Icons.fitness_center, Colors.orange, const FitnessScreen()),
      _ModuleCard('التغذية والسعرات', 'سجل أكلك + وصفات الثلاجة', Icons.restaurant_menu, Colors.green, const NutritionScreen()),
      _ModuleCard('الإنتاجية والمهام', 'بومودورو، مهام، وعادات', Icons.timer, Colors.indigo, const ProductivityScreen()),
      _ModuleCard('الصحة النفسية', 'تنفس، مزاج، ويوميات سرية', Icons.self_improvement, Colors.teal, const WellnessScreen()),
      _ModuleCard('التعلم والبطاقات', 'تكرار متباعد + أضف بطاقتك', Icons.style, Colors.purple, const LearningScreen()),
      _ModuleCard('الطوارئ والإسعاف', '7 حالات + CPR + رقم عائلي', Icons.medical_services, Colors.red, const EmergencyScreen()),
      _ModuleCard('التحديات والـ QR', 'توازنك + تحدي الأصدقاء', Icons.qr_code_2, Colors.amber.shade800, const GamificationScreen()),
      _ModuleCard('عن ZAD وتواصل', 'خالد محمود حسن • 01129220696', Icons.support_agent, Colors.blueGrey, const AboutScreen()),
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
            tooltip: 'طوارئ سريعة',
            icon: const Icon(Icons.emergency, color: Colors.redAccent),
            onPressed: () => _open(const EmergencyScreen()),
          ),
          IconButton(
            tooltip: 'تبديل المظهر',
            icon: Icon(widget.isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            tooltip: 'عن المطور وتواصل معنا',
            icon: const Icon(Icons.info_outline),
            onPressed: () => _open(const AboutScreen()),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF1F7A68), Color(0xFF12463B)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('المستوى $level • $_xp XP', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          _BadgeChip('💧 $_waterMl مل'),
                          const SizedBox(width: 6),
                          _BadgeChip('🔥 $_caloriesToday سعرة'),
                        ],
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
                  const Text('مطور البرنامج: خالد محمود حسن', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text('أقسام زاد المتكاملة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                    elevation: 0.7,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _open(item.screen),
                      child: Padding(
                        padding: const EdgeInsets.all(13),
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

class _BadgeChip extends StatelessWidget {
  final String text;
  const _BadgeChip(this.text);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11)),
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

// ==================== 1. قسم اللياقة + محرك الأنيميشن التفاعلي ====================
enum ExercisePose { highKnees, wallPushup, squat, jumpingJacks, pushup, plank, lunge, burpee, crunch }

class ExerciseData {
  final String name;
  final int seconds;
  final String muscle;
  final String steps;
  final ExercisePose pose;
  const ExerciseData(this.name, this.seconds, this.muscle, this.steps, this.pose);
}

class FitnessScreen extends StatefulWidget {
  const FitnessScreen({super.key});

  @override
  State<FitnessScreen> createState() => _FitnessScreenState();
}

class _FitnessScreenState extends State<FitnessScreen> with SingleTickerProviderStateMixin {
  String _level = 'مبتدئ';
  int _activeIndex = 0;
  int _secondsLeft = 30;
  bool _running = false;
  Timer? _timer;
  late AnimationController _animCtrl;

  final Map<String, List<ExerciseData>> _workouts = {
    'مبتدئ': const [
      ExerciseData('الجري/المشي في المكان', 30, 'القلب والأرجل', 'ارفع ركبتيك بالتبادل وحرّك ذراعيك مع تنظيم التنفس.', ExercisePose.highKnees),
      ExerciseData('ضغط على الحائط', 30, 'الصدر والذراعين', 'قف على بعد ذراع من الحائط، ادفع بصدرك للأمام ثم ارجع ببطء.', ExercisePose.wallPushup),
      ExerciseData('قرفصاء (سكوات)', 30, 'الفخذين والمؤخرة', 'انزل بظهر مستقيم كأنك تجلس على كرسي مع فرد الذراعين للأمام.', ExercisePose.squat),
      ExerciseData('طحن البطن البسيط', 30, 'عضلات البطن', 'استلقِ على ظهرك واثنِ ركبتيك ثم ارفع كتفيك للأعلى برفق.', ExercisePose.crunch),
    ],
    'متوسط': const [
      ExerciseData('قفز النجمة (Jumping Jacks)', 40, 'كامل الجسم', 'اقفز مع فتح الساقين ورفع اليدين فوق الرأس بتناسق.', ExercisePose.jumpingJacks),
      ExerciseData('تمرين الضغط الكلاسيكي', 40, 'الصدر والترايسبس', 'حافظ على استقامة جسمك كاللوح وانزل بصدرك قرب الأرض.', ExercisePose.pushup),
      ExerciseData('تمرين الطعن (Lunges)', 40, 'الأرجل والتوازن', 'اخطُ للأمام واثنِ الركبتين بزاوية 90 درجة ثم عد للوقوف.', ExercisePose.lunge),
      ExerciseData('بلانك (Plank)', 45, 'الكور والبطن', 'ارتكز على الساعدين واشدد البطن دون تقوس أسفل الظهر.', ExercisePose.plank),
    ],
    'متقدم': const [
      ExerciseData('تمرين بيربي (Burpees)', 45, 'حرق عالي وكامل الجسم', 'انزل سكوات ثم وضع الضغط ثم اقفز للأعلى بأقصى طاقة.', ExercisePose.burpee),
      ExerciseData('ضغط سريع متواصل', 45, 'الصدر والكتفين', 'انزل واصعد بتحكم كامل مع الحفاظ على ثبات الجذع.', ExercisePose.pushup),
      ExerciseData('سكوات عميق', 45, 'الأرجل والقوة', 'انزل لأقصى عمق مريح مع ثبات الكعبين على الأرض.', ExercisePose.squat),
      ExerciseData('بلانك تحدي الثبات', 60, 'قوة الجذع', 'ثبات تام على الساعدين مع تنفس منتظم هادئ.', ExercisePose.plank),
    ],
  };

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
    _secondsLeft = _workouts[_level]![0].seconds;
  }

  void _selectWorkout(int index) {
    _timer?.cancel();
    final ex = _workouts[_level]![index];
    setState(() {
      _activeIndex = index;
      _running = false;
      _secondsLeft = ex.seconds;
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
          await ZadStorage.addXp(25, pillar: 'body');
          if (mounted) {
            setState(() {
              _running = false;
              _secondsLeft = 0;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('بطل! أتممت التمرين وحصلت على +25 نقطة للجسد 💪')),
            );
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = _workouts[_level]!;
    final current = list[_activeIndex];

    return Scaffold(
      appBar: AppBar(title: const Text('اللياقة البدنية (رسوم متحركة)')),
      body: Padding(
        padding: const EdgeInsets.all(14),
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
                      _secondsLeft = _workouts[lvl]![0].seconds;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            // شاشة الأنيميشن التفاعلي للتمرين
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(current.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              Text('العضلة المستهدفة: ${current.muscle}', style: const TextStyle(fontSize: 12, color: Colors.orange)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text('$_secondsLeft ث', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 165,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: AnimatedBuilder(
                        animation: _animCtrl,
                        builder: (_, __) => CustomPaint(
                          painter: _ExerciseFigurePainter(
                            pose: current.pose,
                            progress: _animCtrl.value,
                            bodyColor: Theme.of(context).colorScheme.primary,
                            accentColor: Colors.orange,
                            groundColor: Colors.grey.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(current.steps, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: _activeIndex > 0 ? () => _selectWorkout(_activeIndex - 1) : null,
                          icon: const Icon(Icons.skip_next),
                          tooltip: 'السابق',
                        ),
                        FilledButton.icon(
                          onPressed: _toggleTimer,
                          icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                          label: Text(_running ? 'إيقاف' : 'ابدأ التمرين'),
                        ),
                        IconButton(
                          onPressed: () => _selectWorkout(_activeIndex),
                          icon: const Icon(Icons.refresh),
                          tooltip: 'إعادة',
                        ),
                        IconButton(
                          onPressed: _activeIndex < list.length - 1 ? () => _selectWorkout(_activeIndex + 1) : null,
                          icon: const Icon(Icons.skip_previous),
                          tooltip: 'التالي',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final ex = list[i];
                  return Card(
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        backgroundColor: i == _activeIndex ? Colors.orange : null,
                        child: Text('${i + 1}', style: TextStyle(color: i == _activeIndex ? Colors.white : null)),
                      ),
                      title: Text(ex.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${ex.muscle} • ${ex.seconds} ثانية'),
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

class _ExerciseFigurePainter extends CustomPainter {
  final ExercisePose pose;
  final double progress;
  final Color bodyColor;
  final Color accentColor;
  final Color groundColor;

  _ExerciseFigurePainter({
    required this.pose,
    required this.progress,
    required this.bodyColor,
    required this.accentColor,
    required this.groundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final gy = h * 0.86;
    final t = 0.5 - 0.5 * math.cos(progress * 2 * math.pi); // حركة ناعمة ذهاباً وإياباً

    final groundPaint = Paint()
      ..color = groundColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.1, gy), Offset(w * 0.9, gy), groundPaint);

    final limbPaint = Paint()
      ..color = bodyColor
      ..strokeWidth = 7.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final accentPaint = Paint()
      ..color = accentColor
      ..strokeWidth = 7.5
      ..strokeCap = StrokeCap.round;

    final headPaint = Paint()..color = bodyColor;

    void drawBone(Offset a, Offset b, {bool highlight = false}) {
      canvas.drawLine(a, b, highlight ? accentPaint : limbPaint);
    }

    void drawHead(Offset center) {
      canvas.drawCircle(center, 11, headPaint);
    }

    final cx = w * 0.5;

    switch (pose) {
      case ExercisePose.squat:
        final foot = Offset(cx + 8, gy);
        final knee = Offset(cx - 18 * t, gy - 32 + 4 * t);
        final hip = Offset(cx + 18 * t + 6, gy - 68 + 26 * t);
        final shoulder = Offset(hip.dx - 8 - 10 * t, hip.dy - 40);
        final hand = Offset(shoulder.dx - 34 * t - 8, shoulder.dy + 26 * (1 - t) + 4 * t);
        drawBone(foot, knee, highlight: true);
        drawBone(knee, hip, highlight: true);
        drawBone(hip, shoulder);
        drawBone(shoulder, hand);
        drawHead(Offset(shoulder.dx - 2, shoulder.dy - 16));
        break;

      case ExercisePose.wallPushup:
        final wallX = w * 0.30;
        canvas.drawLine(Offset(wallX, h * 0.12), Offset(wallX, gy), groundPaint);
        final foot = Offset(w * 0.62, gy);
        final hip = Offset(w * 0.53 - 18 * t, gy - 54);
        final shoulder = Offset(w * 0.46 - 24 * t, gy - 98);
        final hand = Offset(wallX + 2, gy - 90);
        final elbow = Offset((shoulder.dx + hand.dx) / 2 + 8 * t, (shoulder.dy + hand.dy) / 2 + 12 * t);
        drawBone(foot, hip);
        drawBone(hip, shoulder);
        drawBone(shoulder, elbow, highlight: true);
        drawBone(elbow, hand, highlight: true);
        drawHead(Offset(shoulder.dx - 4, shoulder.dy - 16));
        break;

      case ExercisePose.pushup:
        final foot = Offset(w * 0.78, gy);
        final hand = Offset(w * 0.27, gy);
        final shoulder = Offset(w * 0.29, gy - 46 + 26 * t);
        final hip = Offset((foot.dx + shoulder.dx) / 2, (foot.dy + shoulder.dy) / 2 - 2);
        final elbow = Offset(shoulder.dx + 12 * t, (shoulder.dy + gy) / 2);
        drawBone(foot, hip);
        drawBone(hip, shoulder);
        drawBone(shoulder, elbow, highlight: true);
        drawBone(elbow, hand, highlight: true);
        drawHead(Offset(shoulder.dx - 12, shoulder.dy - 10));
        break;

      case ExercisePose.plank:
        final foot = Offset(w * 0.78, gy);
        final elbow = Offset(w * 0.28, gy);
        final hand = Offset(w * 0.20, gy);
        final shoulder = Offset(w * 0.29, gy - 26 - 2 * t);
        final hip = Offset(w * 0.53, gy - 15 - 2 * t);
        drawBone(foot, hip);
        drawBone(hip, shoulder, highlight: true);
        drawBone(shoulder, elbow);
        drawBone(elbow, hand);
        drawHead(Offset(shoulder.dx - 13, shoulder.dy - 6));
        // نبض حول عضلات البطن
        canvas.drawCircle(
          hip,
          10 + 4 * t,
          Paint()..color = accentColor.withValues(alpha: 0.28),
        );
        break;

      case ExercisePose.jumpingJacks:
        final jump = t * 14;
        final hip = Offset(cx, gy - 54 - jump);
        final shoulder = Offset(cx, hip.dy - 40);
        final spread = 6 + 24 * t;
        drawBone(hip, Offset(cx - spread, gy - jump), highlight: true);
        drawBone(hip, Offset(cx + spread, gy - jump), highlight: true);
        drawBone(hip, shoulder);
        final armY = shoulder.dy + 30 - 62 * t;
        drawBone(shoulder, Offset(cx - 18 - 6 * t, armY), highlight: true);
        drawBone(shoulder, Offset(cx + 18 + 6 * t, armY), highlight: true);
        drawHead(Offset(cx, shoulder.dy - 16));
        break;

      case ExercisePose.highKnees:
        final s = math.sin(progress * 2 * math.pi);
        final hip = Offset(cx, gy - 56);
        final shoulder = Offset(cx, hip.dy - 40);
        final lKnee = Offset(cx - 12, gy - 28 - (s > 0 ? 18 * s : 0));
        final rKnee = Offset(cx + 12, gy - 28 - (s < 0 ? 18 * (-s) : 0));
        final lFoot = Offset(cx - 10, gy - (s > 0 ? 22 * s : 0));
        final rFoot = Offset(cx + 10, gy - (s < 0 ? 22 * (-s) : 0));
        drawBone(hip, lKnee, highlight: s > 0);
        drawBone(lKnee, lFoot, highlight: s > 0);
        drawBone(hip, rKnee, highlight: s < 0);
        drawBone(rKnee, rFoot, highlight: s < 0);
        drawBone(hip, shoulder);
        drawBone(shoulder, Offset(cx - 18, shoulder.dy + 22 - 14 * s));
        drawBone(shoulder, Offset(cx + 18, shoulder.dy + 22 + 14 * s));
        drawHead(Offset(cx, shoulder.dy - 16));
        break;

      case ExercisePose.lunge:
        final fFoot = Offset(cx - 32, gy);
        final bFoot = Offset(cx + 36, gy);
        final hip = Offset(cx, gy - 62 + 22 * t);
        final fKnee = Offset(cx - 28, gy - 32 + 6 * t);
        final bKnee = Offset(cx + 22, gy - 28 + 20 * t);
        final shoulder = Offset(cx - 2, hip.dy - 40);
        drawBone(fFoot, fKnee, highlight: true);
        drawBone(fKnee, hip, highlight: true);
        drawBone(bFoot, bKnee);
        drawBone(bKnee, hip);
        drawBone(hip, shoulder);
        drawBone(shoulder, Offset(cx - 14, shoulder.dy + 26));
        drawHead(Offset(shoulder.dx, shoulder.dy - 16));
        break;

      case ExercisePose.crunch:
        final hip = Offset(cx + 6, gy - 4);
        final knee = Offset(cx - 28, gy - 34);
        final foot = Offset(cx - 48, gy);
        final shoulder = Offset(cx + 46 - 18 * t, gy - 8 - 34 * t);
        drawBone(foot, knee);
        drawBone(knee, hip);
        drawBone(hip, shoulder, highlight: true);
        drawBone(shoulder, Offset(shoulder.dx - 10, shoulder.dy - 14));
        drawHead(Offset(shoulder.dx + 10 - 4 * t, shoulder.dy - 12));
        break;

      case ExercisePose.burpee:
        if (progress < 0.35) {
          final p = progress / 0.35;
          final hip = Offset(cx, gy - 58 + 30 * p);
          final shoulder = Offset(cx - 8 * p, hip.dy - 38 + 12 * p);
          drawBone(Offset(cx, gy), hip);
          drawBone(hip, shoulder);
          drawBone(shoulder, Offset(cx - 14, shoulder.dy + 28));
          drawHead(Offset(shoulder.dx, shoulder.dy - 15));
        } else if (progress < 0.7) {
          final p = (progress - 0.35) / 0.35;
          final k = math.sin(p * math.pi);
          final foot = Offset(w * 0.74, gy);
          final hand = Offset(w * 0.28, gy);
          final shoulder = Offset(w * 0.30, gy - 38 + 14 * k);
          final hip = Offset((foot.dx + shoulder.dx) / 2, (foot.dy + shoulder.dy) / 2);
          drawBone(foot, hip);
          drawBone(hip, shoulder, highlight: true);
          drawBone(shoulder, hand);
          drawHead(Offset(shoulder.dx - 12, shoulder.dy - 8));
        } else {
          final p = (progress - 0.7) / 0.3;
          final jump = math.sin(p * math.pi) * 28;
          final hip = Offset(cx, gy - 54 - jump);
          final shoulder = Offset(cx, hip.dy - 40);
          drawBone(hip, Offset(cx - 8, gy - jump), highlight: true);
          drawBone(hip, Offset(cx + 8, gy - jump), highlight: true);
          drawBone(hip, shoulder);
          drawBone(shoulder, Offset(cx - 16, shoulder.dy - 26));
          drawBone(shoulder, Offset(cx + 16, shoulder.dy - 26));
          drawHead(Offset(cx, shoulder.dy - 16));
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _ExerciseFigurePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.pose != pose || oldDelegate.bodyColor != bodyColor;
  }
}

// ==================== 2. قسم التغذية ومفكرة الأكل + وصفات الثلاجة ====================
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
  double _targetCalories = 2200;
  List<Map<String, dynamic>> _meals = [];
  final Set<String> _selectedIngredients = {'بيض', 'طماطم'};

  final List<Map<String, dynamic>> _localFoods = [
    {'name': 'طبق فول بالزيت والليمون', 'cal': 220},
    {'name': '2 قرص طعمية', 'cal': 160},
    {'name': 'رغيف عيش بلدي', 'cal': 240},
    {'name': 'بيضة مسلوقة', 'cal': 75},
    {'name': 'طبق أرز (6 ملاعق)', 'cal': 210},
    {'name': 'ربع فرخة مشوية', 'cal': 260},
    {'name': 'علبة تونة مصفاة', 'cal': 140},
    {'name': 'طبق سلطة خضراء', 'cal': 50},
    {'name': 'كوب زبادي لايت', 'cal': 95},
    {'name': 'ثمرة موز / تفاح', 'cal': 90},
    {'name': 'شوفان باللبن (كوب)', 'cal': 250},
  ];

  final List<Map<String, dynamic>> _recipes = [
    {'title': 'أومليت بالخضار السريع', 'cal': '290 سعرة', 'time': '7 د', 'ingredients': ['بيض', 'طماطم'], 'steps': 'اخفق بيضتين مع طماطم مقطعة ورشة فلفل في مقلاة غير لاصقة.'},
    {'title': 'شوفان بالموز والقرفة', 'cal': '320 سعرة', 'time': '5 د', 'ingredients': ['شوفان', 'موز'], 'steps': 'اغلي الشوفان بالماء أو اللبن 4 دقائق وأضف شرائح الموز.'},
    {'title': 'سلطة تونة بالليمون', 'cal': '260 سعرة', 'time': '4 د', 'ingredients': ['تونة', 'طماطم'], 'steps': 'صفِّ التونة واخلطها مع طماطم وخيار وليمون وكمون.'},
    {'title': 'زبادي بروتين بالشوفان', 'cal': '250 سعرة', 'time': '3 د', 'ingredients': ['زبادي', 'شوفان', 'موز'], 'steps': 'اخلط علبة زبادي مع ملعقتي شوفان وموزة مقطعة.'},
    {'title': 'صدور دجاج مشوية بالطماطم', 'cal': '370 سعرة', 'time': '15 د', 'ingredients': ['دجاج', 'طماطم'], 'steps': 'تبل الدجاج بالليمون والبهارات واشوِه على طاسة ساخنة.'},
    {'title': 'فول بالبيض (بروتين عالي)', 'cal': '340 سعرة', 'time': '6 د', 'ingredients': ['فول', 'بيض', 'طماطم'], 'steps': 'سخّن الفول مع الطماطم وأضف بيضة فوقه حتى تنضج.'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    _calculateCalories();
  }

  Future<void> _loadData() async {
    final w = await ZadStorage.getWater();
    final m = await ZadStorage.getJsonList('zad_meals');
    if (mounted) {
      setState(() {
        _waterMl = w;
        _meals = m;
      });
    }
  }

  Future<void> _addWater(int ml) async {
    final updated = _waterMl + ml;
    await ZadStorage.setWater(updated);
    await ZadStorage.addXp(5, pillar: 'body');
    setState(() => _waterMl = updated);
  }

  Future<void> _logFood(String name, int cal) async {
    setState(() => _meals.insert(0, {'name': name, 'cal': cal}));
    await ZadStorage.setJsonList('zad_meals', _meals);
    await ZadStorage.addXp(5, pillar: 'body');
  }

  void _calculateCalories() {
    final w = double.tryParse(_weightCtrl.text) ?? 75;
    final h = double.tryParse(_heightCtrl.text) ?? 175;
    final a = double.tryParse(_ageCtrl.text) ?? 26;
    final bmr = (10 * w) + (6.25 * h) - (5 * a) + (_isMale ? 5 : -161);
    setState(() => _targetCalories = bmr * 1.45);
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
    final w = double.tryParse(_weightCtrl.text) ?? 75;
    final targetWater = (w * 35).round();
    final eatenCal = _meals.fold<int>(0, (sum, m) => sum + ((m['cal'] as num?)?.toInt() ?? 0));
    final remainingCal = (_targetCalories.round() - eatenCal);
    final filteredRecipes = _recipes.where((r) => (r['ingredients'] as List).any((i) => _selectedIngredients.contains(i))).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('التغذية والصحة الذكية')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // السعرات اليومية
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('مفكرة السعرات اليومية 🔥', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('متبقي: $remainingCal سعرة', style: TextStyle(fontWeight: FontWeight.bold, color: remainingCal >= 0 ? Colors.green : Colors.red)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (eatenCal / (_targetCalories > 0 ? _targetCalories : 2000)).clamp(0.0, 1.0),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  const SizedBox(height: 8),
                  Text('المستهلك: $eatenCal / الهدف: ${_targetCalories.round()} سعرة', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _localFoods.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (_, i) {
                        final f = _localFoods[i];
                        return ActionChip(
                          label: Text('+ ${f['name']} (${f['cal']})', style: const TextStyle(fontSize: 11.5)),
                          onPressed: () => _logFood(f['name'], f['cal']),
                        );
                      },
                    ),
                  ),
                  if (_meals.isNotEmpty) ...[
                    const Divider(),
                    Wrap(
                      spacing: 6,
                      children: _meals.take(4).map((m) => Chip(
                            label: Text('${m['name']} (${m['cal']})', style: const TextStyle(fontSize: 11)),
                            onDeleted: () async {
                              setState(() => _meals.remove(m));
                              await ZadStorage.setJsonList('zad_meals', _meals);
                            },
                          )).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // الماء
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('متعقب شرب الماء 💧', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('$_waterMl / $targetWater مل', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: (_waterMl / (targetWater > 0 ? targetWater : 2500)).clamp(0.0, 1.0), minHeight: 7, borderRadius: BorderRadius.circular(8)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton(onPressed: () => _addWater(250), child: const Text('+250 مل')),
                      const SizedBox(width: 8),
                      ElevatedButton(onPressed: () => _addWater(500), child: const Text('+500 مل')),
                      const Spacer(),
                      TextButton(onPressed: () async { await ZadStorage.setWater(0); setState(() => _waterMl = 0); }, child: const Text('تصفير')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // حاسبة الاحتياج
          ExpansionTile(
            title: const Text('ضبط حاسبة السعرات حسب جسمك ⚙️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _weightCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الوزن', border: OutlineInputBorder()))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: _heightCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الطول', border: OutlineInputBorder()))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: _ageCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'العمر', border: OutlineInputBorder()))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ChoiceChip(label: const Text('ذكر'), selected: _isMale, onSelected: (_) => setState(() { _isMale = true; _calculateCalories(); })),
                        const SizedBox(width: 8),
                        ChoiceChip(label: const Text('أنثى'), selected: !_isMale, onSelected: (_) => setState(() { _isMale = false; _calculateCalories(); })),
                        const Spacer(),
                        FilledButton(onPressed: _calculateCalories, child: const Text('تحديث')),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text('وصفات سريعة من المتاح في منزلك 🥗', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: ['بيض', 'شوفان', 'تونة', 'طماطم', 'زبادي', 'دجاج', 'موز', 'فول'].map((ing) {
              return FilterChip(
                label: Text(ing),
                selected: _selectedIngredients.contains(ing),
                onSelected: (v) => setState(() => v ? _selectedIngredients.add(ing) : _selectedIngredients.remove(ing)),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
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
  bool _pulseMode = false;
  Timer? _timer;

  List<String> _habits = ['قراءة 10 صفحات', 'التمرين 20 دقيقة', 'أذكار الصباح والمساء', 'نوم قبل 11 م'];
  List<String> _doneHabits = [];
  List<Map<String, dynamic>> _todos = [];
  final _habitCtrl = TextEditingController();
  final _todoCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final allH = await ZadStorage.getStringList('zad_all_habits', _habits);
    final doneH = await ZadStorage.getStringList('zad_done_habits');
    final todos = await ZadStorage.getJsonList('zad_todos');
    if (mounted) {
      setState(() {
        _habits = allH;
        _doneHabits = doneH;
        _todos = todos;
      });
    }
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
          if (_pulseMode && _secondsRemaining % 5 == 0) HapticFeedback.selectionClick();
        } else {
          t.cancel();
          HapticFeedback.heavyImpact();
          await ZadStorage.addXp(25, pillar: 'mind');
          if (mounted) {
            setState(() => _running = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ممتاز! أتممت جلسة التركيز +25 نقطة للعقل 🎯')),
            );
          }
        }
      });
    }
  }

  Future<void> _addHabit() async {
    final txt = _habitCtrl.text.trim();
    if (txt.isEmpty) return;
    setState(() {
      _habits.add(txt);
      _habitCtrl.clear();
    });
    await ZadStorage.setStringList('zad_all_habits', _habits);
  }

  Future<void> _addTodo() async {
    final txt = _todoCtrl.text.trim();
    if (txt.isEmpty) return;
    setState(() {
      _todos.insert(0, {'title': txt, 'done': false});
      _todoCtrl.clear();
    });
    await ZadStorage.setJsonList('zad_todos', _todos);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _habitCtrl.dispose();
    _todoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mins = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final secs = (_secondsRemaining % 60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(title: const Text('الإنتاجية وتنظيم الوقت')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            color: Colors.indigo.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('مؤقت بومودورو للتركيز ⏱️', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [15, 25, 50].map((m) => ChoiceChip(label: Text('$m د'), selected: _focusMinutes == m, onSelected: (_) => _setDuration(m))).toList(),
                  ),
                  const SizedBox(height: 10),
                  Text('$mins:$secs', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.indigo)),
                  SwitchListTile(
                    dense: true,
                    title: const Text('إيقاع تركيز لمسي (تنبيه هادئ كل 5 ثوانٍ)', style: TextStyle(fontSize: 12.5)),
                    value: _pulseMode,
                    onChanged: (v) => setState(() => _pulseMode = v),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilledButton.icon(onPressed: _toggleTimer, icon: Icon(_running ? Icons.pause : Icons.play_arrow), label: Text(_running ? 'إيقاف' : 'ابدأ')),
                      const SizedBox(width: 8),
                      OutlinedButton(onPressed: () => _setDuration(_focusMinutes), child: const Text('إعادة')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text('قائمة المهام السريعة (To-Do) 📝', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: TextField(controller: _todoCtrl, decoration: const InputDecoration(hintText: 'أضف مهمة لليوم...', border: OutlineInputBorder()))),
              const SizedBox(width: 8),
              IconButton.filled(onPressed: _addTodo, icon: const Icon(Icons.add)),
            ],
          ),
          const SizedBox(height: 6),
          ..._todos.map((t) => Card(
                child: CheckboxListTile(
                  dense: true,
                  title: Text(t['title'], style: TextStyle(decoration: t['done'] ? TextDecoration.lineThrough : null)),
                  value: t['done'],
                  secondary: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () async {
                      setState(() => _todos.remove(t));
                      await ZadStorage.setJsonList('zad_todos', _todos);
                    },
                  ),
                  onChanged: (v) async {
                    setState(() => t['done'] = v ?? false);
                    if (v == true) await ZadStorage.addXp(10, pillar: 'mind');
                    await ZadStorage.setJsonList('zad_todos', _todos);
                  },
                ),
              )),
          const SizedBox(height: 14),
          const Text('متعقب العادات اليومية ✅', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: TextField(controller: _habitCtrl, decoration: const InputDecoration(hintText: 'أضف عادة جديدة...', border: OutlineInputBorder()))),
              const SizedBox(width: 8),
              IconButton.filled(onPressed: _addHabit, icon: const Icon(Icons.add)),
            ],
          ),
          const SizedBox(height: 6),
          ..._habits.map((h) {
            final done = _doneHabits.contains(h);
            return Card(
              child: CheckboxListTile(
                dense: true,
                title: Text(h, style: TextStyle(decoration: done ? TextDecoration.lineThrough : null)),
                value: done,
                onChanged: (_) async {
                  setState(() {
                    if (done) {
                      _doneHabits.remove(h);
                    } else {
                      _doneHabits.add(h);
                      ZadStorage.addXp(10, pillar: 'mind');
                    }
                  });
                  await ZadStorage.setStringList('zad_done_habits', _doneHabits);
                },
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
  String _breathMode = 'تخفيف التوتر (4-4-4)';
  String _breathPhase = 'اضغط للبدء';
  bool _breathingActive = false;

  String _todayMood = '😊';
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
    final e = await ZadStorage.getStringList('zad_journal');
    final pin = await ZadStorage.getString('zad_pin');
    final mood = await ZadStorage.getString('zad_mood');
    if (mounted) {
      setState(() {
        _entries = e;
        _savedPin = pin;
        _unlocked = pin == null;
        if (mood != null) _todayMood = mood;
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
      final sec = _breathMode.contains('النوم') ? 6 : 4;
      _breathCtrl.duration = Duration(seconds: sec);
      setState(() {
        _breathingActive = true;
        _breathPhase = 'شهيق عميق...';
      });
      _breathCtrl.repeat(reverse: true);
      _breathCtrl.addStatusListener((status) {
        if (!_breathingActive || !mounted) return;
        HapticFeedback.lightImpact();
        setState(() {
          _breathPhase = status == AnimationStatus.forward ? 'شهيق عميق ببطء...' : 'زفير هادئ وتفريغ التوتر...';
        });
      });
    }
  }

  Future<void> _addJournalEntry() async {
    final txt = _journalCtrl.text.trim();
    if (txt.isEmpty) return;
    final now = DateTime.now();
    final formatted = '${now.year}-${now.month}-${now.day} | $_todayMood | $txt';
    setState(() {
      _entries.insert(0, formatted);
      _journalCtrl.clear();
    });
    await ZadStorage.setStringList('zad_journal', _entries);
    await ZadStorage.addXp(15, pillar: 'calm');
  }

  Future<void> _promptPin() async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(_savedPin == null ? 'تعيين رمز سري (4 أرقام)' : 'أدخل الرمز السري'),
          content: TextField(controller: ctrl, keyboardType: TextInputType.number, obscureText: true, maxLength: 4),
          actions: [
            if (_savedPin != null && _unlocked)
              TextButton(
                onPressed: () async {
                  await ZadStorage.setString('zad_pin', null);
                  setState(() { _savedPin = null; _unlocked = true; });
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('إلغاء القفل'),
              ),
            FilledButton(
              onPressed: () async {
                if (_savedPin == null && ctrl.text.length == 4) {
                  await ZadStorage.setString('zad_pin', ctrl.text);
                  setState(() { _savedPin = ctrl.text; _unlocked = true; });
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
        await ZadStorage.addXp(30, pillar: 'calm');
        if (mounted) {
          setState(() => _detoxActive = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أحسنت! أتممت الديتوكس الرقمي +30 نقطة 🌿')));
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
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  const Text('حالتك المزاجية الآن 💭', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ['😄', '😊', '😐', '😔', '😰'].map((emoji) {
                      final selected = _todayMood == emoji;
                      return GestureDetector(
                        onTap: () async {
                          setState(() => _todayMood = emoji);
                          await ZadStorage.setString('zad_mood', emoji);
                        },
                        child: CircleAvatar(
                          radius: selected ? 24 : 20,
                          backgroundColor: selected ? Colors.teal.withValues(alpha: 0.25) : Colors.transparent,
                          child: Text(emoji, style: TextStyle(fontSize: selected ? 26 : 22)),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('التنفس الموجه التفاعلي 🌬️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: ['تخفيف التوتر (4-4-4)', 'للاستعداد للنوم (4-7-8)', 'تجديد الطاقة'].map((m) {
                      return ChoiceChip(
                        label: Text(m, style: const TextStyle(fontSize: 11)),
                        selected: _breathMode == m,
                        onSelected: (_) => setState(() => _breathMode = m),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  AnimatedBuilder(
                    animation: _breathCtrl,
                    builder: (_, __) {
                      final size = 78 + (_breathCtrl.value * 62);
                      return Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.teal.withValues(alpha: 0.22 + (_breathCtrl.value * 0.3)),
                          border: Border.all(color: Colors.teal, width: 3),
                        ),
                        child: const Icon(Icons.air, color: Colors.teal, size: 32),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(_breathPhase, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                  const SizedBox(height: 8),
                  FilledButton(onPressed: _toggleBreathing, child: Text(_breathingActive ? 'إيقاف' : 'ابدأ الجلسة')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('تحدي صيام الشاشات (Digital Detox) 📵', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_detoxActive)
                    Center(
                      child: Column(
                        children: [
                          Text('$dm:$ds', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.teal)),
                          TextButton(onPressed: () { _detoxTimer?.cancel(); setState(() => _detoxActive = false); }, child: const Text('إلغاء')),
                        ],
                      ),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(onPressed: () => _startDetox(15), child: const Text('15 د')),
                        ElevatedButton(onPressed: () => _startDetox(30), child: const Text('30 د')),
                        ElevatedButton(onPressed: () => _startDetox(60), child: const Text('60 د')),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('دفتر الامتنان السري 🔒', style: TextStyle(fontWeight: FontWeight.bold)),
                      TextButton.icon(
                        onPressed: _promptPin,
                        icon: Icon(_savedPin == null ? Icons.lock_open : Icons.lock, size: 18),
                        label: Text(_savedPin == null ? 'تعيين PIN' : 'إدارة القفل'),
                      ),
                    ],
                  ),
                  if (!_unlocked)
                    FilledButton(onPressed: _promptPin, child: const Text('افتح الدفتر بالرمز'))
                  else ...[
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _journalCtrl, decoration: const InputDecoration(hintText: 'اكتب 3 أشياء ممتن لها اليوم...', border: OutlineInputBorder()))),
                        const SizedBox(width: 8),
                        IconButton.filled(onPressed: _addJournalEntry, icon: const Icon(Icons.add)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._entries.take(6).map((e) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.favorite, color: Colors.teal, size: 18),
                          title: Text(e),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () async {
                              setState(() => _entries.remove(e));
                              await ZadStorage.setStringList('zad_journal', _entries);
                            },
                          ),
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

// ==================== 5. قسم التعلم السريع والبطاقات ====================
class LearningScreen extends StatefulWidget {
  const LearningScreen({super.key});

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  String _deck = 'إنجليزي يومي';
  bool _showAnswer = false;
  int _cardIndex = 0;
  int _quoteIndex = 0;

  final Map<String, List<Map<String, String>>> _decks = {
    'إنجليزي يومي': [
      {'q': 'Resilience', 'a': 'المرونة النفسية والقدرة على النهوض بعد الصعوبات.'},
      {'q': 'Consistency', 'a': 'الاستمرارية اليومية الهادئة (مفتاح الإتقان).'},
      {'q': 'Procrastination', 'a': 'التسويف وتأجيل المهام المهمة.'},
    ],
    'مهارات وإنتاجية': [
      {'q': 'قاعدة 80/20 (باريتو)', 'a': '80% من النتائج تأتي من 20% فقط من الجهد المركز.'},
      {'q': 'قاعدة الدقيقتين', 'a': 'أي مهمة تأخذ أقل من دقيقتين أنجزها فوراً.'},
      {'q': 'مصفوفة أيزنهاور', 'a': 'تقسيم المهام حسب: عاجل ومهم، مهم غير عاجل، عاجل غير مهم.'},
    ],
    'بطاقاتي الخاصة': [],
  };

  final List<String> _quotes = [
    'قليلٌ دائم خيرٌ من كثيرٍ منقطع.',
    'الانضباط يصنع ما لا يصنعه الحماس المؤقت.',
    'اهتم بجسدك فهو المكان الوحيد الذي تعيش فيه.',
    'كل دقيقة تركيز تبعدك خطوات عن القلق والتشتت.',
    'المعرفة قوة، لكن تطبيقها هو القوة الحقيقية.',
  ];

  @override
  void initState() {
    super.initState();
    _loadCustomCards();
  }

  Future<void> _loadCustomCards() async {
    final list = await ZadStorage.getJsonList('zad_custom_cards');
    if (mounted) {
      setState(() {
        _decks['بطاقاتي الخاصة'] = list.map((e) => {'q': e['q'].toString(), 'a': e['a'].toString()}).toList();
      });
    }
  }

  Future<void> _addCustomCard() async {
    final qCtrl = TextEditingController();
    final aCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('أضف بطاقة حفظ جديدة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: qCtrl, decoration: const InputDecoration(labelText: 'السؤال / الكلمة')),
              TextField(controller: aCtrl, decoration: const InputDecoration(labelText: 'الإجابة / المعنى')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                if (qCtrl.text.trim().isNotEmpty && aCtrl.text.trim().isNotEmpty) {
                  setState(() {
                    _decks['بطاقاتي الخاصة']!.add({'q': qCtrl.text.trim(), 'a': aCtrl.text.trim()});
                    _deck = 'بطاقاتي الخاصة';
                    _cardIndex = _decks['بطاقاتي الخاصة']!.length - 1;
                    _showAnswer = false;
                  });
                  await ZadStorage.setJsonList(
                    'zad_custom_cards',
                    _decks['بطاقاتي الخاصة']!.map((e) => Map<String, dynamic>.from(e)).toList(),
                  );
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rateCard(bool hard) async {
    final currentList = _decks[_deck]!;
    if (currentList.isEmpty) return;
    await ZadStorage.addXp(5, pillar: 'skill');
    setState(() {
      if (hard && currentList.length > 1) {
        final item = currentList.removeAt(_cardIndex);
        currentList.add(item);
      } else {
        _cardIndex = (_cardIndex + 1) % currentList.length;
      }
      _showAnswer = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentList = _decks[_deck]!;
    final hasCards = currentList.isNotEmpty;
    final card = hasCards ? currentList[_cardIndex % currentList.length] : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('التعلم السريع والبطاقات'),
        actions: [IconButton(onPressed: _addCustomCard, icon: const Icon(Icons.add_card), tooltip: 'إضافة بطاقة')],
      ),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Wrap(
              spacing: 6,
              children: _decks.keys.map((d) => ChoiceChip(
                    label: Text(d, style: const TextStyle(fontSize: 12)),
                    selected: _deck == d,
                    onSelected: (_) => setState(() { _deck = d; _cardIndex = 0; _showAnswer = false; }),
                  )).toList(),
            ),
            const SizedBox(height: 12),
            if (!hasCards)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Text('لم تضف بطاقات خاصة بعد'),
                      const SizedBox(height: 10),
                      FilledButton.icon(onPressed: _addCustomCard, icon: const Icon(Icons.add), label: const Text('أضف أول بطاقة')),
                    ],
                  ),
                ),
              )
            else ...[
              GestureDetector(
                onTap: () => setState(() => _showAnswer = !_showAnswer),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: double.infinity,
                  height: 190,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _showAnswer ? Colors.purple.withValues(alpha: 0.16) : Colors.purple.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.purple.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_showAnswer ? 'الإجابة:' : 'اضغط لقلب البطاقة', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 10),
                      Text(_showAnswer ? card!['a']! : card!['q']!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton(onPressed: () => _rateCard(true), child: const Text('صعبة (كررها)')),
                  FilledButton(onPressed: () => _rateCard(false), child: const Text('فهمتها (التالية)')),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.format_quote, color: Colors.purple),
                        SizedBox(width: 6),
                        Text('حكمة اليوم التحفيزية', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(_quotes[_quoteIndex], textAlign: TextAlign.center, style: const TextStyle(fontSize: 15.5, fontStyle: FontStyle.italic)),
                    TextButton(onPressed: () => setState(() => _quoteIndex = (_quoteIndex + 1) % _quotes.length), child: const Text('حكمة أخرى')),
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
  String? _familyContact;

  final List<Map<String, String>> _guides = [
    {'title': 'الإنعاش القلبي الرئوي (CPR)', 'body': '1. تأكد من أمان المكان وفحص التنفس.\n2. اطلب الإسعاف (123).\n3. اضغط بكعب اليد في منتصف الصدر بمعدل 100-120 ضغطة/دقيقة مع استخدام النبض بالأعلى.'},
    {'title': 'الاختناق (مناورة هيمليك)', 'body': 'قف خلف المصاب، لف ذراعيك حول خصره، اصنع قبضة فوق السرة واضغط للداخل وللأعلى بقوة حتى يخرج الجسم العالق.'},
    {'title': 'الحروق الحرارية', 'body': 'برّد مكان الحرق بماء فاتر جارٍ 15-20 دقيقة. ممنوع تماماً وضع معجون الأسنان أو الثلج أو البن.'},
    {'title': 'النزيف الحاد', 'body': 'اضغط مباشرة على الجرح بشاش أو قماش نظيف 10 دقائق متواصلة وارفع الطرف المصاب للأعلى.'},
    {'title': 'الإغماء وانخفاض السكر', 'body': 'مدد المصاب على ظهره وارفع ساقيه 30 سم. إذا كان واعياً ويشعر بهبوط، أعطه عصيراً أو ماءً بسكر.'},
    {'title': 'ضربة الشمس والإجهاد الحراري', 'body': 'انقل المصاب لمكان ظليل بارد، فك الملابس الضيقة، ضع كمادات باردة على الرقبة والإبطين.'},
    {'title': 'التسمم الدوائي أو الغذائي', 'body': 'لا تجبر المصاب على التقيؤ إذا ابتلع مواد كيميائية حارقة، واحفظ عبوة المادة لعرضها على الطبيب فوراً.'},
  ];

  @override
  void initState() {
    super.initState();
    ZadStorage.getString('zad_emergency_contact').then((v) {
      if (mounted) setState(() => _familyContact = v);
    });
  }

  void _toggleCpr() {
    if (_cprActive) {
      _cprTimer?.cancel();
      setState(() { _cprActive = false; _beat = false; });
    } else {
      setState(() => _cprActive = true);
      _cprTimer = Timer.periodic(const Duration(milliseconds: 545), (_) {
        HapticFeedback.heavyImpact();
        setState(() => _beat = !_beat);
      });
    }
  }

  Future<void> _setFamilyContact() async {
    final ctrl = TextEditingController(text: _familyContact ?? '');
    await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('رقم طوارئ عائلي سريع'),
          content: TextField(controller: ctrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: 'أدخل رقم قريب للاتصال وقت الخطر')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                await ZadStorage.setString('zad_emergency_contact', ctrl.text.trim());
                setState(() => _familyContact = ctrl.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cprTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الطوارئ والإسعافات الأولية'), backgroundColor: Colors.red.withValues(alpha: 0.14)),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Row(
            children: [
              Expanded(child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => ContactHelper.callNumber(context, '123'), icon: const Icon(Icons.local_hospital), label: const Text('إسعاف 123'))),
              const SizedBox(width: 6),
              Expanded(child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Colors.blueGrey), onPressed: () => ContactHelper.callNumber(context, '122'), icon: const Icon(Icons.local_police), label: const Text('نجدة 122'))),
              const SizedBox(width: 6),
              Expanded(child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Colors.deepOrange), onPressed: () => ContactHelper.callNumber(context, '180'), icon: const Icon(Icons.fire_truck), label: const Text('مطافئ 180'))),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.contact_phone, color: Colors.red),
              title: Text(_familyContact == null || _familyContact!.isEmpty ? 'أضف رقم طوارئ عائلي' : 'اتصال سريع: $_familyContact'),
              trailing: IconButton(icon: const Icon(Icons.edit), onPressed: _setFamilyContact),
              onTap: _familyContact != null && _familyContact!.isNotEmpty ? () => ContactHelper.callNumber(context, _familyContact!) : _setFamilyContact,
            ),
          ),
          Card(
            color: _beat ? Colors.red.withValues(alpha: 0.25) : Colors.red.withValues(alpha: 0.08),
            child: ListTile(
              leading: Icon(Icons.monitor_heart, color: Colors.red, size: _beat ? 36 : 28),
              title: const Text('بندول الإنعاش القلبي (110 نبضة/د)', style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: _toggleCpr,
                child: Text(_cprActive ? 'إيقاف' : 'تشغيل'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ..._guides.map((g) => Card(
                child: ExpansionTile(
                  leading: const Icon(Icons.medical_information, color: Colors.redAccent),
                  title: Text(g['title']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                  children: [Padding(padding: const EdgeInsets.all(14), child: Text(g['body']!, style: const TextStyle(height: 1.6)))],
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
  Map<String, int> _stats = {'xp': 0, 'body': 0, 'mind': 0, 'calm': 0, 'skill': 0};
  final _challengeCtrl = TextEditingController(text: '7 أيام: شرب 2 لتر ماء + تمرين 20 دقيقة');
  String _qrData = 'ZAD-CHALLENGE|7 أيام: شرب 2 لتر ماء + تمرين 20 دقيقة';
  List<String> _activeChallenges = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await ZadStorage.getStats();
    final c = await ZadStorage.getStringList('zad_challenges');
    if (mounted) setState(() { _stats = s; _activeChallenges = c; });
  }

  Future<void> _importChallenge() async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('استيراد كود تحدي من صديق'),
          content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'الصق نص التحدي أو الكود الممسوح')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                final text = ctrl.text.replaceAll('ZAD-CHALLENGE|', '').trim();
                if (text.isNotEmpty) {
                  setState(() => _activeChallenges.insert(0, text));
                  await ZadStorage.setStringList('zad_challenges', _activeChallenges);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('إضافة التحدي'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _challengeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final xp = _stats['xp'] ?? 0;
    final badges = [
      {'name': 'بداية زاد', 'req': 10, 'icon': Icons.flag},
      {'name': 'محارب الجسد', 'req': 50, 'icon': Icons.fitness_center},
      {'name': 'صانع العادات', 'req': 120, 'icon': Icons.verified},
      {'name': 'حكيم زاد', 'req': 250, 'icon': Icons.workspace_premium},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('التحفيز والتحديات (QR)')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('توازن حياتك ($xp XP) 🏆', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _StatBar('الجسد واللياقة', _stats['body'] ?? 0, Colors.orange),
                  _StatBar('العقل والإنتاجية', _stats['mind'] ?? 0, Colors.indigo),
                  _StatBar('الهدوء النفسي', _stats['calm'] ?? 0, Colors.teal),
                  _StatBar('المعرفة والتعلم', _stats['skill'] ?? 0, Colors.purple),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: badges.map((b) {
                      final ok = xp >= (b['req'] as int);
                      return Chip(
                        avatar: Icon(b['icon'] as IconData, color: ok ? Colors.amber : Colors.grey),
                        label: Text('${b['name']} (${b['req']})'),
                        backgroundColor: ok ? Colors.amber.withValues(alpha: 0.15) : null,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  const Text('تحديات الأصدقاء عبر QR Code 📲', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _challengeCtrl,
                    decoration: const InputDecoration(labelText: 'أنشئ تحدياً لمشاركته', border: OutlineInputBorder()),
                    onChanged: (v) => setState(() => _qrData = 'ZAD-CHALLENGE|$v'),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                    child: QrImageView(data: _qrData, version: QrVersions.auto, size: 170),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: _qrData));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ كود التحدي')));
                          }
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('نسخ الكود'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(onPressed: _importChallenge, icon: const Icon(Icons.download), label: const Text('استيراد تحدي')),
                    ],
                  ),
                  if (_activeChallenges.isNotEmpty) ...[
                    const Divider(),
                    ..._activeChallenges.map((c) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.bolt, color: Colors.amber),
                          title: Text(c),
                          trailing: IconButton(
                            icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                            onPressed: () async {
                              await ZadStorage.addXp(35, pillar: 'body');
                              setState(() => _activeChallenges.remove(c));
                              await ZadStorage.setStringList('zad_challenges', _activeChallenges);
                              _load();
                            },
                          ),
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

class _StatBar extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatBar(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 12)),
              Text('$value XP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 3),
          LinearProgressIndicator(
            value: (value / 200).clamp(0.05, 1.0),
            minHeight: 6,
            borderRadius: BorderRadius.circular(6),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ],
      ),
    );
  }
}

// ==================== 8. عن التطبيق وتواصل معنا ====================
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  final String phone = '01129220696';
  final String whatsapp = '201129220696';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('عن التطبيق وتواصل معنا')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 24),
            const Icon(Icons.spa_rounded, size: 80, color: Color(0xFF1F7A68)),
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
            const SizedBox(height: 30),
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
                    onTap: () => ContactHelper.callNumber(context, phone),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.chat, color: Colors.green),
                    title: const Text('تواصل عبر الواتساب'),
                    subtitle: Text(phone),
                    onTap: () => ContactHelper.openWhatsApp(context, whatsapp, phone),
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
