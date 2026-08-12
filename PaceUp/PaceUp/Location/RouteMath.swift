//
//  RouteMath.swift
//  Pace Up
//
//  Geometry and smoothing helpers shared by the recorder, the map and the
//  detail charts.
//

import Foundation
import CoreLocation
import MapKit

enum RouteMath {

    /// Total great-circle distance along a trace, in metres.
    static func distance(of points: [RoutePoint]) -> Double {
        guard points.count > 1 else { return 0 }
        var total = 0.0
        for index in 1..<points.count {
            total += haversine(points[index - 1], points[index])
        }
        return total
    }

    static func haversine(_ a: RoutePoint, _ b: RoutePoint) -> Double {
        let earthRadius = 6_371_000.0
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180

        let h = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadius * atan2(h.squareRoot(), (1 - h).squareRoot())
    }

    /// Cumulative ascent and descent, in metres.
    ///
    /// Barometric and GPS altitude both wander by a metre or two while standing
    /// still. Summing raw deltas over an hour turns that noise into hundreds of
    /// phantom metres of climb, so deltas below `threshold` are ignored.
    static func elevationChange(of points: [RoutePoint], threshold: Double = 1.0) -> (gain: Double, loss: Double) {
        guard points.count > 1 else { return (0, 0) }

        let smoothed = movingAverage(points.map(\.altitude), window: 5)
        var gain = 0.0
        var loss = 0.0
        var reference = smoothed[0]

        for value in smoothed.dropFirst() {
            let delta = value - reference
            if delta > threshold {
                gain += delta
                reference = value
            } else if delta < -threshold {
                loss += -delta
                reference = value
            }
        }
        return (gain, loss)
    }

    static func movingAverage(_ values: [Double], window: Int) -> [Double] {
        guard window > 1, values.count > window else { return values }
        var out = [Double]()
        out.reserveCapacity(values.count)
        var sum = 0.0
        var queue = [Double]()
        for value in values {
            queue.append(value)
            sum += value
            if queue.count > window { sum -= queue.removeFirst() }
            out.append(sum / Double(queue.count))
        }
        return out
    }

    /// Splits a trace into fixed-distance segments.
    static func splits(from points: [RoutePoint], unitDistance: Double) -> [Split] {
        guard points.count > 1, unitDistance > 0 else { return [] }

        var splits = [Split]()
        var index = 1
        var accumulated = 0.0
        var splitStartTime = points[0].elapsed
        var splitStartAltitude = points[0].altitude

        for i in 1..<points.count {
            let segment = haversine(points[i - 1], points[i])
            accumulated += segment

            while accumulated >= unitDistance {
                let overshoot = accumulated - unitDistance
                let fraction = segment > 0 ? (segment - overshoot) / segment : 0
                let crossingTime = points[i - 1].elapsed
                    + (points[i].elapsed - points[i - 1].elapsed) * max(0, min(1, fraction))
                let crossingAltitude = points[i - 1].altitude
                    + (points[i].altitude - points[i - 1].altitude) * max(0, min(1, fraction))

                splits.append(Split(
                    index: index,
                    distance: unitDistance,
                    duration: max(0, crossingTime - splitStartTime),
                    elevationDelta: crossingAltitude - splitStartAltitude
                ))

                index += 1
                splitStartTime = crossingTime
                splitStartAltitude = crossingAltitude
                accumulated = overshoot
            }
        }

        if accumulated > 20, let last = points.last {
            splits.append(Split(
                index: index,
                distance: accumulated,
                duration: max(0, last.elapsed - splitStartTime),
                elevationDelta: last.altitude - splitStartAltitude
            ))
        }
        return splits
    }

    /// Region that frames a whole route with a little breathing room.
    static func region(for coordinates: [CLLocationCoordinate2D],
                       paddingFactor: Double = 1.4,
                       minimumSpan: Double = 0.004) -> MKCoordinateRegion? {
        guard !coordinates.isEmpty else { return nil }

        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        guard
            let minLat = latitudes.min(), let maxLat = latitudes.max(),
            let minLon = longitudes.min(), let maxLon = longitudes.max()
        else { return nil }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * paddingFactor, minimumSpan),
            longitudeDelta: max((maxLon - minLon) * paddingFactor, minimumSpan)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    /// Rolling pace series for the detail chart: seconds per kilometre sampled
    /// every `windowMeters`.
    /// `minimumPaceSecondsPerKm` rejects GPS glitches. The default of 120 s/km
    /// (30 km/h) is right for running but would discard an entire bike ride, so
    /// callers pass a lower bound when the activity can legitimately be faster.
    static func paceSeries(from points: [RoutePoint],
                           windowMeters: Double = 200,
                           minimumPaceSecondsPerKm: Double = 120) -> [(distance: Double, paceSecondsPerKm: Double)] {
        guard points.count > 1 else { return [] }

        var series = [(Double, Double)]()
        var windowDistance = 0.0
        var windowStart = points[0]
        var cumulative = 0.0

        for index in 1..<points.count {
            let step = haversine(points[index - 1], points[index])
            windowDistance += step
            cumulative += step

            if windowDistance >= windowMeters {
                let elapsed = points[index].elapsed - windowStart.elapsed
                if elapsed > 0 {
                    let pace = elapsed / (windowDistance / 1000)
                    // Clamp to something a human could produce; a GPS glitch
                    // otherwise puts a 90 min/km spike in the middle of a chart.
                    if pace > minimumPaceSecondsPerKm && pace < 3600 {
                        series.append((cumulative, pace))
                    }
                }
                windowDistance = 0
                windowStart = points[index]
            }
        }
        return series.map { (distance: $0.0, paceSecondsPerKm: $0.1) }
    }

    /// Elevation profile sampled against cumulative distance.
    static func elevationSeries(from points: [RoutePoint]) -> [(distance: Double, altitude: Double)] {
        guard points.count > 1 else { return [] }
        let smoothed = movingAverage(points.map(\.altitude), window: 7)
        var cumulative = 0.0
        var series = [(Double, Double)]()
        series.append((0, smoothed[0]))
        for index in 1..<points.count {
            cumulative += haversine(points[index - 1], points[index])
            series.append((cumulative, smoothed[index]))
        }
        return series.map { (distance: $0.0, altitude: $0.1) }
    }
}
