import SwiftUI

/// Brand assets carried over from the original design (Figma page "Site Map · Brand pass"):
/// the script monogram and the sample event and couple photos.
/// They live in Assets.xcassets/Brand.
enum Brand {
    static let couplePhoto = "Couple"

    /// Sample photo for a demo event, matched by its name or type. Nil when there isn't one.
    static func photo(for event: String) -> String? {
        switch event {
        case "Engagement Party": "EventEngagementParty"
        case "Bridal Shower": "EventBridalShower"
        case "Rehearsal Dinner": "EventRehearsalDinner"
        case "Welcome Party": "EventWelcomeParty"
        case "Wedding Day", "Ceremony & Reception": "EventWeddingDay"
        case "Farewell Brunch": "EventFarewellBrunch"
        default: nil
        }
    }
}

extension WeddingEvent {
    /// The photo the couple picked, or else the demo event's sample photo.
    var coverPhoto: Image? {
        if let photoFileName, let picked = PhotoStore.image(named: photoFileName) {
            return Image(uiImage: picked)
        }
        return samplePhoto.map { Image($0) }
    }
}

extension Wedding {
    /// The couple's own photo, or else the demo couple's.
    var photo: Image? {
        if let couplePhotoFileName, let picked = PhotoStore.image(named: couplePhotoFileName) {
            return Image(uiImage: picked)
        }
        return couplePhoto.map { Image($0) }
    }
}

/// The script monogram. Drawn as a template so it takes the accent color:
/// slate in Light mode, mist blue in Dark mode.
struct Monogram: View {
    var width: CGFloat = 240

    var body: some View {
        Image("Monogram")
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .frame(width: width)
            .foregroundStyle(Palette.bgAccent)
            .accessibilityLabel("Intertwine")
    }
}

/// The monogram centered on the screen background (Figma: O1 · Welcome cover).
struct MonogramCover: View {
    var height: CGFloat = 280

    var body: some View {
        Monogram(width: 240)
            .frame(maxWidth: .infinity)
            .frame(height: height)
    }
}

/// Countdown on the couple's Home, over their photo (Figma: O7 · Home "Countdown").
struct CountdownTile: View {
    let days: Int
    let photo: Image

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Spacer(minLength: 0)
            Text("\(days)")
                .font(Typo.largeTitle)
            Text("days until “I do”")
                .font(Typo.footnote)
        }
        // Fixed ivory (Figma: ivory/100) so the text reads on the photo in both modes.
        .foregroundStyle(Color(red: 1, green: 0.992, blue: 0.984))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(Space.md)
        .background {
            photo
                .resizable()
                .scaledToFill()
                .overlay {
                    LinearGradient(stops: [.init(color: .clear, location: 0.35),
                                           .init(color: Color(red: 0.09, green: 0.12, blue: 0.14).opacity(0.78), location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(days) days until the wedding")
    }
}
