import SwiftUI

// The couple's registry (Figma: CR1 · Registry, CR2 · Gift advisor, CR3 · Link a registry,
// CR4 · Track gifts). Guests choose gifts on the website; their choices arrive when the app syncs.

private enum RegistryPage: Hashable {
    case advisor, links, bought
}

// MARK: - CR1 · Registry

struct CoupleRegistryView: View {
    @Environment(AppStore.self) private var store
    @State private var editing: RegistryItem?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    ScreenHeader(title: "Registry", subtitle: "Gifts and cash funds guests can choose from")

                    HStack(spacing: Space.sm) {
                        NavigationLink(value: RegistryPage.bought) {
                            StatTile(value: "\(store.registryGifts.count)", label: "gifts listed")
                        }
                        NavigationLink(value: RegistryPage.bought) {
                            StatTile(value: "\(store.takenGiftCount)", label: "bought so far")
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(height: 76)

                    if !store.registryFunds.isEmpty {
                        itemSection("Cash funds", store.registryFunds)
                    }
                    if !store.registryGifts.isEmpty {
                        itemSection("Gifts", store.registryGifts)
                    }
                    if store.data.registry.isEmpty {
                        Panel(background: Palette.bgAccentSubtle, bordered: false) {
                            Text("Start your registry")
                                .font(Typo.title3)
                                .foregroundStyle(Palette.textPrimary)
                            Text("Add gifts and cash funds. Guests see them on your wedding website and can say “I’ll get this,” so nobody buys the same thing twice.")
                                .font(Typo.subheadline)
                                .foregroundStyle(Palette.textPrimary)
                        }
                    }

                    Button("Add a gift") { editing = RegistryItem(name: "", price: 0) }
                        .buttonStyle(.primary)

                    RowGroup {
                        NavigationLink(value: RegistryPage.bought) {
                            ListRow(title: "Gifts bought", subtitle: boughtSubtitle, systemImage: "checkmark.seal")
                        }
                        RowDivider()
                        NavigationLink(value: RegistryPage.advisor) {
                            ListRow(title: "Gift advisor", subtitle: "Price ranges for your guest list", systemImage: "lightbulb")
                        }
                        RowDivider()
                        NavigationLink(value: RegistryPage.links) {
                            ListRow(title: "Link a registry", subtitle: linksSubtitle, systemImage: "link")
                        }
                    }
                    .buttonStyle(.plain)
                }
                .screenStyle()
            }
            .refreshable { await store.sync() }
            .background(Palette.bgCanvas)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: RegistryPage.self) { page in
                switch page {
                case .advisor: GiftAdvisorView { editing = RegistryItem(name: "", price: $0) }
                case .links: LinkRegistryView()
                case .bought: GiftsBoughtView()
                }
            }
            .sheet(item: $editing) { RegistryItemEditor(item: $0) }
        }
    }

    private func itemSection(_ title: String, _ items: [RegistryItem]) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            SectionTitle(title)
            RowGroup {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { RowDivider() }
                    Button { editing = item } label: {
                        ListRow(title: item.name, subtitle: store.registrySubtitle(item))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Edit")
                }
            }
        }
    }

    private var boughtSubtitle: String {
        let due = store.gifts.filter { !$0.thankYouSent }.count
        if store.gifts.isEmpty { return "Who gave what shows up here" }
        return due == 0 ? "All thank-yous sent" : (due == 1 ? "1 thank-you to send" : "\(due) thank-yous to send")
    }

    private var linksSubtitle: String {
        let count = store.registryLinks.count
        return count == 0 ? "Show gifts from another store" : (count == 1 ? "1 store linked" : "\(count) stores linked")
    }
}

// MARK: - Add or edit a gift

struct RegistryItemEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var item: RegistryItem
    @State private var priceText: String
    @State private var confirmingDelete = false
    private let isNew: Bool

    init(item: RegistryItem) {
        _item = State(initialValue: item)
        _priceText = State(initialValue: item.price > 0 ? "\(item.price)" : "")
        isNew = item.name.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    Picker("Kind", selection: $item.isFund) {
                        Text("Gift").tag(false)
                        Text("Cash fund").tag(true)
                    }
                    .pickerStyle(.segmented)

                    LabeledField(label: "Name", text: $item.name,
                                 placeholder: item.isFund ? "e.g. Honeymoon fund" : "e.g. Dutch oven")
                    LabeledField(label: item.isFund ? "Goal ($)" : "Price ($)", text: $priceText,
                                 placeholder: item.isFund ? "3000" : "120",
                                 helper: item.isFund ? "Guests choose how much to give. They’ll see how close you are." : nil)
                        .keyboardType(.numberPad)
                    if !item.isFund {
                        LabeledField(label: "Store link (optional)", text: $item.link, placeholder: "https://",
                                     helper: "Guests tap it to buy the gift.",
                                     error: !item.link.isEmpty && item.linkURL == nil ? "That doesn’t look like a web address." : nil)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    LabeledField(label: "Note for guests (optional)", text: $item.note,
                                 placeholder: item.isFund ? "Two weeks in Portugal." : "Queen size, in oat.", multiline: true)

                    if !item.isFund && !isNew {
                        FieldBox(label: "Status", helper: "Turn on for gifts that arrived another way, so guests don’t buy them again.") {
                            Toggle("Mark as bought", isOn: $item.purchased)
                        }
                    }

                    if !isNew {
                        let given = store.gifts(for: item)
                        if !given.isEmpty {
                            VStack(alignment: .leading, spacing: Space.xs) {
                                SectionTitle(item.isFund ? "Given so far" : "Getting this")
                                RowGroup {
                                    ForEach(Array(given.enumerated()), id: \.element.id) { index, gift in
                                        if index > 0 { RowDivider() }
                                        ListRow(title: giverName(gift),
                                                subtitle: [item.isFund ? Format.price(gift.amount) : nil, Format.dayShort(gift.givenAt),
                                                           gift.note.isEmpty ? nil : "“\(gift.note)”"]
                                                    .compactMap { $0 }.joined(separator: " · "),
                                                showsChevron: false)
                                    }
                                }
                            }
                        }
                        Button("Remove from registry", role: .destructive) { confirmingDelete = true }
                            .buttonStyle(.tertiary)
                            .foregroundStyle(Palette.textError)
                    }
                }
                .screenStyle()
            }
            .background(Palette.bgCanvas)
            .navigationTitle(isNew ? (item.isFund ? "Add a cash fund" : "Add a gift") : item.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Add" : "Save") {
                        item.price = Int(priceText.filter(\.isNumber)) ?? 0
                        store.saveRegistryItem(item)
                        dismiss()
                    }
                    .disabled(item.name.trimmingCharacters(in: .whitespaces).isEmpty
                              || (!item.link.isEmpty && item.linkURL == nil))
                }
            }
            .confirmationDialog("Remove \(item.name)?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Remove", role: .destructive) {
                    store.deleteRegistryItem(item.id)
                    dismiss()
                }
            } message: {
                Text("Guests won’t see it any more. Anything guests already gave stays with them.")
            }
        }
    }

    private func giverName(_ gift: RegistryGift) -> String {
        gift.guestID.map(store.guestName) ?? "A guest"
    }
}

// MARK: - CR2 · Gift advisor

struct GiftAdvisorView: View {
    @Environment(AppStore.self) private var store
    /// Opens the add-a-gift sheet with this price filled in.
    var addGift: (Int) -> Void

    private struct Band {
        let label: String
        let range: ClosedRange<Int>
        let share: ClosedRange<Double>
        let samplePrice: Int
    }

    /// Roughly one gift for every guest and a bit, most of them in the middle.
    private let bands = [
        Band(label: "Under $50", range: 0...49, share: 0.28...0.32, samplePrice: 40),
        Band(label: "$50–$150", range: 50...150, share: 0.36...0.40, samplePrice: 100),
        Band(label: "Over $150", range: 151...Int.max, share: 0.08...0.12, samplePrice: 250),
    ]

    private var guestCount: Int { max(store.totalInvitedPeople, store.wedding.expectedGuests ?? 0) }

    private func have(_ band: Band) -> Int {
        store.registryGifts.filter { band.range.contains($0.price) }.count
    }

    private func suggested(_ band: Band) -> ClosedRange<Int> {
        let n = Double(guestCount)
        let low = Int((n * band.share.lowerBound).rounded()), high = Int((n * band.share.upperBound).rounded())
        return max(1, low)...max(1, high)
    }

    /// The band furthest below its suggestion, compared by share.
    private var shortest: Band? {
        bands.filter { have($0) < suggested($0).lowerBound }
            .min { Double(have($0)) / Double(suggested($0).lowerBound) < Double(have($1)) / Double(suggested($1).lowerBound) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                ScreenHeader(title: "Gift advisor",
                             subtitle: guestCount > 0 ? "Price ranges based on your \(guestCount) guests" : "Add guests to get price ranges")
                Panel {
                    Text("Suggested mix")
                        .font(Typo.title3)
                        .foregroundStyle(Palette.textPrimary)
                    ForEach(bands, id: \.label) { band in
                        let range = suggested(band)
                        HStack {
                            Text(band.label)
                            Spacer()
                            Text("\(range.lowerBound)–\(range.upperBound) gifts")
                                .foregroundStyle(Palette.textSecondary)
                        }
                        .font(Typo.body)
                        .foregroundStyle(Palette.textPrimary)
                        .padding(.vertical, 2)
                        .accessibilityElement(children: .combine)
                    }
                }
                if let band = shortest {
                    let count = have(band)
                    Panel(background: Palette.bgAccentSubtle, bordered: false) {
                        Text("You have \(count) \(count == 1 ? "gift" : "gifts") \(band.label.lowercased()). Add more so every guest has an option in their budget.")
                            .font(Typo.subheadline)
                            .foregroundStyle(Palette.textPrimary)
                    }
                    Button("Add gifts \(band.label.lowercased())") { addGift(band.samplePrice) }
                        .buttonStyle(.primary)
                } else if guestCount > 0 {
                    Panel(background: Palette.bgSuccess, bordered: false) {
                        Text("Nice mix. Every guest can find something in their budget.")
                            .font(Typo.subheadline)
                            .foregroundStyle(Palette.textSuccess)
                    }
                }
            }
            .screenStyle()
        }
        .background(Palette.bgCanvas)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - CR3 · Link a registry

struct LinkRegistryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.openURL) private var openURL
    @State private var address = ""
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                ScreenHeader(title: "Link a registry",
                             subtitle: "Guests see gifts from other stores next to your Intertwine registry.")
                LabeledField(label: "Registry link", text: $address, placeholder: "https://",
                             helper: "Paste the public link to your registry", error: error)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: address) { error = nil }

                if !store.registryLinks.isEmpty {
                    VStack(alignment: .leading, spacing: Space.xs) {
                        SectionTitle("Linked")
                        RowGroup {
                            ForEach(Array(store.registryLinks.enumerated()), id: \.element.id) { index, link in
                                if index > 0 { RowDivider() }
                                Button {
                                    if let url = URL(string: link.url) { openURL(url) }
                                } label: {
                                    ListRow(title: link.name, subtitle: "Opens the store’s website")
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Remove link", systemImage: "trash", role: .destructive) {
                                        store.deleteRegistryLink(link.id)
                                    }
                                }
                            }
                        }
                        Text("Touch and hold a link to remove it.")
                            .font(Typo.footnote)
                            .foregroundStyle(Palette.textTertiary)
                    }
                }
            }
            .screenStyle()
        }
        .background(Palette.bgCanvas)
        .navigationBarTitleDisplayMode(.inline)
        .pinnedFooter {
            Button("Link registry") {
                if store.addRegistryLink(address) {
                    address = ""
                } else {
                    error = "That doesn’t look like a web address. It should start with https://"
                }
            }
            .buttonStyle(.primary)
            .disabled(address.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}

// MARK: - CR4 · Track gifts

struct GiftsBoughtView: View {
    @Environment(AppStore.self) private var store
    @State private var onlyDue = false

    /// Gifts from guests, plus ones the couple marked bought themselves.
    private struct Entry: Identifiable {
        let id: UUID
        let gift: RegistryGift?
        let item: RegistryItem
    }

    private var entries: [Entry] {
        let fromGuests = store.gifts.compactMap { gift -> Entry? in
            guard let item = store.data.registry.first(where: { $0.id == gift.itemID }) else { return nil }
            return Entry(id: gift.id, gift: gift, item: item)
        }
        .sorted { ($0.gift?.givenAt ?? .distantPast) > ($1.gift?.givenAt ?? .distantPast) }
        let markedByCouple = store.registryGifts
            .filter { $0.purchased && store.gifts(for: $0).isEmpty }
            .map { Entry(id: $0.id, gift: nil, item: $0) }
        let all = fromGuests + markedByCouple
        return onlyDue ? all.filter { $0.gift != nil && $0.gift?.thankYouSent == false } : all
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                ScreenHeader(title: "Gifts bought",
                             subtitle: "\(store.takenGiftCount) of \(store.registryGifts.count) gifts · \(Format.price(store.fundsRaised)) in cash funds")
                Picker("Show", selection: $onlyDue) {
                    Text("All gifts").tag(false)
                    Text("Thank-yous to send").tag(true)
                }
                .pickerStyle(.segmented)

                if entries.isEmpty {
                    Text(onlyDue ? "You’re all caught up on thank-you notes." : "When guests choose gifts on your website, they’ll show up here.")
                        .font(Typo.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                } else {
                    RowGroup {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            if index > 0 { RowDivider() }
                            row(entry)
                        }
                    }
                    if entries.contains(where: { $0.gift != nil }) {
                        Text("Tap a gift to mark its thank-you note as sent.")
                            .font(Typo.footnote)
                            .foregroundStyle(Palette.textTertiary)
                    }
                }
            }
            .screenStyle()
        }
        .refreshable { await store.sync() }
        .background(Palette.bgCanvas)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func row(_ entry: Entry) -> some View {
        let title = entry.item.isFund ? "\(entry.item.name) · \(Format.price(entry.gift?.amount ?? 0))" : entry.item.name
        if let gift = entry.gift {
            let from = gift.guestID.map(store.guestName) ?? "A guest"
            Button {
                store.setThankYouSent(gift.id, !gift.thankYouSent)
            } label: {
                HStack(spacing: 0) {
                    ListRow(title: title,
                            subtitle: "From \(from) · \(Format.dayShort(gift.givenAt)) · \(gift.thankYouSent ? "Thank-you sent" : "Thank-you due")"
                                + (gift.note.isEmpty ? "" : "\n“\(gift.note)”"),
                            showsChevron: false)
                    Image(systemName: gift.thankYouSent ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(gift.thankYouSent ? Palette.textSuccess : Palette.iconInactive)
                        .padding(.trailing, Space.md)
                }
            }
            .buttonStyle(.plain)
            .accessibilityValue(gift.thankYouSent ? "Thank-you sent" : "Thank-you due")
            .accessibilityHint("Marks the thank-you note as sent or not sent")
        } else {
            ListRow(title: title, subtitle: "Marked bought by you", showsChevron: false)
        }
    }
}
