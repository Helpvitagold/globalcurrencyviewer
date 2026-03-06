import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const CurrencyApp(),
    );
  }
}

class CurrencyApp extends StatefulWidget {
  const CurrencyApp({super.key});
  @override
  State<CurrencyApp> createState() => _CurrencyAppState();
}

class _CurrencyAppState extends State<CurrencyApp> {
  double baseAmount = 1000.0;
  String baseCurrency = 'KRW';
  List<String> targetCurrencies = ['USD', 'JPY', 'EUR'];
  Map<String, double> rates = {};
  List<String> presetNames = ['프리셋 1', '프리셋 2', '프리셋 3', '프리셋 4'];
  String lastUpdated = "업데이트 기록 없음";
  int selectedPresetIndex = -1;

  final Map<String, String> currencyData = {
    'KRW': '대한민국 한국 원',
    'USD': '미국 달러',
    'JPY': '일본 엔',
    'EUR': '유럽 유로',
    'CNY': '중국 위안',
    'VND': '베트남 동',
    'THB': '태국 바트',
    'PHP': '필리핀 페소',
    'TWD': '대만 달러',
    'HKD': '홍콩 달러',
    'SGD': '싱가포르 달러',
    'AUD': '호주 달러',
    'GBP': '영국 파운드',
    'CAD': '캐나다 달러',
    'CHF': '스위스 프랑',
    'IDR': '인도네시아 루피아',
    'MYR': '말레이시아 링깃',
  };

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        presetNames =
            prefs.getStringList('preset_names') ??
            ['프리셋 1', '프리셋 2', '프리셋 3', '프리셋 4'];
        // 💡 저장된 리스트가 있으면 불러오고, 없으면 기본값 사용
        targetCurrencies =
            prefs.getStringList('current_list') ?? ['USD', 'JPY', 'EUR'];
      });
    }
    await _loadOfflineData();
    fetchRates();
  }

  String _formatNumber(double number, String code) {
    List<String> noDecimal = ['KRW', 'JPY', 'VND', 'IDR', 'THB', 'PHP'];
    String formatted = noDecimal.contains(code)
        ? number.round().toString()
        : number.toStringAsFixed(2);
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return formatted.replaceAllMapped(reg, (Match m) => '${m[1]},');
  }

  Future<void> _loadOfflineData() async {
    final prefs = await SharedPreferences.getInstance();
    String? cachedRates = prefs.getString('cached_rates');
    if (cachedRates != null && mounted) {
      setState(() {
        rates = Map<String, double>.from(json.decode(cachedRates));
        lastUpdated = prefs.getString('last_updated') ?? "시간 정보 없음";
      });
    }
  }

  Future<void> fetchRates() async {
    try {
      final res = await http
          .get(Uri.parse('https://open.er-api.com/v6/latest/$baseCurrency'))
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200 && mounted) {
        final Map<String, dynamic> data = json.decode(res.body);
        DateTime now = DateTime.now();
        String formattedTime =
            "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
        setState(() {
          rates = (data['rates'] as Map).map(
            (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
          );
          lastUpdated = formattedTime;
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_rates', json.encode(rates));
        await prefs.setString('last_updated', lastUpdated);
      }
    } catch (e) {
      await _loadOfflineData();
    }
  }

  void _showSearchDialog(bool isBase) {
    String query = "";
    List<String> selectedCodes = [];
    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final results = currencyData.keys
              .where(
                (code) => (code + (currencyData[code] ?? ""))
                    .toLowerCase()
                    .contains(query.toLowerCase()),
              )
              .toList();
          return AlertDialog(
            title: Text(isBase ? "기준 통화 선택" : "통화 다중 추가"),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: "국가명 또는 코드 입력",
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setDialogState(() => query = v),
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: results.length,
                      itemBuilder: (ctx, i) {
                        final c = results[i];
                        return CheckboxListTile(
                          secondary: SizedBox(
                            // 💡 이모지 박스가 깨지지 않게 크기를 고정
                            width: 40,
                            child: Text(
                              _getFlag(c),
                              style: const TextStyle(fontSize: 20),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          title: Text(c),
                          value: selectedCodes.contains(c),
                          onChanged: (val) {
                            setDialogState(() {
                              if (isBase)
                                selectedCodes = [c];
                              else
                                (val == true)
                                    ? selectedCodes.add(c)
                                    : selectedCodes.remove(c);
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text("취소"),
              ),
              ElevatedButton(
                onPressed: selectedCodes.isEmpty
                    ? null
                    : () {
                        setState(() {
                          if (isBase)
                            baseCurrency = selectedCodes.first;
                          else {
                            for (var code in selectedCodes) {
                              if (!targetCurrencies.contains(code))
                                targetCurrencies.add(code);
                            }
                          }
                          selectedPresetIndex = -1;
                        });
                        fetchRates();
                        Navigator.pop(dialogCtx);
                      },
                child: const Text("확인"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> saveAndRenamePreset(int i) async {
    TextEditingController ctrl = TextEditingController(
      text: i <= presetNames.length ? presetNames[i - 1] : "",
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("프리셋 설정 & 저장"),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: "프리셋 이름"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("취소"),
          ),
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              setState(() {
                if (i > presetNames.length)
                  presetNames.add(ctrl.text);
                else
                  presetNames[i - 1] = ctrl.text;
                selectedPresetIndex = i;
              });
              await prefs.setStringList('preset_names', presetNames);
              await prefs.setString('p$i', json.encode(targetCurrencies));
              Navigator.pop(ctx);
            },
            child: const Text("확인"),
          ),
        ],
      ),
    );
  }

  Future<void> loadPreset(int i) async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString('p$i');
    if (data != null && mounted) {
      setState(() {
        targetCurrencies = List<String>.from(json.decode(data));
        selectedPresetIndex = i;
      });
      fetchRates();
    }
  }

  String _getFlag(String code) {
    if (code == 'EUR') return "🇪🇺";
    return code
        .substring(0, 2)
        .toUpperCase()
        .replaceAllMapped(
          RegExp(r'[A-Z]'),
          (m) => String.fromCharCode(m.group(0)!.codeUnitAt(0) + 127397),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Global Currency Viewer',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo.shade50,
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Container(
            color: Colors.white,
            child: Column(
              children: [
                _buildInputSection(),
                _buildUpdateInfo(),
                _buildPresetGrid(),
                _buildAddButtonInline(), // 💡 프리셋 아래로 이동한 통화 추가 버튼
                const Divider(
                  height: 32,
                  thickness: 1,
                  indent: 16,
                  endIndent: 16,
                ),
                _buildCurrencyList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: IntrinsicHeight(
        // 💡 핵심: 자식들 중 가장 높은 위젯에 높이를 맞춤
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.stretch, // 💡 중요: 높이를 꽉 채우도록 강제
          children: [
            // 1. 좌측 통화 선택 버튼
            InkWell(
              onTap: () => _showSearchDialog(true),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ), // 💡 높이 기준점이 됨
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.indigo.shade100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getFlag(baseCurrency),
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "$baseCurrency▼",
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 2. 우측 금액 입력창
            Expanded(
              child: TextField(
                textAlignVertical: TextAlignVertical.center, // 💡 텍스트 수직 중앙 정렬
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: '금액 입력 (미입력시 1,000원 기준)',
                  hintStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                  ),
                  isDense: true,
                  // 💡 contentPadding을 적절히 주어 내부 텍스트가 박스 정중앙에 오도록 보정
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Colors.indigo,
                      width: 1.5,
                    ),
                  ),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandSeparatorInputFormatter()],
                onChanged: (v) => setState(
                  () =>
                      baseAmount = double.tryParse(v.replaceAll(',', '')) ?? 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      width: double.infinity,
      child: Text(
        "마지막 업데이트: $lastUpdated",
        style: const TextStyle(fontSize: 10, color: Colors.grey),
      ),
    );
  }

  Widget _buildPresetGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: constraints.maxWidth > 600 ? 5.0 : 3.5,
            ),
            itemCount: 4,
            itemBuilder: (context, index) {
              int i = index + 1;
              bool isSelected = selectedPresetIndex == i;
              String name = i <= presetNames.length
                  ? presetNames[index]
                  : "프리셋 $i";
              return Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.indigo.shade100 : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Colors.indigo : Colors.grey.shade300,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => loadPreset(i),
                        child: Center(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? Colors.indigo.shade900
                                  : Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => saveAndRenamePreset(i),
                      child: Container(
                        width: 40,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.indigo.shade200.withOpacity(0.4)
                              : Colors.grey.shade100,
                          border: Border(
                            left: BorderSide(
                              color: isSelected
                                  ? Colors.indigo
                                  : Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                        ),
                        child: const Center(
                          child: Text("📝", style: TextStyle(fontSize: 14)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // 💡 피드백 반영: 프리셋 아래로 이동한 인라인 추가 버튼
  Widget _buildAddButtonInline() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ElevatedButton.icon(
        onPressed: () => _showSearchDialog(false),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.indigo,
          minimumSize: const Size(double.infinity, 48), // 가로 가득 채움
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 2,
        ),
        icon: const Text("💱", style: TextStyle(fontSize: 16)),
        label: const Text(
          "통화 추가하기",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildCurrencyList() {
    return Expanded(
      child: ReorderableListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        buildDefaultDragHandles: false,
        itemCount: targetCurrencies.length,
        onReorder: (int oldIndex, int newIndex) async {
          setState(() {
            if (oldIndex < newIndex) newIndex -= 1;
            final String item = targetCurrencies.removeAt(oldIndex);
            targetCurrencies.insert(newIndex, item);
            selectedPresetIndex = -1;
          });
          final prefs = await SharedPreferences.getInstance();
          await prefs.setStringList('current_list', targetCurrencies);
        },
        itemBuilder: (context, index) {
          String c = targetCurrencies[index];
          double r = rates[c] ?? 0;

          // 💡 1,000원 기준 계산 로직
          String referenceText =
              "1,000 $baseCurrency ≒ ${_formatNumber(1000.0 * r, c)} $c";

          return Card(
            key: ValueKey(c),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: Text(
                        "☰",
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ),
                  ),
                  Text(_getFlag(c), style: const TextStyle(fontSize: 24)),
                ],
              ),
              title: Text(
                "${_formatNumber(baseAmount * r, c)} $c",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              // 💡 피드백 반영: 1,000원 기준 비교 문구 노출
              subtitle: Text(
                referenceText,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.indigo,
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: IconButton(
                icon: const Text("❌", style: TextStyle(fontSize: 16)),
                onPressed: () {
                  setState(() {
                    targetCurrencies.removeAt(index);
                    selectedPresetIndex = -1;
                  });
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class ThousandSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldV,
    TextEditingValue newV,
  ) {
    if (newV.text.isEmpty) return newV;
    String numText = newV.text.replaceAll(',', '');
    final double? num = double.tryParse(numText);
    if (num == null) return oldV;
    String formatted = numText.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return newV.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
