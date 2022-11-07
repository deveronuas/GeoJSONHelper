import Foundation
import CoreLocation
import Turf
import MapKit

class BoundaryPolygon: MKPolygon {}

extension GeoJSONObject {
  static func create(from geoJSONString: String) -> GeoJSONObject? {
    guard let data = geoJSONString.data(using: .utf8) else { return nil }

    do {
      return try JSONDecoder().decode(GeoJSONObject.self, from: data)
    } catch {
      print("Error while decoding geoJSONObject...")
      print(String(describing: error))
    }

    return nil
  }

  var coordinates: [CLLocationCoordinate2D] {
    switch self {
    case .geometry(let geometry):
      return getCoordinates(from: geometry)
    case .feature(let feature):
      return getCoordinates(from: feature.geometry!)
    case .featureCollection(let featureCollection):
      return featureCollection.features.flatMap { getCoordinates(from: $0.geometry!) }
    }
  }

  private func getCoordinates(from geometry: Turf.Geometry) -> [CLLocationCoordinate2D] {
    switch geometry {
    case .point(let point):
      return [point.coordinates]
    case .lineString(let lineString):
      return lineString.coordinates
    case .polygon(let polygon):
      return polygon.coordinates.flatMap {$0}
    case .multiPoint(let multiPoint):
      return multiPoint.coordinates
    case .multiLineString(let multiLineString):
      return multiLineString.coordinates.flatMap {$0}
    case .multiPolygon(let multiPolygon):
      return multiPolygon.coordinates.flatMap {$0}.flatMap {$0}
    case .geometryCollection(let geometryCollection):
      return geometryCollection.geometries.flatMap { getCoordinates(from: $0 )}
    }
  }

  var polygons: [Turf.Polygon] {
    switch self {
    case .geometry(let geometry):
      return getPolygons(from: geometry)
    case .feature(let feature):
      return getPolygons(from: feature.geometry!)
    case .featureCollection(let featureCollection):
      return featureCollection.features.flatMap { getPolygons(from: $0.geometry!) }
    }
  }

  private func getPolygons(from geometry: Turf.Geometry) -> [Turf.Polygon] {
    switch geometry {
    case .point(_):
      return []
    case .lineString(_):
      return []
    case .polygon(let polygon):
      return [polygon]
    case .multiPoint(_):
      return []
    case .multiLineString(_):
      return []
    case .multiPolygon(let multiPolygon):
      return multiPolygon.polygons
    case .geometryCollection(let geometryCollection):
      return geometryCollection.geometries.flatMap { getPolygons(from: $0 )}
    }
  }

  var center: CLLocationCoordinate2D {
    var maxLatitude: Double = -200
    var maxLongitude: Double = -200
    var minLatitude: Double = Double(MAXFLOAT)
    var minLongitude: Double = Double(MAXFLOAT)

    for location in self.coordinates {
      if location.latitude < minLatitude {
        minLatitude = location.latitude
      }

      if location.longitude < minLongitude {
        minLongitude = location.longitude
      }

      if location.latitude > maxLatitude {
        maxLatitude = location.latitude
      }

      if location.longitude > maxLongitude {
        maxLongitude = location.longitude
      }
    }

    return CLLocationCoordinate2DMake(
      CLLocationDegrees((maxLatitude + minLatitude) * 0.5),
      CLLocationDegrees((maxLongitude + minLongitude) * 0.5))
  }

  var bounds: CoordinateBounds {
    var maxN = CLLocationDegrees(), maxS = CLLocationDegrees(), maxE = CLLocationDegrees(), maxW = CLLocationDegrees()
    for coordinate in coordinates {
      if coordinate.latitude >= maxN || maxN == 0 { maxN = coordinate.latitude }
      if coordinate.latitude <= maxS || maxS == 0 { maxS = coordinate.latitude }
      if coordinate.longitude >= maxE || maxE == 0 { maxE = coordinate.longitude }
      if coordinate.longitude <= maxW || maxW == 0 { maxW = coordinate.longitude }
    }

    let offset = 0.001
    let maxNE = CLLocationCoordinate2D(latitude: maxN + offset, longitude: maxE + offset)
    let maxSW =  CLLocationCoordinate2D(latitude: maxS - offset, longitude: maxW - offset)
    let bounds = CoordinateBounds(southwest: maxSW, northeast: maxNE)
    return bounds
  }

  var region: MKCoordinateRegion? {
    return MKCoordinateRegion(coordinates: [bounds.northwest, bounds.southeast])
    // This is too snug
    // return MKCoordinateRegion(coordinates: coordinates)
  }

  var mapPolygons: [BoundaryPolygon]? {
    return overlays.filter { overlay in
      overlay is BoundaryPolygon
    } as? [BoundaryPolygon]
  }

  var overlays: [MKOverlay] {
    switch self {
    case .geometry(let geometry):
      return getOverlays(from: geometry)
    case .feature(let feature):
      return getOverlays(from: feature.geometry!)
    case .featureCollection(let featureCollection):
      return featureCollection.features.flatMap { getOverlays(from: $0.geometry!) }
    }
  }

  private func getOverlays(from geometry: Turf.Geometry) -> [MKOverlay] {
    switch geometry {
    case .point(let point):
      return [MKCircle(center: point.coordinates,
                       radius: 1.0)]
    case .lineString(let lineString):
      return [MKPolyline(coordinates: lineString.coordinates,
                         count: lineString.coordinates.count)]
    case .polygon(let polygon):
      return [
        BoundaryPolygon(coordinates:
                          polygon.coordinates.flatMap { $0 },
                        count:
                          polygon.coordinates.flatMap { $0 }.count)
      ]
    case .multiPoint(let multiPoint):
      return multiPoint.coordinates.map { MKCircle(center: $0,
                                                   radius: 1.0) }
    case .multiLineString(let multiLineString):
      return multiLineString
        .coordinates
        .flatMap {[
          MKPolyline(coordinates: $0,
                     count: $0.count)
        ]}
    case .multiPolygon(let multiPolygon):
      return multiPolygon
        .coordinates
        .flatMap { $0 }
        .flatMap { [
          BoundaryPolygon(coordinates: $0,
                          count: $0.count)
        ] }
    case .geometryCollection(let geometryCollection):
      return geometryCollection.geometries.flatMap { getOverlays(from: $0.geometry)}
    }
  }

  var sourceData: GeoJSONSourceData {
    switch self {
    case .geometry(let geometry):
      return .geometry(geometry)
    case .feature(let feature):
      return .feature(feature)
    case .featureCollection(let featureCollection):
      return .featureCollection(featureCollection)
    }
  }
}

struct CoordinateBounds {
  let southwest: CLLocationCoordinate2D
  let northeast: CLLocationCoordinate2D

  var southeast: CLLocationCoordinate2D {
    return CLLocationCoordinate2D(latitude: southwest.latitude, longitude: northeast.longitude)
  }
  var northwest: CLLocationCoordinate2D {
    return CLLocationCoordinate2D(latitude: northeast.latitude, longitude: southwest.longitude)
  }
}

/// Captures potential values of the `data` property of a GeoJSONSource
public enum GeoJSONSourceData: Codable {
  /// The `data` property can be a url
  case url(URL)

  /// The `data` property can be a feature
  case feature(Feature)

  /// The `data` property can be a feature collection
  case featureCollection(FeatureCollection)

  /// The `data` property can be a geometry with no associated properties.
  case geometry(Geometry)

  /// Empty data to be used for initialization
  case empty

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()

    if let decodedURL = try? container.decode(URL.self) {
      self = .url(decodedURL)
      return
    }

    if let decodedFeature = try? container.decode(Feature.self) {
      self = .feature(decodedFeature)
      return
    }

    if let decodedFeatureCollection = try? container.decode(FeatureCollection.self) {
      self = .featureCollection(decodedFeatureCollection)
      return
    }

    if let decodedString = try? container.decode(String.self), decodedString.isEmpty {
      self = .empty
      return
    }

    let context = DecodingError.Context(codingPath: decoder.codingPath,
                                        debugDescription: "Failed to decode GeoJSONSource `data` property")
    throw DecodingError.dataCorrupted(context)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()

    switch self {
    case .url(let url):
      try container.encode(url)
    case .feature(let feature):
      try container.encode(feature)
    case .featureCollection(let featureCollection):
      try container.encode(featureCollection)
    case .geometry(let geometry):
      try container.encode(geometry)
    case .empty:
      try container.encode("")
    }
  }
}

extension GeoJSONSourceData: Equatable {
  public static func == (lhs: GeoJSONSourceData, rhs: GeoJSONSourceData) -> Bool {
    switch (lhs, rhs) {
    case (let .url(lhsURL), let .url(rhsURL)):
      return lhsURL == rhsURL
    case (let .feature(lhsFeature), let .feature(rhsFeature)):
      return lhsFeature == rhsFeature
    default:
      return false
    }
  }
}

extension MKCoordinateRegion {
  init?(coordinates: [CLLocationCoordinate2D]) {
    // first create a region centered around the prime meridian
    let primeRegion = MKCoordinateRegion.region(for: coordinates, transform: { $0 }, inverseTransform: { $0 })

    // next create a region centered around the 180th meridian
    let transformedRegion = MKCoordinateRegion.region(for: coordinates, transform: MKCoordinateRegion.transform, inverseTransform: MKCoordinateRegion.inverseTransform)

    // return the region that has the smallest longitude delta
    if let a = primeRegion, let b = transformedRegion,
       let min = [a, b].min(by: { $0.span.longitudeDelta < $1.span.longitudeDelta }) {
      self = min
    } else if let a = primeRegion {
      self = a
    } else if let b = transformedRegion {
      self = b
    } else {
      return nil
    }
  }

  // Latitude -180...180 -> 0...360
  private static func transform(c: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
    if c.longitude < 0 { return CLLocationCoordinate2DMake(c.latitude, 360 + c.longitude) }
    return c
  }

  // Latitude 0...360 -> -180...180
  private static func inverseTransform(c: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
    if c.longitude > 180 { return CLLocationCoordinate2DMake(c.latitude, -360 + c.longitude) }
    return c
  }

  private typealias Transform = (CLLocationCoordinate2D) -> (CLLocationCoordinate2D)

  private static func region(for coordinates: [CLLocationCoordinate2D], transform: Transform, inverseTransform: Transform) -> MKCoordinateRegion? {
    // handle empty array
    guard !coordinates.isEmpty else { return nil }

    // handle single coordinate
    guard coordinates.count > 1 else {
      return MKCoordinateRegion(center: coordinates[0], span: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1))
    }

    let transformed = coordinates.map(transform)

    // find the span
    let minLat = transformed.min { $0.latitude < $1.latitude }!.latitude
    let maxLat = transformed.max { $0.latitude < $1.latitude }!.latitude
    let minLon = transformed.min { $0.longitude < $1.longitude }!.longitude
    let maxLon = transformed.max { $0.longitude < $1.longitude }!.longitude
    let span = MKCoordinateSpan(latitudeDelta: maxLat - minLat, longitudeDelta: maxLon - minLon)

    // find the center of the span
    let center = inverseTransform(CLLocationCoordinate2DMake((maxLat - span.latitudeDelta / 2), maxLon - span.longitudeDelta / 2))

    return MKCoordinateRegion(center: center, span: span)
  }
}

extension CLLocationCoordinate2D {
  func distance(from otherCoordinate: CLLocationCoordinate2D) -> Double {
    let myLoc = CLLocation(latitude: self.latitude, longitude: self.longitude)
    let otherLoc = CLLocation(latitude: otherCoordinate.latitude, longitude: otherCoordinate.longitude)

    return myLoc.distance(from: otherLoc)
  }
}
