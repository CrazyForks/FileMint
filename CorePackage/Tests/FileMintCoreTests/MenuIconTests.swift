import Foundation
import Testing
@testable import FileMintCore

struct MenuIconTests {
    private func icon(_ symbol: String = "folder") throws -> MenuIconCustomization {
        try #require(MenuIconCustomization(symbolName: symbol, primaryHex: "#12ab34", secondaryHex: "EF9012"))
    }

    @Test func symbolAndColorsRoundTripWithPreferencesAndTemplate() throws {
        var preferences = FileMintPreferences.default
        let choice = try icon()
        preferences.menuIcons[MenuIconSlot.fileTools.rawValue] = choice
        preferences.templates[0].customMenuIcon = try icon("doc.text")

        let restored = try FileMintPreferencesStore.decode(JSONEncoder().encode(preferences))
        #expect(restored.menuIcons[MenuIconSlot.fileTools.rawValue] == choice)
        #expect(restored.templates[0].customMenuIcon?.symbolName == "doc.text")
        #expect(restored.templates[0].customMenuIcon?.primaryHex == "#12AB34")
        #expect(restored.templates[0].customMenuIcon?.secondaryHex == "#EF9012")
    }

    @Test func legacyAndMalformedIconsKeepOtherSettings() throws {
        var preferences = FileMintPreferences.default
        preferences.language = .chinese
        preferences.launchAtLogin = false
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(preferences)) as? [String: Any])
        object.removeValue(forKey: "menuIcons")
        var templates = try #require(object["templates"] as? [[String: Any]])
        templates[0].removeValue(forKey: "customMenuIcon")
        object["templates"] = templates
        let legacy = try FileMintPreferencesStore.decode(JSONSerialization.data(withJSONObject: object))
        #expect(legacy.menuIcons.isEmpty && legacy.templates[0].customMenuIcon == nil)
        #expect(legacy.language == .chinese && !legacy.launchAtLogin)

        object["menuIcons"] = ["fileTools": ["symbolName": "not a symbol", "primaryHex": "bad", "secondaryHex": "#FFFFFF"]]
        templates[0]["customMenuIcon"] = ["symbolName": "bad/name", "primaryHex": "#000000", "secondaryHex": "#FFFFFF"]
        object["templates"] = templates
        let malformed = try FileMintPreferencesStore.decode(JSONSerialization.data(withJSONObject: object))
        #expect(malformed.menuIcons.isEmpty && malformed.templates[0].customMenuIcon == nil)
        #expect(malformed.language == .chinese && !malformed.launchAtLogin)
    }

    @Test func editedTemplateKeepsIconAndRestorationResetsBuiltIns() throws {
        var original = try #require(TemplateCatalog.builtInTemplates.first { $0.id == "plain-text" })
        original.customMenuIcon = try icon("star")
        let edited = try TemplateCatalog.customTemplate(name: "Notes", fileExtension: "md", content: "",
            id: original.id, in: [original], suggestedFileName: "Notes.md")
        #expect(edited.customMenuIcon == original.customMenuIcon)
        #expect(TemplateCatalog.defaultMenuSymbol(forSuffix: edited.fileExtension) == "doc.richtext")
        let restored = TemplateCatalog.restoringBuiltIns(in: [edited])
        #expect(restored.first { $0.id == original.id }?.customMenuIcon == nil)
        #expect(TemplateCatalog.defaultMenuSymbol(forSuffix: "unknown") == "doc")
    }

    @Test func onlyExpectedMenuSlotsAreSaved() throws {
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(FileMintPreferences.default)) as? [String: Any])
        let value = ["symbolName": "star", "primaryHex": "#000000", "secondaryHex": "#FFFFFF"]
        object["menuIcons"] = ["favoriteLocations": value, "unknownSlot": value]
        let preferences = try FileMintPreferencesStore.decode(JSONSerialization.data(withJSONObject: object))
        #expect(preferences.menuIcons.count == 1)
        #expect(preferences.menuIcons[MenuIconSlot.favoriteLocations.rawValue]?.symbolName == "star")
    }
}
