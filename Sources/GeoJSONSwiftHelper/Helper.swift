import Foundation
import Turf

public struct Helper {
  public static func getPolygons(from geometry: Turf.Geometry) -> [Turf.Polygon] {
    switch geometry {
    case .point, .lineString, .multiPoint, .multiLineString:
      return []
    case .polygon(let polygon):
      return [polygon]
    case .multiPolygon(let multiPolygon):
      return multiPolygon.polygons
    case .geometryCollection(let geometryCollection):
      return geometryCollection.geometries.flatMap { getPolygons(from: $0 )}
    }
  }
}
