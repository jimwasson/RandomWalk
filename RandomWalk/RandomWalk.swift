//
//  RandomWalk.swift
//  RandomMovement
//
//  Created by Jim Wasson on 3/7/16.
//  Copyright © 2016 Jim Wasson. All rights reserved.
//

import Foundation
import CoreLocation


// Implemented as a singleton.
// Access the singleton from anywhere using RandomWalk.sharedInstance.
class RandomWalk {

    // Singleton class constant (requires Swift 1.2 or later).
    static let sharedInstance = RandomWalk()
    // Make init() private so it can't be used -- can only use as a singleton.
    private init() {}

    // Our local CoreLocation Manager instance.
    var locationManager = CLLocationManager()
    // Latitude and longitude deltas in degrees to give us a 100 mile region to display on the map.
    // For latitude, 1 degree is always 69 miles. So our latitude delta is 100.0 / 69.0 = 1.44928 degrees.
    // Longitude is also 69 miles per degree but it varies by latitude and is adjusted when we get a
    // position update.
    var latitudeDelta:CLLocationDegrees = 100.0 / 69.0
    var longitudeDelta:CLLocationDegrees = 69.0

    // The current user location reported by the CLLocationManager.
    // Just initialized to a default value.
    var userLocation:CLLocation = CLLocation()

    // The random location generation update time in seconds.
    let updateTimeInterval = 30
    // The replay display interval time in seconds.
    let replayTimeInterval = 1

    // The location radius in meters.
    let locationRadius = 160935.0 // Defaults to 160,935 meters = 100 miles.
    // Maximum distance to move from the last location in meters.
    let movementDeltaMax:CLLocationDistance = 3218.7 // 3218.7 meters = 2 miles.
    // Minimum distance to move from the last location in meters.
    let movementDeltaMin:CLLocationDistance = 1000.0  // Minimum distance to move of 1000 meters.
    // Maximum number of degrees to use when randomizing bearings to move along.
    let randomBearingAdjustment:Double = 45.0   // Bearing adjustment default plus or minus 45 degrees.

    // Array of random locations generated each hour.
    // We will store up to the last 48 random locations that were generated.
    // We initialize it with an empty dictionary entry so we don't need to use an optional.
    var randomLocations:[[String:Double]] = [[:]]
    // The maximum number of random locations to store.
    var randomLocationsMax = 48
    
    // Generate a new random location and store it in the randomLocations array.
    // Uses movementDeltaMax to set the maximum distance to move from the last location.
    // Locations are saved with a datetime (NSDate) and the latitude and longitude.
    func generateRandomLocation() {
        if self.randomLocations[0] == [:] {
            // We initialized randomLocations to have an empty dictionary entry.
            // We don't have any locations yet so we need to generate the first one.
            // We generate a location < locationRadius miles but > 90% of locationRadius miles from the userLocation.
            let minDistance = locationRadius * 0.90 // Minimum will be 90% of the locationRadius setting.
            let distanceFromCurrent = Double(arc4random_uniform(UInt32(locationRadius - minDistance))) + minDistance
            // Generate random bearing to the new location.
            let bearingToLocation = Double(arc4random_uniform(360))
            // Generate the new location using distance and bearing from userLocation.
            let loc2D:CLLocationCoordinate2D = CLLocationCoordinate2DMake(self.userLocation.coordinate.latitude,
                self.userLocation.coordinate.longitude)
            let newLocation = self.newLocationBearing(bearingToLocation, distanceMeters: distanceFromCurrent, origin: loc2D)
            print("first location: \(newLocation)")
            // Save the location.
            let entryNumber:Double = 1.0 // First entry.
            var locationEntry:[String:Double] = ["id":entryNumber]
            locationEntry["lat"] = newLocation.latitude
            locationEntry["lon"] = newLocation.longitude
            // Delete the empty first entry.
            self.randomLocations.removeFirst()
            // Add the new location to randomLocations. Just directly add as we know it's empty.
            self.randomLocations.append(locationEntry)
            // Display the location on the map.
//            setRandomLocationAnnotation(newLocation, index: 0)
//            // Display location info.
//            let info = "Random Walk #\(Int(entryNumber)) Lat: \(String(format:"%.2f", newLocation.latitude)) Lon: \(String(format:"%.2f", newLocation.longitude))"
//            self.lblStatus.text = info
        } else {
            // Generate a random distance to move from movementDeltaMin to movementDeltaMax.
            var distanceToMove = Double(arc4random_uniform(UInt32(self.movementDeltaMax)))
            if distanceToMove < self.movementDeltaMin {
                distanceToMove += self.movementDeltaMin
            }
            // Get the last location. This should be the latest location.
            // Sort the locations array to get the latest one at the top.
            let sortedLocations:[[String:Double]] = randomLocations.sort() { $0["id"] < $1["id"] }
            // Convert the saved last location to a CLLocationCoordinate2D
            if let lastLocation = sortedLocations.last, lastId:Double = lastLocation["id"], lat:Double = lastLocation["lat"], lon:Double = lastLocation["lon"] {
                print("last location: \(lastLocation)")
                let lastCLLocation = CLLocationCoordinate2DMake(CLLocationDegrees(lat), CLLocationDegrees(lon))
                // Generate a bearing from lastLocation towards the userLocation.
                let newBearing = self.bearingToLocation(lastCLLocation, toLocation: self.userLocation)
                print("bearing \(newBearing)")
                // Randomize the bearing.
                let randomBearing = self.randomizeBearing(newBearing)
                let newLocation = self.newLocationBearing(randomBearing, distanceMeters: distanceToMove, origin: lastCLLocation)
                print("new location (\(distanceToMove)): \(newLocation)")
                // Save the location.
                let newId = Double(lastId) + 1.0
                var locationEntry:[String:Double] = ["id":newId]
                locationEntry["lat"] = newLocation.latitude
                locationEntry["lon"] = newLocation.longitude
                // Add the new location to randomLocations. addNewLocation() accounts for the maximum length.
                self.addNewLocation(locationEntry, lastLocation: lastLocation)
                // Display the location on the map.
//                setRandomLocationAnnotation(newLocation, index: newId)
//                // Display location info.
//                let info = "Random Walk #\(Int(newId)) Lat: \(String(format:"%.2f", newLocation.latitude)) Lon: \(String(format:"%.2f", newLocation.longitude))"
//                self.lblStatus.text = info
            }
        }
    }

    // Add the new location to the randomLocations array.
    // Treat it as a circular queue, respecting the limit of 48 entries.
    func addNewLocation(newLocation:[String:Double], lastLocation:[String:Double]) {
        // If the array isn't full, just append newLocation to it.
        if self.randomLocations.count < randomLocationsMax {
            self.randomLocations.append(newLocation)
        } else {
            // Find the lowest ID number element to replace.
            var lowestId = DBL_MAX //1000000000.0
            var lowestIndex = 0
            for var ndx in 0..<self.randomLocations.count {
                if let id = self.randomLocations[ndx]["id"] {
                    if id < lowestId {
                        lowestId = id
                        lowestIndex = ndx
                    }
                }
            }
            // Replace the lowestIndex element.
            self.randomLocations[lowestIndex] = newLocation
            print("replacing index \(lowestIndex)")
        }
    }

    // Calculate the bearing between two points.
    // Meant to give the bearing from point1 (the last random location) to point2 (the userLocation).
    func bearingToLocation(fromLocation : CLLocationCoordinate2D, toLocation : CLLocation) -> Double {
        // Returns a float with the angle in degrees between the two points.

        let lat1 = fromLocation.latitude * (M_PI / 180.0) // Convert latitude to radians.
        let lat2 = toLocation.coordinate.latitude * (M_PI / 180.0) // Convert latitude to radians.
        let deltaLon = (toLocation.coordinate.longitude - fromLocation.longitude) * (M_PI / 180.0) // Convert difference to radians.
        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - (sin(lat1) * cos(lat2) * cos(deltaLon))
        let brng = atan2(y, x)

        return ((brng * (180.0 / M_PI)) + 360) % 360 // Return bearing in degrees.
    }

    // Randomize a bearing by plus or minus the randomBearingAdjustment (in degrees).
    func randomizeBearing(bearing:Double) -> Double {
        // Generate randomized adjustment value
        let adjustment:Double = Double(arc4random_uniform(UInt32(self.randomBearingAdjustment)))
        // Decide on adding the adjustment (1) or subtracting (0).
        let plusOrMinus = arc4random_uniform(2)
        // Calculate the adjusted bearing.
        let adjustedBearing = plusOrMinus == 0 ? bearing - adjustment : bearing + adjustment

        return adjustedBearing
    }

    // Calculate the location that is bearing and distanceMeters from the given location.
    func newLocationBearing(bearing:Double, distanceMeters:Double, origin:CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        let distRadians = distanceMeters / (6372797.6) // earth radius in meters

        // Convert degrees to radians.
        let lat1 = origin.latitude * (M_PI / 180)
        let lon1 = origin.longitude * (M_PI / 180)
        let brngRadians = bearing * (M_PI / 180.0)

        let lat2 = asin(sin(lat1) * cos(distRadians) + cos(lat1) * sin(distRadians) * cos(brngRadians))
        let x = cos(distRadians) - (sin(lat1) * sin(lat2))
        let y = sin(brngRadians) * sin(distRadians) * cos(lat1)
        let lon2 = lon1 + atan2(y, x)

        return CLLocationCoordinate2D(latitude: lat2 * 180 / M_PI, longitude: ((lon2 * 180 / M_PI) + 540.0) % 360 - 180)
    }

    // Save the entire udpated randomLocations array in NSUserDefaults.
    func saveLocations() {
        NSUserDefaults.standardUserDefaults().setObject(randomLocations, forKey: "randomLocations")
        // In iOS 8+ we shouldn't call synchronize() unless absolutely necessary.
        // NSUserDefaults.standardUserDefaults().synchronize() // Force save.
    }

    // Get the randomLocations saved in NSUserDefaults and update the randomLocations array.
    func getLocations() {
        // Make sure we have a stored array in NSUserDefaults to retrieve.
        guard NSUserDefaults.standardUserDefaults().arrayForKey("randomLocations") != nil else {
            return
        }
        self.randomLocations = (NSUserDefaults.standardUserDefaults().arrayForKey("randomLocations") as? [[String:Double]])!
    }

    // CLLocationManager Delegate function. Called for a location update.
    // Update the current location and show it on the map but only one time.
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Stop further updates. We only need our current position.
        manager.stopUpdatingLocation()

        self.userLocation = locations[0]
        print("user location: \(self.userLocation)")
        // Adjust the longitudeDelta for our new latitude value.
        var posLat = self.userLocation.coordinate.latitude
        if posLat < 0.0 {
            // Latitude is West so it's negative. We just need positive values for our calculations.
            posLat *= -1.0
        }
        // Calculate the new longitude delta using our current latitude and save it.
        let longDelta: CLLocationDegrees = (100.0 / (69.0 - ((90.0 / 69.0) * posLat)))
        self.longitudeDelta = longDelta

        // Set up and display the map view.
//        setupMapView()
    }

    // CLLocationManager Delegate function.
    // Will be called if a location error occurs.
    func locationManager(manager:CLLocationManager, didFailWithError error:NSError) {
        print("Location Manager Error: \(error)")
    }
}