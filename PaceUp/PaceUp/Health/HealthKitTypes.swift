//
//  HealthKitTypes.swift
//  Pace Up
//

import Foundation
import HealthKit

enum PaceUpHealthTypes {

    static var stepCount: HKQuantityType { HKQuantityType(.stepCount) }
    static var walkingRunningDistance: HKQuantityType { HKQuantityType(.distanceWalkingRunning) }
    static var cyclingDistance: HKQuantityType { HKQuantityType(.distanceCycling) }
    static var activeEnergy: HKQuantityType { HKQuantityType(.activeEnergyBurned) }
    static var heartRate: HKQuantityType { HKQuantityType(.heartRate) }
    static var exerciseTime: HKQuantityType { HKQuantityType(.appleExerciseTime) }
    static var flightsClimbed: HKQuantityType { HKQuantityType(.flightsClimbed) }

    /// Everything Pace Up reads. Matches the list on the Connect Health screen.
    static var readTypes: Set<HKObjectType> {
        [
            stepCount,
            walkingRunningDistance,
            cyclingDistance,
            activeEnergy,
            heartRate,
            exerciseTime,
            flightsClimbed,
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute()
        ]
    }

    /// Everything Pace Up writes. Writing workouts is what allows a user's
    /// history to survive deleting the app.
    static var shareTypes: Set<HKSampleType> {
        [
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute(),
            activeEnergy,
            walkingRunningDistance,
            cyclingDistance
        ]
    }
}

extension ActivityType {
    var hkWorkoutActivityType: HKWorkoutActivityType {
        switch self {
        case .walk:  return .walking
        case .run:   return .running
        case .hike:  return .hiking
        case .cycle: return .cycling
        case .other: return .other
        }
    }

    init(hkWorkoutActivityType: HKWorkoutActivityType) {
        switch hkWorkoutActivityType {
        case .walking:  self = .walk
        case .running:  self = .run
        case .hiking:   self = .hike
        case .cycling:  self = .cycle
        default:        self = .other
        }
    }
}
