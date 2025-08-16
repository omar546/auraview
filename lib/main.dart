import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';

// Main App Entry Point
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await Hive.initFlutter();
  Hive.registerAdapter(HealthLogEntryAdapter());
  await Hive.openBox<HealthLogEntry>('health_logs');
  runApp(AuraViewApp(prefs: prefs));
}

class AuraViewApp extends StatefulWidget {
  const AuraViewApp({super.key, required this.prefs});

  final SharedPreferences prefs;

  static void setLocale(BuildContext context, Locale newLocale) {
    _AuraViewAppState? state =
    context.findAncestorStateOfType<_AuraViewAppState>();
    state?.setLocale(newLocale);
  }

  static void setThemeMode(BuildContext context, ThemeMode themeMode) {
    _AuraViewAppState? state =
    context.findAncestorStateOfType<_AuraViewAppState>();
    state?.setThemeMode(themeMode);
  }

  @override
  _AuraViewAppState createState() => _AuraViewAppState();
}

class _AuraViewAppState extends State<AuraViewApp> {
  Locale? _locale;
  ThemeMode _themeMode = ThemeMode.dark; // Start with dark mode by default

  @override
  void initState() {
    super.initState();
    _loadPreferences().then((_) {
      // After preferences are loaded, if a locale was set,
      // ensure the directionality is updated for the whole app.
      if (_locale != null && mounted) {
        // This callback ensures that the MaterialApp has been built
        // and can correctly apply the new directionality.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // The Directionality will be handled by MaterialApp's locale.
        });
      }
    });
  }

  Future<void> _loadPreferences() async {
    final String? languageCode = widget.prefs.getString('language_code');
    if (languageCode != null) {
      _locale = Locale(languageCode);
      // Ensure Bidi is initialized with the correct directionality
      // This might not be strictly necessary here if MaterialApp handles it,
      // but it's a good practice if you encounter directionality issues.
      WidgetsBinding.instance.addPostFrameCallback((_) {});
    }
    final String? theme = widget.prefs.getString('theme_mode');
    if (theme == 'light') {
      _themeMode = ThemeMode.light;
    } else if (theme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.dark; // Default to dark if no preference is set
    }
    // No need to call setState here as initState is called before build
  }

  void setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
    widget.prefs.setString('language_code', locale.languageCode);
  }

  void setThemeMode(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
    if (themeMode == ThemeMode.light) {
      widget.prefs.setString('theme_mode', 'light');
    } else if (themeMode == ThemeMode.dark) {
      widget.prefs.setString('theme_mode', 'dark');
    } else {
      widget.prefs.remove('theme_mode');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AURA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      locale: _locale,
      home: AppWrapper(),
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [Locale('en', ''), Locale('ar', '')],
      localeResolutionCallback: (locale, supportedLocales) {
        for (var supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == locale?.languageCode &&
              supportedLocale.countryCode == locale?.countryCode) {
            return supportedLocale;
          }
        }
        return supportedLocales.first;
      },
    );
  }
}

// App Wrapper to handle onboarding and main flow
class AppWrapper extends StatefulWidget {
  const AppWrapper({super.key});

  @override
  _AppWrapperState createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> {
  bool? _isFirstTime; // Nullable to represent loading state
  bool _isLoading = true; // Still useful for initial shared_prefs load

  @override
  void initState() {
    super.initState();
    _checkFirstTime();
  }

  _checkFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    // Preferences for theme and language are already loaded in _AuraViewAppState's initState

    // Check if the key exists. If not, it's the first time.
    final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
    setState(() {
      _isFirstTime = !hasSeenOnboarding;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
        ),
      );
    }

    if (_isFirstTime == null) {
      // Should not happen if _isLoading is false, but as a safeguard
      return Scaffold(
        body: Center(child: Text("Error determining onboarding status.")),
      );
    }

    return _isFirstTime! ? OnboardingScreen() : MainApp();
  }
}

// App Theme Configuration
class AppTheme {
  static const Color primaryColor = Color(0xFF6C5CE7);
  static const Color secondaryColor = Color(0xFF74B9FF);
  static const Color accentColor = Color(0xFF00B894);
  static const Color warningColor = Color(0xFFFFAB00);
  static const Color errorColor = Color(0xFFFF6B6B);

  static const Gradient primaryGradient = LinearGradient(
    colors: [primaryColor, secondaryColor],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primarySwatch: MaterialColor(0xFF6C5CE7, {
      50: Color(0xFFE8E6FF),
      100: Color(0xFFC5C1FF),
      200: Color(0xFF9E97FF),
      300: Color(0xFF776DFF),
      400: Color(0xFF594EFF),
      500: Color(0xFF6C5CE7),
      600: Color(0xFF5A4FCF),
      700: Color(0xFF483FB5),
      800: Color(0xFF36309B),
      900: Color(0xFF241B73),
    }),
    scaffoldBackgroundColor: Color(0xFFF8F9FA),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: Color(0xFF2D3436)),
      titleTextStyle: TextStyle(
        color: Color(0xFF2D3436),
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith( // For light theme
        statusBarColor: Colors.transparent, // Or a specific light color
        statusBarIconBrightness: Brightness.dark, // For Android
        statusBarBrightness: Brightness.light, // For iOS
      ),
    ),
    cardTheme: CardTheme(
      elevation: 8,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    textTheme: TextTheme(
      headlineLarge: TextStyle(
        color: Color(0xFF2D3436),
        fontWeight: FontWeight.bold,
      ),
      headlineMedium: TextStyle(
        color: Color(0xFF2D3436),
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(color: Color(0xFF636E72)),
      bodyMedium: TextStyle(color: Color(0xFF636E72)),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primarySwatch: MaterialColor(0xFF6C5CE7, {
      50: Color(0xFFE8E6FF),
      100: Color(0xFFC5C1FF),
      200: Color(0xFF9E97FF),
      300: Color(0xFF776DFF),
      400: Color(0xFF594EFF),
      500: Color(0xFF6C5CE7),
      600: Color(0xFF5A4FCF),
      700: Color(0xFF483FB5),
      800: Color(0xFF36309B),
      900: Color(0xFF241B73),
    }),
    scaffoldBackgroundColor: Color(0xFF1A1D29),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      systemOverlayStyle: SystemUiOverlayStyle.light.copyWith( // For dark theme
        statusBarColor: Colors.transparent, // Or a specific dark color
        statusBarIconBrightness: Brightness.light, // For Android
        statusBarBrightness: Brightness.dark, // For iOS
      ),
    ),
    cardTheme: CardTheme(
      elevation: 8,
      shadowColor: Colors.black26,
      color: Color(0xFF2C2F36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    textTheme: TextTheme(
      headlineLarge: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
      headlineMedium: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(color: Color(0xFFB2BEC3)),
      bodyMedium: TextStyle(color: Color(0xFFB2BEC3)),
    ),
  );
}

// Data Models
@HiveType(typeId: 0)
class HealthLogEntry extends HiveObject {
  @HiveField(0)
  DateTime date;

  @HiveField(1)
  double mood; // 1-5 scale

  @HiveField(2)
  double waterIntake; // in glasses (250ml each)

  @HiveField(3)
  int exerciseMinutes;

  @HiveField(4)
  double sleepHours;

  @HiveField(5)
  String? exerciseType;

  HealthLogEntry({
    required this.date,
    required this.mood,
    required this.waterIntake,
    required this.exerciseMinutes,
    required this.sleepHours,
    this.exerciseType,
  });
}

// Hive Adapter (Auto-generated, but included for completeness)
class HealthLogEntryAdapter extends TypeAdapter<HealthLogEntry> {
  @override
  final int typeId = 0;

  @override
  HealthLogEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HealthLogEntry(
      date: fields[0] as DateTime,
      mood: fields[1] as double,
      waterIntake: fields[2] as double,
      exerciseMinutes: fields[3] as int,
      sleepHours: fields[4] as double,
      exerciseType: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, HealthLogEntry obj) {
    writer
      ..writeByte(6)..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.mood)
      ..writeByte(2)
      ..write(obj.waterIntake)
      ..writeByte(3)
      ..write(obj.exerciseMinutes)
      ..writeByte(4)
      ..write(obj.sleepHours)
      ..writeByte(5)
      ..write(obj.exerciseType);
  }

  @override
  bool get isOpen => false;
}

// Data Service
class HealthLogService {
  static const String _boxName = 'health_logs';

  static Box<HealthLogEntry> get _box => Hive.box<HealthLogEntry>(_boxName);

  static Future<void> saveEntry(HealthLogEntry entry) async {
    final existingIndex = _box.values.toList().indexWhere(
          (e) =>
      DateFormat('yyyy-MM-dd').format(e.date) ==
          DateFormat('yyyy-MM-dd').format(entry.date),
    );

    if (existingIndex != -1) {
      await _box.putAt(existingIndex, entry);
    } else {
      await _box.add(entry);
    }
  }

  static List<HealthLogEntry> getAllEntries() {
    return _box.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  static HealthLogEntry? getTodaysEntry() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final entries = _box.values.where(
          (entry) => DateFormat('yyyy-MM-dd').format(entry.date) == today,
    );
    // If no entry for today, return null. The UI will handle prompting for a new log.
    return entries.isEmpty ? null : entries.first;
  }

  static Future<void> deleteEntry(HealthLogEntry entry) async {
    await entry.delete();
  }

  static List<HealthLogEntry> getWeeklyEntries() {
    final now = DateTime.now();
    final weekAgo = now.subtract(Duration(days: 7));
    return _box.values.where((entry) => entry.date.isAfter(weekAgo)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  static List<HealthLogEntry> getMonthlyEntries() {
    final now = DateTime.now();
    final monthAgo = DateTime(now.year, now.month - 1, now.day);
    return _box.values.where((entry) => entry.date.isAfter(monthAgo)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }
}

// Main Application
class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  _MainAppState createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkTodaysLog();
    });
  }

  void _checkTodaysLog() {
    final todaysEntry = HealthLogService.getTodaysEntry();
    if (todaysEntry == null) {
      // Ensure context is still mounted before navigating
      if (mounted) {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (context) => DailyLogFlow()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: HomeScreen());
  }
}

// Onboarding Screen
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Welcome to AURA',
      subtitle: 'Track your daily wellness journey with beautiful insights',
      icon: Icons.health_and_safety_outlined,
      color: AppTheme.primaryColor,
    ),
    OnboardingPage(
      title: 'Daily Logging',
      subtitle:
      'Record your mood, sleep, water intake, and exercise effortlessly',
      icon: Icons.today_outlined,
      color: AppTheme.secondaryColor,
    ),
    OnboardingPage(
      title: 'Beautiful Analytics',
      subtitle: 'Visualize your progress with stunning charts and insights',
      icon: Icons.analytics_outlined,
      color: AppTheme.accentColor,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (context) => MainApp()));
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery
            .of(context)
            .orientation == Orientation.landscape;

    return Scaffold(
      body: Container(
        // Ensure the gradient covers the entire screen, including under the status bar
        // if the SafeArea is not handled by the system (e.g., on some Android versions)
        height: MediaQuery
            .of(context)
            .size
            .height,
        decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildOnboardingPage(_pages[index], isLandscape),
                    );
                  },
                ),
              ),
              _buildBottomSection(isLandscape),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOnboardingPage(OnboardingPage page, bool isLandscape) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isLandscape ? 60 : 32,
        vertical: isLandscape ? 20 : 40,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: isLandscape ? 120 : 160,
            height: isLandscape ? 120 : 160,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              page.icon,
              size: isLandscape ? 60 : 80,
              color: Colors.white,
            ),
          ),
          SizedBox(height: isLandscape ? 20 : 40),
          Text(
            page.title,
            style: TextStyle(
              fontSize: isLandscape ? 24 : 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isLandscape ? 10 : 20),
          Text(
            page.subtitle,
            style: TextStyle(
              fontSize: isLandscape ? 14 : 16,
              color: Colors.white.withOpacity(0.9),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection(bool isLandscape) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 32,
        vertical: isLandscape ? 16 : 32,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _pages.length,
                  (index) =>
                  Container(
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: Colors.white.withOpacity(
                        _currentPage == index ? 1.0 : 0.4,
                      ),
                    ),
                  ),
            ),
          ),
          SizedBox(height: isLandscape ? 16 : 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_currentPage > 0)
                TextButton(
                  onPressed: () {
                    _pageController.previousPage(
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Text(
                    'Previous',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              else
                SizedBox.shrink(),
              ElevatedButton(
                onPressed:
                _currentPage == _pages.length - 1
                    ? _finishOnboarding
                    : () {
                  _pageController.nextPage(
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.primaryColor,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Text(
                  _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

// Daily Log Flow
class DailyLogFlow extends StatefulWidget {
  const DailyLogFlow({super.key});

  @override
  _DailyLogFlowState createState() => _DailyLogFlowState();
}

class _DailyLogFlowState extends State<DailyLogFlow>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  int _currentStep = 0;

  // Log data
  double _mood = 3.0;
  double _waterIntake = 4.0;
  int _exerciseMinutes = 30;
  String _exerciseType = 'Walking';
  double _sleepHours = 8.0;

  final List<String> _exerciseTypes = [
    'Walking',
    'Running',
    'Cycling',
    'Swimming',
    'Yoga',
    'Gym',
    'Dancing',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );

    _slideController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _scaleController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 3) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      _slideController.reset();
      _slideController.forward();
      _scaleController.reset();
      _scaleController.forward();
    } else {
      _saveLog();
    }
  }

  void _saveLog() async {
    final entry = HealthLogEntry(
      date: DateTime.now(),
      mood: _mood,
      waterIntake: _waterIntake,
      exerciseMinutes: _exerciseMinutes,
      sleepHours: _sleepHours,
      exerciseType: _exerciseType,
    );

    await HealthLogService.saveEntry(entry);

    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => MainApp()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery
            .of(context)
            .orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
        // Add an AppBar for the back button
        leading: BackButton(
          onPressed: () {
            // Navigate back to the HomeScreen or the previous relevant screen.
            // If DailyLogFlow was pushed from MainApp due to no log,
            // popping will return to MainApp.
            Navigator.of(context).pop();
          },
        ),
        backgroundColor: Colors.transparent, // Make AppBar transparent
        elevation: 0, // Remove shadow
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(isLandscape),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: NeverScrollableScrollPhysics(),
                  children: [
                    _buildMoodStep(isLandscape),
                    _buildWaterStep(isLandscape),
                    _buildExerciseStep(isLandscape),
                    _buildSleepStep(isLandscape),
                  ],
                ),
              ),
              _buildBottomButtons(isLandscape),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isLandscape) {
    return Container(
      padding: EdgeInsets.all(isLandscape ? 16 : 24),
      child: Column(
        children: [
          Text(
            Localizations
                .localeOf(context)
                .languageCode == 'ar'
                ? 'السجل اليومي'
                : 'Daily Log',
            style: TextStyle(
              fontSize: isLandscape ? 20 : 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: isLandscape ? 8 : 16),
          LinearProgressIndicator(
            value: (_currentStep + 1) / 4,
            backgroundColor: Colors.white.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodStep(bool isLandscape) {
    return SlideTransition(
      position: _slideAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: _buildStepContainer(
          isLandscape,
          title:
          Localizations
              .localeOf(context)
              .languageCode == 'ar'
              ? 'كيف حالك اليوم؟'
              : 'How are you feeling?',
          illustration: _buildMoodIllustration(),
          slider: _buildMoodSlider(),
        ),
      ),
    );
  }

  Widget _buildWaterStep(bool isLandscape) {
    return SlideTransition(
      position: _slideAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: _buildStepContainer(
          isLandscape,
          title:
          Localizations
              .localeOf(context)
              .languageCode == 'ar'
              ? 'كمية المية النهاردة؟'
              : 'Water intake today?',
          illustration: _buildWaterIllustration(),
          slider: _buildWaterSlider(),
        ),
      ),
    );
  }

  Widget _buildExerciseStep(bool isLandscape) {
    return SlideTransition(
      position: _slideAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: _buildStepContainer(
          isLandscape,
          title:
          Localizations
              .localeOf(context)
              .languageCode == 'ar'
              ? 'اتمرنت النهاردة؟'
              : 'Exercise today?',
          illustration: _buildExerciseIllustration(),
          slider: _buildExerciseControls(),
        ),
      ),
    );
  }

  Widget _buildSleepStep(bool isLandscape) {
    return SlideTransition(
      position: _slideAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: _buildStepContainer(
          isLandscape,
          title:
          Localizations
              .localeOf(context)
              .languageCode == 'ar'
              ? 'نمت كام ساعة؟'
              : 'How many hours of sleep?',
          illustration: _buildSleepIllustration(),
          slider: _buildSleepSlider(),
        ),
      ),
    );
  }

  Widget _buildStepContainer(bool isLandscape, {
    required String title,
    required Widget illustration,
    required Widget slider,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isLandscape ? 40 : 24,
        vertical: isLandscape ? 10 : 20,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: isLandscape ? 20 : 24,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isLandscape ? 20 : 40),
          illustration,
          SizedBox(height: isLandscape ? 20 : 40),
          slider,
        ],
      ),
    );
  }

  // Illustration widgets will be in the next part
  Widget _buildMoodIllustration() {
    List<String> moodEmojis = ['😢', '😕', '😐', '😊', '😄'];
    return SizedBox(
      height: 120,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (index) {
          bool isSelected = index == (_mood - 1).round();
          return Container(
            margin: EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              moodEmojis[index],
              style: TextStyle(fontSize: isSelected ? 48 : 32),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMoodSlider() {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: Colors.white,
        inactiveTrackColor: Colors.white.withOpacity(0.3),
        thumbColor: Colors.white,
        trackHeight: 8.0,
        // Make slider thicker
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 12),
      ),
      child: Slider(
        value: _mood,
        min: 1,
        max: 5,
        divisions: 4,
        onChanged: (value) {
          setState(() {
            _mood = value;
          });
        },
      ),
    );
  }

  Widget _buildWaterIllustration() {
    return SizedBox(
      height: 120,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(8, (index) {
          bool isFilled = index < _waterIntake.round();
          return Container(
            margin: EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              Icons.local_drink,
              size: 24,
              color: isFilled ? Colors.white : Colors.white.withOpacity(0.3),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildWaterSlider() {
    return Column(
      children: [
        Text(
          Localizations
              .localeOf(context)
              .languageCode == 'ar'
              ? '${_waterIntake.round()} كوبايات (${(_waterIntake * 250)
              .round()}مل)'
              : '${_waterIntake.round()} glasses (${(_waterIntake * 250)
              .round()}ml)',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        SizedBox(height: 16),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white.withOpacity(0.3),
            thumbColor: Colors.white,
            trackHeight: 8.0, // Make slider thicker
          ),
          child: Slider(
            value: _waterIntake,
            min: 0,
            max: 12,
            divisions: 12,
            label:
            Localizations
                .localeOf(context)
                .languageCode == 'ar'
                ? '${_waterIntake.round()} كوبايات'
                : '${_waterIntake.round()} glasses',
            onChanged: (value) {
              setState(() {
                _waterIntake = value;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseIllustration() {
    return SizedBox(
      height: 110,
      child: Column(
        children: [
          Icon(_getExerciseIcon(_exerciseType), size: 64, color: Colors.white),
          SizedBox(height: 16),
          Text(
            _exerciseType,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getExerciseIcon(String type) {
    switch (type.toLowerCase()) {
      case 'walking':
        return Icons.directions_walk;
      case 'running':
        return Icons.directions_run;
      case 'cycling':
        return Icons.directions_bike;
      case 'swimming':
        return Icons.pool;
      case 'yoga':
        return Icons.self_improvement;
      case 'gym':
        return Icons.fitness_center;
      case 'dancing':
        return Icons.music_note;
      default:
        return Icons.sports;
    }
  }

  Widget _buildExerciseControls() {
    return Column(
      children: [
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _exerciseTypes.length,
            itemBuilder: (context, index) {
              bool isSelected = _exerciseTypes[index] == _exerciseType;
              return Container(
                margin: EdgeInsets.symmetric(horizontal: 4),
                child: FilterChip(
                  label: Text(
                    _exerciseTypes[index],
                    style: TextStyle(
                      color:
                      isSelected
                          ? AppTheme.primaryColor
                          : (Theme
                          .of(context)
                          .brightness ==
                          Brightness.light
                          ? Colors.black87
                          : Colors.white),
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _exerciseType = _exerciseTypes[index];
                      });
                    }
                  },
                  backgroundColor: Colors.white.withOpacity(0.2),
                  selectedColor: Colors.white,
                  checkmarkColor: AppTheme.primaryColor,
                ),
              );
            },
          ),
        ),
        SizedBox(height: 20),
        Text(
          Localizations
              .localeOf(context)
              .languageCode == 'ar'
              ? '$_exerciseMinutes دقيقة'
              : '$_exerciseMinutes minutes',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        SizedBox(height: 16),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white.withOpacity(0.3),
            thumbColor: Colors.white,
            trackHeight: 8.0, // Make slider thicker
          ),
          child: Slider(
            value: _exerciseMinutes.toDouble(),
            min: 0,
            max: 180,
            divisions: 18,
            label:
            Localizations
                .localeOf(context)
                .languageCode == 'ar'
                ? '${_exerciseMinutes.round()} دقيقة'
                : '${_exerciseMinutes.round()} min',
            onChanged: (value) {
              setState(() {
                _exerciseMinutes = value.round();
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSleepIllustration() {
    return SizedBox(
      height: 120,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(12, (index) {
              bool isFilled = index < _sleepHours.round();
              return Container(
                margin: EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  isFilled ? Icons.bedtime : Icons.bedtime_outlined,
                  size: 20,
                  color:
                  isFilled ? Colors.white : Colors.white.withOpacity(0.3),
                ),
              );
            }),
          ),
          SizedBox(height: 20),
          Text(
            Localizations
                .localeOf(context)
                .languageCode == 'ar'
                ? '${_sleepHours.toStringAsFixed(1)} ساعات'
                : '${_sleepHours.toStringAsFixed(1)} hours',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSleepSlider() {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: Colors.white,
        inactiveTrackColor: Colors.white.withOpacity(0.3),
        thumbColor: Colors.white,
        trackHeight: 8.0,
        // Make slider thicker
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 12),
      ),
      child: Slider(
        value: _sleepHours,
        min: 0,
        max: 12,
        divisions: 24,
        label:
        Localizations
            .localeOf(context)
            .languageCode == 'ar'
            ? '${_sleepHours.toStringAsFixed(1)} ساعات'
            : '${_sleepHours.toStringAsFixed(1)} hours',
        onChanged: (value) {
          setState(() {
            _sleepHours = value;
          });
        },
      ),
    );
  }

  Widget _buildBottomButtons(bool isLandscape) {
    return Container(
      padding: EdgeInsets.all(isLandscape ? 16 : 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _currentStep--;
                });
                _pageController.previousPage(
                  duration: Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                );
              },
              icon: Icon(Icons.arrow_back, color: Colors.white70),
              label: Text(
                Localizations
                    .localeOf(context)
                    .languageCode == 'ar'
                    ? 'رجوع'
                    : 'Back',
                style: TextStyle(color: Colors.white70),
              ),
            )
          else
            SizedBox.shrink(),
          ElevatedButton.icon(
            onPressed: _nextStep,
            icon: Icon(
              _currentStep == 3 ? Icons.check : Icons.arrow_forward,
              color: AppTheme.primaryColor,
            ),
            label: Text(
              _currentStep == 3
                  ? (Localizations
                  .localeOf(context)
                  .languageCode == 'ar'
                  ? 'حفظ السجل'
                  : 'Save Log')
                  : (Localizations
                  .localeOf(context)
                  .languageCode == 'ar'
                  ? 'التالي'
                  : 'Next'),
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Home Screen
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isDarkMode = true; // Start with dark mode
  bool _isArabic = false;
  int _selectedPeriod = 0; // 0: Week, 1: Month
  final ScrollController _scrollController = ScrollController();
  bool _showFab = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    // Check if the user is scrolling down
    if (_scrollController.position.pixels > 50 && _showFab) { // 50 is an arbitrary threshold
      setState(() {
        _showFab = false;
      });
    } else if (_scrollController.position.pixels <= 50 && !_showFab) {
      setState(() {
        _showFab = true;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('dark_mode') ?? true; // Default to true (dark mode)
      _isArabic = prefs.getBool('arabic_language') ?? false;
    });
  }

  _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', _isDarkMode);
    await prefs.setBool('arabic_language', _isArabic);
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery
            .of(context)
            .orientation == Orientation.landscape;
    final screenWidth = MediaQuery
        .of(context)
        .size
        .width;
    final isTablet = screenWidth > 600;

    // Determine if the screen is wide enough for a different layout
    final isWideScreen = screenWidth > 1100;


    return Theme(
      data: _isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme,
      // data: _isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme,
      child: Scaffold(
        appBar: _buildAppBar(),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView( // Make sure this is the scrollable view
              controller: _scrollController, // Assign the controller here
              padding: EdgeInsets.all(isTablet ? 24 : 16),
              child: isWideScreen
                  ? _buildWideScreenLayout(isTablet)
                  : _buildNarrowScreenLayout(isTablet, isLandscape),
            ),
          ),
        ),
        floatingActionButton: _showFab ? _buildFAB() : null,
      ),
    );
  }

  Widget _buildNarrowScreenLayout(bool isTablet, bool isLandscape) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildWelcomeSection(),
        SizedBox(height: 24),
        _buildTodaysSummary(),
        SizedBox(height: 24),
        _buildPeriodSelector(),
        SizedBox(height: 16),
        if (isLandscape && isTablet) _buildLandscapeCharts() else
          _buildPortraitCharts(),
        SizedBox(height: 24),
        _buildQuickStats(),
      ],
    );
  }

  Widget _buildWideScreenLayout(bool isTablet) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2, // Assign more space to charts and stats
          child: Column(
            children: [
              _buildPeriodSelector(),
              SizedBox(height: 16),
              _buildMoodChart(),
              SizedBox(height: 16),
              _buildWaterChart(),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildExerciseChart()),
                  SizedBox(width: 16),
                  Expanded(child: _buildSleepChart()),
                ],
              ),
              SizedBox(height: 24),
              _buildQuickStats(),
            ],
          ),
        ),
        SizedBox(width: 24),
        Expanded(
          flex: 1, // Assign less space to welcome and summary
          child: Column(
            children: [
              _buildWelcomeSection(),
              SizedBox(height: 24),
              _buildTodaysSummary(),
            ],
          ),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: SvgPicture.asset(
        _isDarkMode
         ? 'assets/Auradark.svg'
        : 'assets/Auralight.svg',
      ),
      actions: [
        IconButton(
          icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode),
          tooltip: _isDarkMode ? 'Light Mode' : 'Dark Mode',
          onPressed: () {
            _handleMenuAction('theme');
          },
        ),
        IconButton(
          icon: Icon(Icons.view_list_outlined), // Changed icon
          tooltip: 'View History',
          onPressed: () {
            _handleMenuAction('history');
          },
        ),
      ],
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'theme':
        setState(() {
          _isDarkMode = !_isDarkMode;
        });
        AuraViewApp.setThemeMode(
          context,
          _isDarkMode ? ThemeMode.dark : ThemeMode.light,
        );
        // Update status bar style based on the new theme
        SystemChrome.setSystemUIOverlayStyle(
          _isDarkMode
              ? AppTheme.darkTheme.appBarTheme.systemOverlayStyle!
              : AppTheme.lightTheme.appBarTheme.systemOverlayStyle!,
        );


        _savePreferences();
        break;
      case 'language':
        setState(() {
          _isArabic = !_isArabic;
        });
        if (_isArabic) {
          AuraViewApp.setLocale(context, Locale('ar', ''));
        } else {
          AuraViewApp.setLocale(context, Locale('en', ''));
        }
        _savePreferences();
        break;





      case 'history':
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (context) => HistoryScreen()));
        break;
    }
  }

  Widget _buildWelcomeSection() {
    final now = DateTime.now();
    final timeOfDay =
    now.hour < 12
        ? 'Morning'
        : now.hour < 17
        ? 'Afternoon'
        : 'Evening';
    //     return Card(
    //       elevation: 8.0,
    //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
    //       child: Container(
    //         padding: EdgeInsets.all(24),
    //         decoration: BoxDecoration(
    //           gradient: LinearGradient(
    //             colors: [AppTheme.primaryColor.withOpacity(0.8), AppTheme.secondaryColor.withOpacity(0.8)],
    //             begin: Alignment.topLeft,
    //             end: Alignment.bottomRight,
    //           ),
    //           borderRadius: BorderRadius.circular(20.0),
    //           boxShadow: [
    //             BoxShadow(
    //               color: AppTheme.primaryColor.withOpacity(0.3),
    //               blurRadius: 15,
    //               offset: Offset(0, 8),
    //             ),
    //           ],
    //         ),
    //         child: Column(
    //           crossAxisAlignment: CrossAxisAlignment.start,
    //           children: [
    //             Text(
    //               _isArabic ? 'مساء الخير!' : 'Good $timeOfDay!',
    //               style: TextStyle(
    //                 fontSize: 28,
    //                 fontWeight: FontWeight.bold,
    //                 color: Colors.white,
    //                 letterSpacing: 0.5,
    //               ),
    //             ),
    //             SizedBox(height: 12),
    //             Text(
    //               _isArabic ? 'كيف كان يومك اليوم؟' : 'How has your day been?',
    //               style: TextStyle(
    //                 fontSize: 18,
    //                 color: Colors.white.withOpacity(0.95),
    //                 height: 1.4,
    //               ),
    //             ),
    //           ],
    //         ),
    //       ),
    //     );

    return AnimatedGreetingCard(isArabic: _isArabic, timeOfDay: timeOfDay);
  }

  Widget _buildTodaysSummary() {
    final todaysEntry = HealthLogService.getTodaysEntry();

    if (todaysEntry == null) {
      return Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme
              .of(context)
              .cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 48,
              color: AppTheme.primaryColor,
            ),
            SizedBox(height: 16),
            Text(
              _isArabic ? 'لم تسجل بياناتك اليوم بعد' : 'No log for today yet',
              style: Theme
                  .of(context)
                  .textTheme
                  .headlineMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              _isArabic
                  ? 'انقر على الزر أدناه لبدء تسجيل يومك'
                  : 'Tap the button below to start logging your day',
              style: Theme
                  .of(context)
                  .textTheme
                  .bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme
            .of(context)
            .cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isArabic ? 'ملخص اليوم' : 'Today\'s Summary',
                style: Theme
                    .of(context)
                    .textTheme
                    .headlineMedium,
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _isArabic ? 'مكتمل' : 'Logged',
                  style: TextStyle(
                    color: AppTheme.accentColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            childAspectRatio: 1.5,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildSummaryCard(
                _isArabic ? 'المزاج' : 'Mood',
                _getMoodEmoji(todaysEntry.mood),
                AppTheme.primaryColor,
              ),
              _buildSummaryCard(
                _isArabic ? 'الماء' : 'Water',
                '${todaysEntry.waterIntake.round()}g',
                AppTheme.secondaryColor,
              ),
              _buildSummaryCard(
                _isArabic ? 'التمرين' : 'Exercise',
                '${todaysEntry.exerciseMinutes}m',
                AppTheme.accentColor,
              ),
              _buildSummaryCard(
                _isArabic ? 'النوم' : 'Sleep',
                '${todaysEntry.sleepHours.toStringAsFixed(1)}h',
                AppTheme.warningColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getMoodEmoji(double mood) {
    List<String> emojis = ['😢', '😕', '😐', '😊', '😄'];
    return emojis[(mood - 1).round().clamp(0, 4)];
  }

  Widget _buildPeriodSelector() {
    return Row(
      children: [
        Text(
          _isArabic ? 'الإحصائيات' : 'Statistics',
          style: Theme
              .of(context)
              .textTheme
              .headlineMedium,
        ),
        Spacer(),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPeriodButton('Week', 0),
              _buildPeriodButton('Month', 1),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodButton(String label, int index) {
    bool isSelected = _selectedPeriod == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPeriod = index;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          _isArabic ? (label == 'Week' ? 'أسبوع' : 'شهر') : label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.primaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildLandscapeCharts() {
    return Row(
      children: [
        Expanded(child: _buildMoodChart()),
        SizedBox(width: 16),
        Expanded(child: _buildWaterChart()),
      ],
    );
  }

  Widget _buildPortraitCharts() {
    return Column(
      children: [
        _buildMoodChart(),
        SizedBox(height: 16),
        _buildWaterChart(),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildExerciseChart()),
            SizedBox(width: 16),
            Expanded(child: _buildSleepChart()),
          ],
        ),
      ],
    );
  }

  Widget _buildMoodChart() {
    final entries =
    _selectedPeriod == 0
        ? HealthLogService.getWeeklyEntries()
        : HealthLogService.getMonthlyEntries();

    if (entries.isEmpty) {
      return _buildEmptyChart(_isArabic ? 'المزاج' : 'Mood Trends');
    }

    return Container(
      height: 200,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme
            .of(context)
            .cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isArabic ? 'اتجاهات المزاج' : 'Mood Trends',
            style: Theme
                .of(
              context,
            )
                .textTheme
                .headlineMedium
                ?.copyWith(fontSize: 16),
          ),
          SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots:
                    entries
                        .asMap()
                        .entries
                        .map((entry) {
                      return FlSpot(entry.key.toDouble(), entry.value.mood);
                    }).toList(),
                    isCurved: true,
                    color: AppTheme.primaryColor,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: AppTheme.primaryColor,
                          strokeColor: Colors.white,
                          strokeWidth: 2,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.primaryColor.withOpacity(0.2),
                    ),
                  ),
                ],
                minY: 1,
                maxY: 5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaterChart() {
    final entries =
    _selectedPeriod == 0
        ? HealthLogService.getWeeklyEntries()
        : HealthLogService.getMonthlyEntries();

    if (entries.isEmpty) {
      return _buildEmptyChart(_isArabic ? 'استهلاك الماء' : 'Water Intake');
    }

    final barWidth =
    entries.length <= 7
        ? 32.0
        : 16.0; // Adjust bar width based on number of entries

    return Container(
      height: 200,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme
            .of(context)
            .cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isArabic ? 'استهلاك الماء' : 'Water Intake',
            style: Theme
                .of(
              context,
            )
                .textTheme
                .headlineMedium
                ?.copyWith(fontSize: 16),
          ),
          SizedBox(height: 16),
          Expanded(
            child: BarChart(
              BarChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                barGroups:
                entries
                    .asMap()
                    .entries
                    .map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.waterIntake,
                        color: AppTheme.secondaryColor,
                        width: barWidth,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }).toList(),
                maxY: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseChart() {
    final entries =
    _selectedPeriod == 0
        ? HealthLogService.getWeeklyEntries()
        : HealthLogService.getMonthlyEntries();

    if (entries.isEmpty) {
      return _buildEmptyChart(_isArabic ? 'التمرين' : 'Exercise');
    }

    final totalMinutes = entries.fold<int>(
      0,
          (sum, entry) => sum + entry.exerciseMinutes,
    );
    final avgMinutes = entries.isNotEmpty ? totalMinutes / entries.length : 0;

    return Container(
      height: 120,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme
            .of(context)
            .cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isArabic ? 'التمرين' : 'Exercise',
            style: Theme
                .of(
              context,
            )
                .textTheme
                .headlineMedium
                ?.copyWith(fontSize: 14),
          ),
          Spacer(),
          Text(
            '${avgMinutes.round()}',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppTheme.accentColor,
            ),
          ),
          Text(
            _isArabic ? 'دقيقة متوسط' : 'avg minutes',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.accentColor.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSleepChart() {
    final entries =
    _selectedPeriod == 0
        ? HealthLogService.getWeeklyEntries()
        : HealthLogService.getMonthlyEntries();

    if (entries.isEmpty) {
      return _buildEmptyChart(_isArabic ? 'النوم' : 'Sleep');
    }

    final totalHours = entries.fold<double>(
      0,
          (sum, entry) => sum + entry.sleepHours,
    );
    final avgHours = entries.isNotEmpty ? totalHours / entries.length : 0;

    return Container(
      height: 120,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme
            .of(context)
            .cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isArabic ? 'النوم' : 'Sleep',
            style: Theme
                .of(
              context,
            )
                .textTheme
                .headlineMedium
                ?.copyWith(fontSize: 14),
          ),
          Spacer(),
          Text(
            avgHours.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppTheme.warningColor,
            ),
          ),
          Text(
            _isArabic ? 'ساعة متوسط' : 'avg hours',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.warningColor.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChart(String title) {
    return Container(
      height: 200,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme
            .of(context)
            .cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme
                .of(
              context,
            )
                .textTheme
                .headlineMedium
                ?.copyWith(fontSize: 16),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bar_chart,
                    size: 48,
                    color: Colors.grey.withOpacity(0.5),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _isArabic ? 'لا توجد بيانات' : 'No data available',
                    style: TextStyle(
                      color: Colors.grey.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    final allEntries = HealthLogService.getAllEntries();
    if (allEntries.isEmpty) return SizedBox.shrink();

    final totalDays = allEntries.length;
    final avgMood =
        allEntries.fold<double>(0, (sum, e) => sum + e.mood) / totalDays;
    final avgWater =
        allEntries.fold<double>(0, (sum, e) => sum + e.waterIntake) / totalDays;
    final totalExercise = allEntries.fold<int>(
      0,
          (sum, e) => sum + e.exerciseMinutes,
    );

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme
            .of(context)
            .cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isArabic ? 'إحصائيات سريعة' : 'Quick Stats',
            style: Theme
                .of(context)
                .textTheme
                .headlineMedium,
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildQuickStatItem(
                _isArabic ? 'أيام مسجلة' : 'Days Logged',
                totalDays.toString(),
                Icons.calendar_today,
                AppTheme.primaryColor,
              ),
              _buildQuickStatItem(
                _isArabic ? 'متوسط المزاج' : 'Avg Mood',
                '${avgMood.toStringAsFixed(1)}',
                Icons.sentiment_satisfied,
                AppTheme.secondaryColor,
                suffix: TextSpan(
                  text: '/5',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    color: Colors.grey,
                  ),
                ),
              ),


              _buildQuickStatItem(
                _isArabic ? 'إجمالي التمرين' : 'Total Exercise',
                '${(totalExercise / 60).toStringAsFixed(0)}h',
                Icons.fitness_center,
                AppTheme.accentColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatItem(String label,
      String value,
      IconData icon,
      Color color,
      {TextSpan? suffix}) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        SizedBox(height: 8),
        RichText(
          text: TextSpan(
            text: value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
              // Ensure default text style from theme is used for family, etc.
              fontFamily: Theme
                  .of(context)
                  .textTheme
                  .bodyLarge
                  ?.fontFamily,
            ),
            children: suffix != null ? [suffix] : [],

          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFAB() {
    final todaysEntry = HealthLogService.getTodaysEntry();

    return FloatingActionButton.extended(
      onPressed: () {
        Navigator.of(context)
            .push(
          MaterialPageRoute(
            builder:
                (context) => DailyLogFlow(), // Always push DailyLogFlow
          ),
        )
            .then((value) {
          // This block is executed when DailyLogFlow is popped.
          // Refresh the HomeScreen's state to reflect any new or updated logs.
          if (mounted) {
            setState(() {});
          }
        });
      },
      backgroundColor: AppTheme.primaryColor,
      label: Text(
        todaysEntry != null
            ? (_isArabic ? 'تحديث السجل' : 'Update Log')
            : (_isArabic ? 'سجل اليوم' : 'Log Today'),
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      icon: Icon(
        todaysEntry != null ? Icons.edit : Icons.add,
        color: Colors.white,
      ),
    );
  }
}

// History Screen
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  List<HealthLogEntry> _entries = [];

  // final String _searchQuery = ''; // Replaced by date range
  DateTimeRange? _selectedDateRange;

  bool _isArabic = false;

  @override
  void initState() {
    super.initState();
    _loadEntries();
    _loadLanguagePreference();

    _animationController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  _loadEntries() {
    setState(() {
      _entries = HealthLogService.getAllEntries();
    });
  }

  _loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isArabic = prefs.getBool('arabic_language') ?? false;
    });
  }

  List<HealthLogEntry> get _filteredEntries {
    List<HealthLogEntry> currentEntries = List.from(_entries);

    if (_selectedDateRange != null) {
      currentEntries =
          currentEntries.where((entry) {
            final entryDate = DateUtils.dateOnly(entry.date);
            final startDate = DateUtils.dateOnly(_selectedDateRange!.start);
            final endDate = DateUtils.dateOnly(_selectedDateRange!.end);
            return !entryDate.isBefore(startDate) &&
                !entryDate.isAfter(endDate);
          }).toList();
    }
    return currentEntries;
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery
            .of(context)
            .orientation == Orientation.landscape;
    final screenWidth = MediaQuery
        .of(context)
        .size
        .width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isArabic ? 'السجل التاريخي' : 'History'),
        actions: [_buildDateRangePicker()],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            if (_entries.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: Colors.grey.withOpacity(0.5),
                      ),
                      SizedBox(height: 16),
                      Text(
                        _isArabic ? 'لا توجد سجلات بعد' : 'No logs yet',
                        style: Theme
                            .of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        _isArabic
                            ? 'ابدأ بتسجيل يومك الأول'
                            : 'Start by logging your first day',
                        style: Theme
                            .of(context)
                            .textTheme
                            .bodyMedium,
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.all(isTablet ? 24 : 16),
                  itemCount: _filteredEntries.length,
                  itemBuilder: (context, index) {
                    final entry = _filteredEntries[index];
                    return _buildHistoryCard(entry, index, isTablet);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangePicker() {
    return IconButton(
      icon: Icon(Icons.date_range),
      tooltip: _isArabic ? 'تحديد نطاق التاريخ' : 'Select Date Range',
      onPressed: () async {
        final now = DateTime.now();
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(now.year - 5),
          // Allow selection up to 5 years ago
          lastDate: now,
          initialDateRange:
          _selectedDateRange ??
              DateTimeRange(start: now.subtract(Duration(days: 7)), end: now),
        );
        if (picked != null && picked != _selectedDateRange) {
          setState(() {
            _selectedDateRange = picked;
          });
        } else if (picked == null && _selectedDateRange != null) {
          // Allow clearing the filter
          setState(() {
            _selectedDateRange = null;
          });
        }
      },
    );
  }

  Widget _buildHistoryCard(HealthLogEntry entry, int index, bool isTablet) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: TweenAnimationBuilder<double>(
        duration: Duration(milliseconds: 600 + (index * 100)),
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, 50 * (1 - value)),
            child: Opacity(opacity: value, child: child),
          );
        },
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showEntryDetails(entry),
            child: Padding(
              padding: EdgeInsets.all(isTablet ? 20 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat(
                          _isArabic ? 'dd/MM/yyyy' : 'MMM dd, yyyy',
                        ).format(entry.date),
                        style: Theme
                            .of(
                          context,
                        )
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit, size: 20),
                            onPressed: () => _editEntry(entry),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, size: 20),
                            onPressed: () => _deleteEntry(entry),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMiniStat(
                          _isArabic ? 'المزاج' : 'Mood',
                          _getMoodEmoji(entry.mood),
                          AppTheme.primaryColor,
                        ),
                      ),
                      Expanded(
                        child: _buildMiniStat(
                          _isArabic ? 'الماء' : 'Water',
                          '${entry.waterIntake.round()}g',
                          AppTheme.secondaryColor,
                        ),
                      ),
                      Expanded(
                        child: _buildMiniStat(
                          _isArabic ? 'التمرين' : 'Exercise',
                          '${entry.exerciseMinutes}m',
                          AppTheme.accentColor,
                        ),
                      ),
                      Expanded(
                        child: _buildMiniStat(
                          _isArabic ? 'النوم' : 'Sleep',
                          '${entry.sleepHours.toStringAsFixed(1)}h',
                          AppTheme.warningColor,
                        ),
                      ),
                    ],
                  ),
                  if (entry.exerciseType != null) ...[
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        entry.exerciseType!,
                        style: TextStyle(
                          color: AppTheme.accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: color.withOpacity(0.8)),
        ),
      ],
    );
  }

  String _getMoodEmoji(double mood) {
    List<String> emojis = ['😢', '😕', '😐', '😊', '😄'];
    return emojis[(mood - 1).round().clamp(0, 4)];
  }

  void _showEntryDetails(HealthLogEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildEntryDetailsSheet(entry),
    );
  }

  Widget _buildEntryDetailsSheet(HealthLogEntry entry) {
    return Container(
      height: MediaQuery
          .of(context)
          .size
          .height * 0.6,
      decoration: BoxDecoration(
        color: Theme
            .of(context)
            .scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat(
                    _isArabic ? 'dd MMMM yyyy' : 'MMMM dd, yyyy',
                  ).format(entry.date),
                  style: Theme
                      .of(context)
                      .textTheme
                      .headlineMedium,
                ),
                SizedBox(height: 24),
                _buildDetailRow(
                  _isArabic ? 'المزاج' : 'Mood',
                  '${_getMoodEmoji(entry.mood)} ${entry.mood.toStringAsFixed(
                      1)}/5',
                  Icons.sentiment_satisfied,
                  AppTheme.primaryColor,
                ),
                _buildDetailRow(
                  _isArabic ? 'استهلاك الماء' : 'Water Intake',
                  '${entry.waterIntake.round()} glasses (${(entry.waterIntake *
                      250).round()}ml)',
                  Icons.local_drink,
                  AppTheme.secondaryColor,
                ),
                _buildDetailRow(
                  _isArabic ? 'التمرين' : 'Exercise',
                  '${entry.exerciseMinutes} minutes${entry.exerciseType != null
                      ? " - ${entry.exerciseType}"
                      : ""}',
                  Icons.fitness_center,
                  AppTheme.accentColor,
                ),
                _buildDetailRow(
                  _isArabic ? 'النوم' : 'Sleep',
                  '${entry.sleepHours.toStringAsFixed(1)} hours',
                  Icons.bedtime,
                  AppTheme.warningColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label,
      String value,
      IconData icon,
      Color color,) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              Text(
                value,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _editEntry(HealthLogEntry entry) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => EditEntryScreen(entry: entry),
      ),
    )
        .then((_) {
      _loadEntries(); // Refresh the list
    });
  }

  void _deleteEntry(HealthLogEntry entry) {
    showDialog(
      context: context,
      builder:
          (context) =>
          AlertDialog(
            title: Text(_isArabic ? 'حذف السجل' : 'Delete Entry'),
            content: Text(
              _isArabic
                  ? 'هل أنت متأكد من حذف سجل ${DateFormat('dd/MM/yyyy').format(
                  entry.date)}؟'
                  : 'Are you sure you want to delete the entry for ${DateFormat(
                  'MMM dd, yyyy').format(entry.date)}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(_isArabic ? 'إلغاء' : 'Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  await HealthLogService.deleteEntry(entry);
                  Navigator.of(context).pop();
                  _loadEntries();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _isArabic ? 'تم حذف السجل' : 'Entry deleted',
                      ),
                      backgroundColor: AppTheme.accentColor,
                    ),
                  );
                },
                child: Text(
                  _isArabic ? 'حذف' : 'Delete',
                  style: TextStyle(color: AppTheme.errorColor),
                ),
              ),
            ],
          ),
    );
  }
}

// Search Delegate
class HealthLogSearchDelegate extends SearchDelegate<String> {
  final List<HealthLogEntry> entries;
  final bool isArabic;

  HealthLogSearchDelegate(this.entries, this.isArabic);

  @override
  String get searchFieldLabel =>
      isArabic ? 'بحث حسب نوع التمرين' : 'Search by exercise type';

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        tooltip: isArabic ? 'مسح' : 'Clear',
        icon: Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      tooltip: isArabic ? 'رجوع' : 'Back',
      icon: Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    final filteredEntries =
    entries.where((entry) {
      final exerciseType = entry.exerciseType?.toLowerCase() ?? '';
      // Only filter by exercise type now
      return exerciseType.contains(query.toLowerCase());
    }).toList();

    if (filteredEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey.withOpacity(0.5),
            ),
            SizedBox(height: 16),
            Text(
              isArabic ? 'لا توجد نتائج' : 'No results found',
              style: Theme
                  .of(
                context,
              )
                  .textTheme
                  .headlineMedium
                  ?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: filteredEntries.length,
      itemBuilder: (context, index) {
        final entry = filteredEntries[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
              child: Text(_getMoodEmoji(entry.mood)),
            ),
            title: Text(
              DateFormat(
                isArabic ? 'dd/MM/yyyy' : 'MMM dd, yyyy',
              ).format(entry.date),
            ),
            subtitle: Text(
              '${isArabic ? 'الماء' : 'Water'}: ${entry.waterIntake
                  .round()}g | '
                  '${isArabic ? 'التمرين' : 'Exercise'}: ${entry
                  .exerciseMinutes}m | '
                  '${isArabic ? 'النوم' : 'Sleep'}: ${entry.sleepHours
                  .toStringAsFixed(1)}h',
            ),
            onTap: () {
              close(context, '');
              // Optionally, navigate to the details of this entry or perform other action
              // For now, it just closes the search.
            },
          ),
        );
      },
    );
  }

  String _getMoodEmoji(double mood) {
    List<String> emojis = ['😢', '😕', '😐', '😊', '😄'];
    return emojis[(mood - 1).round().clamp(0, 4)];
  }
}

// Edit Entry Screen
class EditEntryScreen extends StatefulWidget {
  final HealthLogEntry entry;

  const EditEntryScreen({super.key, required this.entry});

  @override
  _EditEntryScreenState createState() => _EditEntryScreenState();
}

class _EditEntryScreenState extends State<EditEntryScreen> {
  late double _mood;
  late double _waterIntake;
  late int _exerciseMinutes;
  late String _exerciseType;
  late double _sleepHours;
  bool _isArabic = false;

  final List<String> _exerciseTypes = [
    'Walking',
    'Running',
    'Cycling',
    'Swimming',
    'Yoga',
    'Gym',
    'Dancing',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
    _mood = widget.entry.mood;
    _waterIntake = widget.entry.waterIntake;
    _exerciseMinutes = widget.entry.exerciseMinutes;
    _exerciseType = widget.entry.exerciseType ?? 'Walking';
    _sleepHours = widget.entry.sleepHours;
  }

  _loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isArabic = prefs.getBool('arabic_language') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isArabic ? 'تحرير السجل' : 'Edit Entry'),
        actions: [
          TextButton(
            onPressed: _saveEntry,
            child: Text(
              _isArabic ? 'حفظ' : 'Save',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat(
                _isArabic ? 'dd MMMM yyyy' : 'MMMM dd, yyyy',
              ).format(widget.entry.date),
              style: Theme
                  .of(context)
                  .textTheme
                  .headlineMedium,
            ),
            SizedBox(height: 32),
            _buildMoodSection(),
            SizedBox(height: 32),
            _buildWaterSection(),
            SizedBox(height: 32),
            _buildExerciseSection(),
            SizedBox(height: 32),
            _buildSleepSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isArabic ? 'المزاج' : 'Mood',
          style: Theme
              .of(context)
              .textTheme
              .headlineSmall,
        ),
        SizedBox(height: 16),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppTheme.primaryColor,
            thumbColor: AppTheme.primaryColor,
            trackHeight: 8.0, // Make slider thicker
          ),
          child: Slider(
            value: _mood,
            min: 1,
            max: 5,
            divisions: 4,
            label: _getMoodEmoji(_mood),
            onChanged: (value) {
              setState(() {
                _mood = value;
              });
            },
          ),
        ),
        Center(
          child: Text(
            '${_getMoodEmoji(_mood)} ${_mood.toStringAsFixed(1)}/5',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildWaterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isArabic ? 'استهلاك الماء' : 'Water Intake',
          style: Theme
              .of(context)
              .textTheme
              .headlineSmall,
        ),
        SizedBox(height: 16),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppTheme.secondaryColor,
            thumbColor: AppTheme.secondaryColor,
            trackHeight: 8.0, // Make slider thicker
          ),
          child: Slider(
            value: _waterIntake,
            min: 0,
            max: 12,
            divisions: 12,
            label: '${_waterIntake.round()} glasses',
            onChanged: (value) {
              setState(() {
                _waterIntake = value;
              });
            },
          ),
        ),
        Center(
          child: Text(
            '${_waterIntake.round()} ${_isArabic
                ? 'كوب'
                : 'glasses'} (${(_waterIntake * 250).round()}ml)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isArabic ? 'التمرين' : 'Exercise',
          style: Theme
              .of(context)
              .textTheme
              .headlineSmall,
        ),
        SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _exerciseType,
          items:
          _exerciseTypes.map((String type) {
            return DropdownMenuItem<String>(value: type, child: Text(type));
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _exerciseType = value;
              });
            }
          },
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        SizedBox(height: 16),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppTheme.accentColor,
            thumbColor: AppTheme.accentColor,
            trackHeight: 8.0, // Make slider thicker
          ),
          child: Slider(
            value: _exerciseMinutes.toDouble(),
            min: 0,
            max: 180,
            divisions: 18,
            label: '${_exerciseMinutes.round()} min',
            onChanged: (value) {
              setState(() {
                _exerciseMinutes = value.round();
              });
            },
          ),
        ),
        Center(
          child: Text(
            '$_exerciseMinutes ${_isArabic ? 'دقيقة' : 'minutes'}',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildSleepSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isArabic ? 'النوم' : 'Sleep',
          style: Theme
              .of(context)
              .textTheme
              .headlineSmall,
        ),
        SizedBox(height: 16),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppTheme.warningColor,
            thumbColor: AppTheme.warningColor,
            trackHeight: 8.0, // Make slider thicker
          ),
          child: Slider(
            value: _sleepHours,
            min: 0,
            max: 12,
            divisions: 24,
            // 0.5 hour increments
            label: '${_sleepHours.toStringAsFixed(1)} hours',
            onChanged: (value) {
              setState(() {
                _sleepHours = value;
              });
            },
          ),
        ),
        Center(
          child: Text(
            '${_sleepHours.toStringAsFixed(1)} ${_isArabic
                ? 'ساعات'
                : 'hours'}',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  void _saveEntry() async {
    final updatedEntry = HealthLogEntry(
      date: widget.entry.date,
      // Keep the original date
      mood: _mood,
      waterIntake: _waterIntake,
      exerciseMinutes: _exerciseMinutes,
      sleepHours: _sleepHours,
      exerciseType: _exerciseType,
    );

    await HealthLogService.saveEntry(updatedEntry);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isArabic ? 'تم تحديث السجل' : 'Entry updated'),
        backgroundColor: AppTheme.accentColor,
      ),
    );
  }

  String _getMoodEmoji(double mood) {
    List<String> emojis = ['😢', '😕', '😐', '😊', '😄'];
    return emojis[(mood - 1).round().clamp(0, 4)];
  }
}

class AnimatedGreetingCard extends StatefulWidget {
  final bool isArabic;
  final String timeOfDay;

  const AnimatedGreetingCard({
    Key? key,
    required this.isArabic,
    required this.timeOfDay,
  }) : super(key: key);

  @override
  _AnimatedGreetingCardState createState() => _AnimatedGreetingCardState();
}

class _AnimatedGreetingCardState extends State<AnimatedGreetingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 8),
    )
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final angle = _controller.value * 2 * math.pi;
        return Transform.scale(
          scale: 1 + math.sin(angle) * 0.005, // very subtle pulse
          child: Card(
            elevation: 12,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            clipBehavior: Clip.antiAlias,
            child: Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color.lerp(
                      AppTheme.primaryColor,
                      AppTheme.secondaryColor,
                      (math.sin(angle) + 1) / 2,
                    )!,
                    Color.lerp(
                      AppTheme.secondaryColor,
                      AppTheme.primaryColor,
                      (math.cos(angle) + 1) / 2,
                    )!,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20.0),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.25),
                    blurRadius: 15 + math.sin(angle) * 2,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isArabic
                        ? 'مساء الخير!'
                        : 'Good ${widget.timeOfDay}!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    widget.isArabic
                        ? 'كيف كان يومك اليوم؟'
                        : 'How has your day been?',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white.withOpacity(0.95),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
