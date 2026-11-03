import 'package:flutter/material.dart';
import '../data/account_repository.dart';
import 'new_account_screen.dart';
import 'account_details_screen.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key, required this.language});
  final String language;

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final AccountRepository _repository = AccountRepository();
  final TextEditingController _search = TextEditingController();
  late Future<List<Map<String, Object?>>> _accounts;

  bool get _urdu => widget.language == 'ur';
  Future<void> _addAccount() async {
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => NewAccountScreen(language: widget.language)));
    if (saved == true && mounted) setState(() => _accounts = _repository.searchAccounts(_search.text));
  }
  String _text(String key) {
    const values = {
      'ur': {
        'title': 'کھاتے', 'search': 'نام یا کھاتہ نمبر تلاش کریں',
        'empty': 'ابھی کوئی کھاتہ موجود نہیں',
        'hint': 'نیا کھاتہ بنانے کے لیے + دبائیں',
        'add': 'نیا کھاتہ',
        'number': 'کھاتہ نمبر', 'phone': 'فون نمبر',
        'error': 'کھاتے لوڈ نہیں ہو سکے',
      },
      'en': {
        'title': 'Accounts', 'search': 'Search by name or account number',
        'empty': 'No accounts yet',
        'hint': 'Tap + to create a new account',
        'add': 'New Account',
        'number': 'Account No.', 'phone': 'Phone number',
        'error': 'Could not load accounts',
      },
      'hi': {
        'title': 'खाते', 'search': 'नाम या खाता नंबर खोजें',
        'empty': 'अभी कोई खाता नहीं है',
        'hint': 'नया खाता बनाने के लिए + दबाएँ',
        'add': 'नया खाता',
        'number': 'खाता नंबर', 'phone': 'फ़ोन नंबर',
        'error': 'खाते लोड नहीं हो सके',
      },
    };
    return values[widget.language]?[key] ?? values['en']![key]!;
  }

  @override
  void initState() {
    super.initState();
    _accounts = _repository.searchAccounts('');
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _searchChanged(String value) {
    setState(() => _accounts = _repository.searchAccounts(value));
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: _urdu ? TextDirection.rtl : TextDirection.ltr,
        child: Column(
          children: [
            Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: Row(children: [
              Expanded(child: Text(_text('title'), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold))),
              FilledButton.icon(onPressed: _addAccount, icon: const Icon(Icons.add), label: Text(_text('add'))),
            ])),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: TextField(
                controller: _search,
                onChanged: _searchChanged,
                textDirection: _urdu ? TextDirection.rtl : TextDirection.ltr,
                decoration: InputDecoration(
                  hintText: _text('search'),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _search.clear();
                            _searchChanged('');
                          },
                          icon: const Icon(Icons.close),
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFB7D8F5)),
                  ),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, Object?>>>(
                future: _accounts,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text(_text('error')));
                  }
                  final accounts = snapshot.data ?? [];
                  if (accounts.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.people_outline,
                                size: 68, color: Color(0xFF78A9D5)),
                            const SizedBox(height: 12),
                            Text(
                              _text('empty'),
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF173D67),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _text('hint'),
                              style: const TextStyle(color: Colors.blueGrey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
                    itemCount: accounts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 9),
                    itemBuilder: (context, index) {
                      final account = accounts[index];
                      final name = account['customer_name'] as String? ?? '';
                      final number = account['account_number'];
                      final phone = account['phone_number'] as String? ?? '';
                      final code = account['country_code'] as String? ?? '';
                      return Card(
                        color: Colors.white,
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: const BorderSide(color: Color(0xFFD6E8F8)),
                        ),
                        child: ListTile(
                          onTap: () async {
                            await Navigator.push<void>(context, MaterialPageRoute(
                              builder: (_) => AccountDetailsScreen(
                                accountId: account['id'].toString(),
                                language: widget.language,
                              ),
                            ));
                            if (mounted) setState(() => _accounts = _repository.searchAccounts(_search.text));
                          },
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFE0F8E8),
                            child: Text(
                              '$number',
                              style: const TextStyle(
                                color: Color(0xFF087B32),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('$code $phone'),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
}
