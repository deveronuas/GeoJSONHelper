import Foundation
import MapKit
import Turf
import GEOSwift


public struct GridHelper {
  public enum gridPolygonStatus {
    case pending, skipped, done
  }
  typealias LineCoordinates = (start: CLLocationCoordinate2D, end: CLLocationCoordinate2D)

  /// This method will calculate the horizontal and verticle grid lines from the overlay's center to the overlay's bound with the provided rotation and offset.
  /// - Parameters:
  ///     - bounds: The overlay's bounding rectangle.
  ///     - center: The overlay's center.
  ///     - rotation: Rotaion should be in degrees and it rotates the grid line as per the provided rotation.
  ///     - offset: Offset should be in SizeInMeters and it moves the grid line as per the provided offset.
  ///     - gridCellSize: GridCellSize should be in meters and it is the distance between two grid line.
  /// - Returns: The array of GridLineOverlay.
  public static func calcGridLines(bounds: CoordinateBounds,
                                   center: CLLocationCoordinate2D,
                                   rotation: Double,
                                   offset: SizeInMeters,
                                   gridCellSize: Double) -> [GridLineOverlay] {
    var hLines : [GridLineOverlay] = []
    var vLines : [GridLineOverlay] = []

    let origin = center.movedBy(latitudinalMeters: offset.height, longitudinalMeters: offset.width)
    let gridSize = bounds.northwest.distance(from: bounds.southeast)
    var numOfLines = Int(ceil(gridSize / gridCellSize))
    numOfLines = numOfLines % 2 == 0 ? numOfLines : numOfLines + 1
    let lineLength = Double(numOfLines) * gridCellSize

    let rotationRadians = (rotation * Double.pi / 180)
    let vLineMvmtDirection = (Double.pi / 2.0) + rotationRadians
    let hLineMvmtDirection = (Double.pi) + rotationRadians

    let originVLineStart = origin.movedBy(distanceMeters: -lineLength / 2.0, bearingRadians: hLineMvmtDirection)
    let originVLineEnd = origin.movedBy(distanceMeters: lineLength / 2.0, bearingRadians: hLineMvmtDirection)

    let originHLineStart = origin.movedBy(distanceMeters: -lineLength / 2.0, bearingRadians: vLineMvmtDirection)
    let originHLineEnd = origin.movedBy(distanceMeters: lineLength / 2.0, bearingRadians: vLineMvmtDirection)

    // Origin Lines
    vLines.append(GridLineOverlay(coordinates: [originVLineStart, originVLineEnd], count: 2))
    hLines.append(GridLineOverlay(coordinates: [originHLineStart, originHLineEnd], count: 2))

    // Fill the bounds
    for num in 1...Int(numOfLines / 2) {
      let mvmt = gridCellSize * Double(num)

      // Vertical lines
      let vNegLineStart = originVLineStart.movedBy(distanceMeters: -mvmt, bearingRadians: vLineMvmtDirection)
      let vNegLineEnd = originVLineEnd.movedBy(distanceMeters: -mvmt, bearingRadians: vLineMvmtDirection)

      let vPosLineStart = originVLineStart.movedBy(distanceMeters: mvmt, bearingRadians: vLineMvmtDirection)
      let vPosLineEnd = originVLineEnd.movedBy(distanceMeters: mvmt, bearingRadians: vLineMvmtDirection)

      vLines.append(GridLineOverlay(coordinates: [vNegLineStart, vNegLineEnd], count: 2))
      vLines.append(GridLineOverlay(coordinates: [vPosLineStart, vPosLineEnd], count: 2))

      // Horizontal lines
      let hNegLineStart = originHLineStart.movedBy(distanceMeters: -mvmt, bearingRadians: hLineMvmtDirection)
      let hNegLineEnd = originHLineEnd.movedBy(distanceMeters: -mvmt, bearingRadians: hLineMvmtDirection)

      let hPosLineStart = originHLineStart.movedBy(distanceMeters: mvmt, bearingRadians: hLineMvmtDirection)
      let hPosLineEnd = originHLineEnd.movedBy(distanceMeters: mvmt, bearingRadians: hLineMvmtDirection)

      hLines.append(GridLineOverlay(coordinates: [hNegLineStart, hNegLineEnd], count: 2))
      hLines.append(GridLineOverlay(coordinates: [hPosLineStart, hPosLineEnd], count: 2))
    }

    return [vLines.sorted(), hLines.sorted()].flatMap({ $0 })
  }

  /// This method will calculate the grid polygons from the overlay's center to the overlay's bound with the provided rotation and offset.
  /// - Parameters:
  ///     - bounds: The overlay's bounding rectangle.
  ///     - center: The overlay's center.
  ///     - rotation: Rotaion should be in degrees and it rotates the grid polygon as per the provided rotation.
  ///     - offset: Offset should be in SizeInMeters and it moves the grid polygon as per the provided offset.
  ///     - gridCellSize: GridCellSize should be in meters and it is the distance between two grid line.
  /// - Returns: The array of GridPolygonOverlay.
  public static func calcGridPolygons(bounds: CoordinateBounds,
                                      center: CLLocationCoordinate2D,
                                      rotation: Double,
                                      offset: SizeInMeters,
                                      gridCellSize: Double) -> [GridPolygonOverlay] {
    var polygons : [GridPolygonOverlay] = []

    let origin = center.movedBy(latitudinalMeters: offset.height, longitudinalMeters: offset.width)
    let gridSize = bounds.northwest.distance(from: bounds.southeast)
    var numOfLines = Int(ceil(gridSize / gridCellSize))
    numOfLines = numOfLines % 2 == 0 ? numOfLines : numOfLines + 1

    let rotationRadians = (rotation * Double.pi / 180)
    let vLineMvmtDirection = (Double.pi / 2.0) + rotationRadians
    let hLineMvmtDirection = (Double.pi) + rotationRadians

    for vIndex in 0...Int(numOfLines / 2) {
      for hIndex in 0...Int(numOfLines / 2) {
        let vMvmt = gridCellSize * Double(vIndex)
        let hMvmt = gridCellSize * Double(hIndex)

        if vIndex == 0 && hIndex == 0 {
          polygons.append(
            buildPolygon(origin: origin,
                         vMvmt: vMvmt,
                         hMvmt: hMvmt,
                         vLineMvmtDirection: vLineMvmtDirection,
                         hLineMvmtDirection: hLineMvmtDirection,
                         gridCellSize: gridCellSize)
          )
        } else if vIndex == 0 {
          polygons.append(contentsOf: [
            buildPolygon(origin: origin,
                         vMvmt: vMvmt,
                         hMvmt: hMvmt,
                         vLineMvmtDirection: vLineMvmtDirection,
                         hLineMvmtDirection: hLineMvmtDirection,
                         gridCellSize: gridCellSize),
            buildPolygon(origin: origin,
                         vMvmt: vMvmt,
                         hMvmt: -hMvmt,
                         vLineMvmtDirection: vLineMvmtDirection,
                         hLineMvmtDirection: hLineMvmtDirection,
                         gridCellSize: gridCellSize)
          ])
        } else if hIndex == 0 {
          polygons.append(contentsOf: [
            buildPolygon(origin: origin,
                         vMvmt: vMvmt,
                         hMvmt: hMvmt,
                         vLineMvmtDirection: vLineMvmtDirection,
                         hLineMvmtDirection: hLineMvmtDirection,
                         gridCellSize: gridCellSize),
            buildPolygon(origin: origin,
                         vMvmt: -vMvmt,
                         hMvmt: hMvmt,
                         vLineMvmtDirection: vLineMvmtDirection,
                         hLineMvmtDirection: hLineMvmtDirection,
                         gridCellSize: gridCellSize)
          ])
        } else {
          polygons.append(contentsOf: [
            buildPolygon(origin: origin,
                         vMvmt: vMvmt,
                         hMvmt: hMvmt,
                         vLineMvmtDirection: vLineMvmtDirection,
                         hLineMvmtDirection: hLineMvmtDirection,
                         gridCellSize: gridCellSize),
            buildPolygon(origin: origin,
                         vMvmt: -vMvmt,
                         hMvmt: hMvmt,
                         vLineMvmtDirection: vLineMvmtDirection,
                         hLineMvmtDirection: hLineMvmtDirection,
                         gridCellSize: gridCellSize),
            buildPolygon(origin: origin,
                         vMvmt: vMvmt,
                         hMvmt: -hMvmt,
                         vLineMvmtDirection: vLineMvmtDirection,
                         hLineMvmtDirection: hLineMvmtDirection,
                         gridCellSize: gridCellSize),
            buildPolygon(origin: origin,
                         vMvmt: -vMvmt,
                         hMvmt: -hMvmt,
                         vLineMvmtDirection: vLineMvmtDirection,
                         hLineMvmtDirection: hLineMvmtDirection,
                         gridCellSize: gridCellSize)
          ])
        }
      }
    }

    return polygons
  }

  static private func buildPolygon(origin: CLLocationCoordinate2D,
                                   vMvmt: Double,
                                   hMvmt: Double,
                                   vLineMvmtDirection: Double,
                                   hLineMvmtDirection: Double,
                                   gridCellSize: Double) -> GridPolygonOverlay {
    let tl = origin.movedBy(distanceMeters: vMvmt,
                            bearingRadians: hLineMvmtDirection)
      .movedBy(distanceMeters: hMvmt,
               bearingRadians: vLineMvmtDirection)
    let tr = tl.movedBy(distanceMeters: gridCellSize,
                        bearingRadians: vLineMvmtDirection)
    let bl = tr.movedBy(distanceMeters: gridCellSize,
                        bearingRadians: hLineMvmtDirection)
    let br = tl.movedBy(distanceMeters: gridCellSize,
                        bearingRadians: hLineMvmtDirection)

    let coords = [tl, tr, bl, br, tl]

    return GridPolygonOverlay.create(coords)
  }

  public class GridPolygonOverlay: MKPolygon, Identifiable, Comparable {
    public var id: String = UUID().uuidString
    public let isGrid: Bool = true
    public var boundary: Turf.Polygon? = nil
    public var selected = false

    public var opacity: Double {
      selected ? 1 : 0
    }

    public var status: gridPolygonStatus = .pending

    public var geoJSON: String {
      guard let boundary = boundary else { return "" }

      let geoObj = Turf.Geometry(boundary)
      var feature = Turf.Feature(geometry: geoObj)
      feature.properties = JSONObject(rawValue: ["id": id])

      if let geoData = try? JSONEncoder().encode(feature),
         let geoString = String(data: geoData, encoding: .utf8) {
        return geoString
      }

      return ""
    }

    public static func create(_ coords: [CLLocationCoordinate2D], selected: Bool = false) -> GridPolygonOverlay {
      let polygon = GridPolygonOverlay(coordinates: coords, count: coords.count)
      polygon.selected = selected
      polygon.boundary = Turf.Polygon([coords])
      return polygon
    }

    public static func < (lhs: GridHelper.GridPolygonOverlay, rhs: GridHelper.GridPolygonOverlay) -> Bool {
      lhs.coordinate < rhs.coordinate
    }

    public static func == (lhs: GridHelper.GridPolygonOverlay, rhs: GridHelper.GridPolygonOverlay) -> Bool {
      lhs.coordinate == rhs.coordinate && lhs.selected == rhs.selected
    }

    /// This method uses GEOSwift to find intersection of the grid cell with the given boundary
    /// It's a 3 step process:
    /// 1. Convert boundary and cell polygon to GEOSwift Geometries
    /// 2. Find intersection
    /// 3. Convert intercetion to a GridPolygonOverlay
    public func intersection(with boundaryGeoJSON: String) -> GridPolygonOverlay? {
      let jsonDecoder = JSONDecoder()
      let jsonEncoder = JSONEncoder()

      /// 1. Convert boundary and cell polygon to GEOSwift Geometries
      if let cellData = try? jsonEncoder.encode(self.boundary),
         let cellGeoJSONObj = try? jsonDecoder.decode(GEOSwift.GeoJSON.self, from: cellData),
         let boundaryData = boundaryGeoJSON.data(using: .utf8),
         let boundaryGeoJSONObj = try? jsonDecoder.decode(GEOSwift.GeoJSON.self, from: boundaryData)
      {
      var intersectedGeometry: GEOSwift.Geometry? = nil
      var boundaryGeometries: [GEOSwift.Geometry?] = []

      switch boundaryGeoJSONObj {
      case .feature(let feature):
        boundaryGeometries = [feature.geometry]
      case .featureCollection(let featureCollection):
        boundaryGeometries = featureCollection.features.map({ $0.geometry })
      case .geometry(let geometry):
        boundaryGeometries = [geometry]
      }

      boundaryGeometries.forEach { boundaryGeometry in
        /// 2. Find intersection
        if let boundaryGeometry = boundaryGeometry {
          // we assume grid cell overlays are always geometries
          switch cellGeoJSONObj {
          case .geometry(let geometry):
            if let overlap = try? geometry.intersection(with: boundaryGeometry) {
              intersectedGeometry = overlap
            }
          default:
            print("Grid cell is not a geometry")
          }
        }
      }

      /// 3. Convert intersection geometry to a GridPolygonOverlay
      if let intersectedJsonData = try? jsonEncoder.encode(intersectedGeometry),
         let intersectedJsonString = String(data: intersectedJsonData, encoding: .utf8),
         let intersectedGeoObj = Turf.GeoJSONObject.create(from: intersectedJsonString),
         let intersectedPolygon = intersectedGeoObj.polygons.first,
         let intersectedPolygonCoords = intersectedPolygon.coordinates.first
      {
      let newOverlay = GridHelper.GridPolygonOverlay.create(intersectedPolygonCoords)
      newOverlay.selected = true
      return newOverlay
      }
      }

      return nil
    }
  }

  public class GridLineOverlay: MKPolyline, Comparable {
    let isGrid = true

    public static func < (lhs: GridHelper.GridLineOverlay, rhs: GridHelper.GridLineOverlay) -> Bool {
      lhs.coordinate < rhs.coordinate
    }
  }
}
