import Foundation
import SwiftUI

struct ShowIfEquals: Decodable {
    let id: String
    let value: Int
}

struct UIConfigItem: Decodable, Identifiable {
    let id: String
    let type: String        // "toggle" | "slider" | "segment" | "colorPicker"
    let label: String
    let icon: String        // SF Symbol
    let color: String       // hex without #
    let showIf: String?     // id of toggle that controls visibility
    let showIfVal: String?  // expected value ("true"/"false")
    let showIfEquals: ShowIfEquals?  // segment parent must equal this value
    let min: Double?
    let max: Double?
    let step: Double?
    let unit: String?
    let options: [String]?

    var accentColor: Color {
        Color(hex: color) ?? Color(red: 1, green: 0.18, blue: 0.38)
    }

    private enum CodingKeys: String, CodingKey {
        case id, type, label, icon, min, max, step, unit, options
        case color = "colorHex"
        case showIf, showIfVal, showIfEquals
    }
}

struct UIConfigSection: Decodable, Identifiable {
    let id: String
    let title: String
    let icon: String
    let color: String
    let items: [UIConfigItem]

    var accentColor: Color {
        Color(hex: color) ?? Color(red: 1, green: 0.18, blue: 0.38)
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, icon, items
        case color = "colorHex"
    }
}

private struct TabContainer: Decodable {
    let sections: [UIConfigSection]
}

private struct AntiBanConfig: Decodable {
    let visible: Bool?
}

struct UIConfig: Decodable {
    let esp: [UIConfigSection]
    let misc: [UIConfigSection]
    let antiBanVisible: Bool

    var isEmpty: Bool { esp.isEmpty && misc.isEmpty }

    static let empty = UIConfig(esp: [], misc: [], antiBanVisible: true)

    private enum CodingKeys: String, CodingKey {
        case espAim = "esp_aim"
        case misc
        case antiban
    }

    init(esp: [UIConfigSection], misc: [UIConfigSection], antiBanVisible: Bool = true) {
        self.esp = esp
        self.misc = misc
        self.antiBanVisible = antiBanVisible
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let espTab = try container.decodeIfPresent(TabContainer.self, forKey: .espAim)
        let miscTab = try container.decodeIfPresent(TabContainer.self, forKey: .misc)
        let abCfg = try container.decodeIfPresent(AntiBanConfig.self, forKey: .antiban)
        self.esp = espTab?.sections ?? []
        self.misc = miscTab?.sections ?? []
        self.antiBanVisible = abCfg?.visible ?? true
    }
}
