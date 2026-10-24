import 'package:brahma_core/brahma_core.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../db/database.dart';
import '../domain/contact_links.dart';
import 'common.dart';
import 'property_page.dart';

const contactRoles = {
  'agent': 'Letting or estate agent',
  'landlord': 'Landlord',
  'tenant': 'Tenant',
  'broker': 'Mortgage broker',
  'solicitor': 'Solicitor',
  'trade': 'Trades',
  'other': 'Other',
};

class ContactsPage extends ConsumerWidget {
  const ContactsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => PageScaffold(
    title: 'Contacts',
    banner: 'page.contacts',
    fab: FloatingActionButton.extended(
      heroTag: null,
      onPressed: () => editContact(context, ref),
      icon: const Icon(Icons.person_add_alt),
      label: const Text('Add'),
    ),
    children: [
      AsyncView(
        ref.watch(contactsProvider),
        builder: (contacts) => contacts.isEmpty
            ? const EmptyState(
                icon: Icons.contacts_outlined,
                title: 'No contacts yet',
                message:
                    'Agents are added when you add their adverts. Add landlords, brokers and others here.',
              )
            : Column(
                children: [
                  for (final c in contacts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => editContact(context, ref, c: c),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(c.name, style: Theme.of(context).textTheme.titleSmall),
                                      Text(
                                        [
                                          contactRoles[c.role] ?? c.role,
                                          if (c.organisation.isNotEmpty && c.organisation != c.name)
                                            c.organisation,
                                          if (c.phone.isNotEmpty) c.phone,
                                        ].join(' · '),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              ContactButtons(c),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    ],
  );
}

/// Call, text, WhatsApp and e-mail buttons. Each logs what it started,
/// against [propertyId] when given.
class ContactButtons extends ConsumerWidget {
  const ContactButtons(this.c, {super.key, this.propertyId});
  final Contact c;
  final String? propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> go(String channel, Uri uri) async {
      if (await openUri(context, uri)) {
        await ref.mutate(
          (s) => s.book.log(propertyId: propertyId, contactId: c.id, channel: channel, at: nowLocal()),
        );
      }
    }

    return Wrap(
      children: [
        if (c.phone.isNotEmpty) ...[
          IconButton(
            tooltip: 'Call',
            icon: Icon(channelIcons['call']),
            onPressed: () => go('call', callUri(c.phone)),
          ),
          IconButton(
            tooltip: 'Text',
            icon: Icon(channelIcons['sms']),
            onPressed: () => go('sms', smsUri(c.phone)),
          ),
          IconButton(
            tooltip: 'WhatsApp',
            icon: Icon(channelIcons['whatsapp']),
            onPressed: () => go('whatsapp', whatsAppUri(c.phone)),
          ),
        ],
        if (c.email.isNotEmpty)
          IconButton(
            tooltip: 'E-mail',
            icon: Icon(channelIcons['email']),
            onPressed: () => go('email', mailUri(c.email)),
          ),
      ],
    );
  }
}

/// Adds or edits a contact; returns its id when saved.
Future<String?> editContact(BuildContext context, WidgetRef ref, {Contact? c}) async {
  final name = TextEditingController(text: c?.name);
  final organisation = TextEditingController(text: c?.organisation);
  final phone = TextEditingController(text: c?.phone);
  final email = TextEditingController(text: c?.email);
  final notes = TextEditingController(text: c?.notes);
  var role = c?.role ?? 'agent';
  final id = c?.id ?? newId();
  final ok = await showFormDialog(
    context,
    title: c == null ? 'New contact' : 'Edit contact',
    fields: (setState) => [
      Field(name, 'Name', autofocus: c == null),
      Choice(label: 'Role', value: role, options: contactRoles, onChanged: (v) => setState(() => role = v)),
      Field(organisation, 'Company'),
      Field(phone, 'Phone'),
      Field(email, 'E-mail'),
      Field(notes, 'Notes', lines: 3),
    ],
    onSave: () async {
      if (name.text.trim().isEmpty) return 'Enter a name.';
      await ref.mutate(
        (s) => s.book.save(
          s.db.contacts,
          ContactsCompanion(
            id: Value(id),
            name: Value(name.text.trim()),
            role: Value(role),
            organisation: Value(organisation.text.trim()),
            phone: Value(phone.text.trim()),
            email: Value(email.text.trim()),
            notes: Value(notes.text.trim()),
          ),
          id,
        ),
      );
      return null;
    },
  );
  return ok ? id : null;
}
