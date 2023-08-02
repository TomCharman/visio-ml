import Foundation
import CoreGraphics

struct Annotation {

  private enum CodingKeys: String, CodingKey {
    case label
    case coordinates
  }

  private struct JsonCoordinates: Codable {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    
    var asCgRect: CGRect {
      CGRect(x: x, y: y, width: width, height: height)
    }
  }

  var id: UUID = UUID()
  var label: String
  var coordinates: CGRect // Top-Left Origin. Centered.

  var isSelected = false
  var isMoving = false

  var origin: CGPoint {
    coordinates.origin
  }
  
  var size: CGSize {
    coordinates.size
  }

  var width: CGFloat {
    size.width
  }

  var height: CGFloat {
    size.height
  }

  private var jsonCoordinates: JsonCoordinates {
    JsonCoordinates(x: origin.x, y: origin.y, width: width, height: height)
  }
}

extension Annotation: Identifiable {

}

extension Annotation: Codable {

  // Decodable
  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    label = try values.decode(String.self, forKey: .label)
    let jsonCoordinates = try values.decode(JsonCoordinates.self, forKey: .coordinates)
    coordinates = jsonCoordinates.asCgRect
  }

  // Encodable
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(label, forKey: .label)
    try container.encode(jsonCoordinates, forKey: .coordinates)
  }
}

extension Array where Element == Annotation {

  var hasSelected: Bool {
    firstIndex { $0.isSelected } != nil
  }

  var selectedIndex: Int {
    firstIndex { $0.isSelected }!
  }

  mutating func removeSelectedAnnotation() {
    guard
      let i = firstIndex(where: { $0.isSelected } )
    else {
      return
    }
    self.remove(at: i)
  }
}
