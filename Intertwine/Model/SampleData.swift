import Foundation

/// Mia & Ryan's wedding, matching the Figma screens. Used on first launch and by "Reset demo".
enum SampleData {
    static func make() -> AppData {
        let rosa = Guest(name: "Rosa", partySize: 1)
        var guests = [rosa]
        let names = ["Amy Adams", "Elizabeth Atkinson", "John Atwood", "Jessica Avery", "Christopher Bailey",
                     "Joseph Baker", "James Bennett", "Megan Berry", "Hannah Blair", "Patricia Brooks",
                     "Sarah Brown", "Laura Bryant", "Edward Burton"]
        for (index, name) in names.enumerated() {
            guests.append(Guest(name: name, partySize: index % 3 == 0 ? 2 : 1))
        }

        let engagement = WeddingEvent(
            type: "Engagement Party", name: "Engagement Party",
            welcomeMessage: "Come celebrate with us!",
            day: date(2026, 11, 14), startTime: time(19, 0), endTime: time(22, 0),
            venue: "Harbor View Terrace", directions: "Take the elevator to the rooftop.",
            dressCode: "Smart casual", dressGuidance: "Whatever makes you feel good — it’s a party.",
            rsvpRequired: true, rsvpDeadline: date(2026, 11, 1), status: .published)

        let shower = WeddingEvent(
            type: "Bridal Shower", name: "Bridal Shower",
            welcomeMessage: "An afternoon of tea and games for Mia.",
            day: date(2027, 7, 18), startTime: time(13, 0), endTime: time(16, 0),
            venue: "Rosa’s house", directions: "Park on the street; the gate is on the left.",
            dressCode: "Garden party", dressGuidance: "Light colors and flat shoes — we’ll be on the lawn.",
            rsvpRequired: true, rsvpDeadline: date(2027, 7, 1), status: .published)

        let welcome = WeddingEvent(
            type: "Welcome Party", name: "Welcome Party",
            welcomeMessage: "Join us for drinks before the big day.",
            day: date(2027, 9, 25), startTime: time(18, 0), endTime: time(20, 0),
            venue: "Seaport Hotel", directions: "Use the main entrance and follow the Welcome Party signs.",
            dressCode: "Cocktail attire", dressGuidance: "Dresses or suits; comfortable shoes welcome.",
            rsvpRequired: true, rsvpDeadline: date(2027, 9, 10), status: .published)

        let rehearsal = WeddingEvent(
            type: "Rehearsal Dinner", name: "Rehearsal Dinner",
            welcomeMessage: "", day: date(2027, 9, 24), startTime: time(18, 0), endTime: time(21, 0),
            venue: "", dressCode: "Smart casual", status: .draft)

        let weddingDay = WeddingEvent(
            type: "Ceremony & Reception", name: "Wedding Day",
            welcomeMessage: "We can’t wait to celebrate with you.",
            day: date(2027, 9, 26), venue: "Seaport Hotel",
            dressCode: "Black tie optional", status: .draft)

        var rsvps: [RSVP] = []
        for (index, guest) in guests.enumerated() where guest.id != rosa.id {
            rsvps.append(RSVP(eventID: engagement.id, guestID: guest.id, attending: index % 5 != 0,
                              partyCount: guest.partySize, note: ""))
            if index % 2 == 0 {
                rsvps.append(RSVP(eventID: shower.id, guestID: guest.id, attending: true, partyCount: 1, note: ""))
            }
        }
        rsvps.append(RSVP(eventID: engagement.id, guestID: rosa.id, attending: true, partyCount: 1, note: ""))
        rsvps.append(RSVP(eventID: shower.id, guestID: rosa.id, attending: true, partyCount: 1, note: "I’ll bring dessert!"))

        return AppData(
            wedding: Wedding(
                coupleNames: "Mia & Ryan",
                date: date(2027, 9, 26),
                venue: "Seaport Hotel",
                hotelInfo: "We have a room block at the Seaport Hotel until Aug 25. Mention “Mia & Ryan” when you book.",
                parkingInfo: "Valet parking at the main entrance, or the Seaport garage across the street."),
            events: [engagement, shower, welcome, rehearsal, weddingDay],
            guests: guests,
            rsvps: rsvps,
            questions: [
                GuestQuestion(guestID: guests[2].id, eventID: welcome.id, text: "Is there parking at the hotel?"),
                GuestQuestion(guestID: guests[5].id, eventID: nil, text: "Can I bring my kids?"),
            ],
            updates: [
                WeddingUpdate(title: "Welcome Party added", detail: "Drinks the night before · Sep 25"),
                WeddingUpdate(title: "Hotel block closes Aug 25", detail: "Mention “Mia & Ryan” when you book"),
            ],
            registry: [
                RegistryItem(name: "Linen napkin set", price: 45),
                RegistryItem(name: "Dutch oven", price: 120, purchased: true),
                RegistryItem(name: "Honeymoon fund", price: 25),
                RegistryItem(name: "Stand mixer", price: 380),
            ],
            currentGuestID: rosa.id)
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }

    private static func time(_ hour: Int, _ minute: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1, hour: hour, minute: minute)) ?? Date()
    }
}
