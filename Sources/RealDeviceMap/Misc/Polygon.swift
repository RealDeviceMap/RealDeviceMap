//
//  Polygon.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 23.11.18.
//

import Turf
import S2Geometry

extension Polygon {

    func getS2CellIDs(minLevel: Int, maxLevel: Int, maxCells: Int) -> [S2CellId] {

        let bbox = BoundingBox(from: coordinates[0])
        let region = S2LatLngRect(
            lo: S2LatLng(
                lat: S1Angle(degrees: bbox!.southEast.latitude),
                lng: S1Angle(degrees: bbox!.northWest.longitude)
            ),
            hi: S2LatLng(
                lat: S1Angle(degrees: bbox!.northWest.latitude),
                lng: S1Angle(degrees: bbox!.southEast.longitude)
            )
        )
        let regionCoverer = S2RegionCoverer()
        regionCoverer.maxCells = maxCells
        regionCoverer.minLevel = minLevel
        regionCoverer.maxLevel = maxLevel
        let cellIDsBBox = regionCoverer.getInteriorCovering(region: region)

        var cellIDs = [S2CellId]()
        for cellID in cellIDsBBox {
            let cell = S2Cell(cellId: cellID)
            let coord0 = S2LatLng(point: cell.getVertex(0)).coord
            let coord1 = S2LatLng(point: cell.getVertex(1)).coord
            let coord2 = S2LatLng(point: cell.getVertex(2)).coord
            let coord3 = S2LatLng(point: cell.getVertex(3)).coord
            if contains(coord0) || contains(coord1) || contains(coord2) || contains(coord3) {
                cellIDs.append(cellID)
            }
        }
        return cellIDs
    }

}
