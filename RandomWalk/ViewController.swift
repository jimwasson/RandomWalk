//
//  ViewController.swift
//  RandomMovement
//
//  Created by Jim Wasson on 3/6/16.
//  Copyright © 2016 Jim Wasson. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation


// The ViewController is responsible for the display. It handles the status
// messages, the map display and the controls.
// Location data is obtained from the RandomWalk class object. It also
// is a RandomWalkDelegate which provides it with location data.
//
class ViewController: UIViewController, MKMapViewDelegate, RandomWalkDelegate {

    @IBOutlet weak var lblStatus: UILabel!

    @IBOutlet weak var btnReplay: UIButton!

    @IBOutlet weak var mapView: MKMapView!

    // The current user location reported by the CLLocationManager.
    // Just initialized to a default value.
    var userLocation:CLLocationCoordinate2D?

    // MARK: RandomWalkProtocol delegate and functions.

    // Provides our current user location.
    func userLocation(latitude: Double, longitude: Double) {
        self.userLocation = CLLocationCoordinate2DMake(latitude, longitude)
        self.setupMapView()
    }

    // Notification that a new random location was added.
    // Display the map annotation and update the status message.
    func randomLocation(id: Double, latitude: Double, longitude: Double) {
        // Display the location on the map.
        let newLocation = CLLocationCoordinate2DMake(latitude, longitude)
        self.setRandomLocationAnnotation(newLocation, id: id)
        // Display location info.
        let info = "Random Walk #\(Int(id)) Lat: \(String(format:"%.2f", latitude)) Lon: \(String(format:"%.2f", longitude))"
        self.lblStatus.text = info
    }

    // Notifications that a replay session has started or finished.
    func notifyReplayStatus(status:Bool) {
        // If status == true then replay is starting up.
        if status {
            // Set up by clearing the map of any location annotations.
            self.clearRandomLocationAnnotations()

            // Update the status message to indicate we are starting up.
            self.updateStatus(" (replay starting)")
        } else {
            // Replay has finished.
            // Update the status message to indicate we are starting up.
            self.updateStatus(" (replay finished)")
        }
    }

    // Drop an annotation on the map for a random location entry.
    // id is the id of the location.
    func setRandomLocationAnnotation(location:CLLocationCoordinate2D, id:Double) {
        let annotation = MKPointAnnotation()
        annotation.coordinate = location
        annotation.title = "# \(Int(id))"
        //annotation.subtitle = "Time:"
        mapView.addAnnotation(annotation)
    }

    // Clear all of the random location map annotations and their saved location information.
    func clearRandomLocationAnnotations() {
        // MKMapView stores all of its annotations internally in mapView.annotations array.
        // Gather all of the annotations related to our userLocation into an array.
        let ourAnnotations = mapView.annotations.filter { $0 !== mapView.userLocation }
        // Remove all of "our" annotations from mapView.
        self.mapView.removeAnnotations(ourAnnotations)
    }

    // Set up and display the map view. Creates the region and displays the map.
    // Uses the saved location and delta values. Can be used to conveniently reset the map whenever we need to.
    func setupMapView() {
        // Size the map view. Create the span to use for our map region.
        let span:MKCoordinateSpan = MKCoordinateSpanMake(RandomWalk.sharedInstance.latitudeDelta, RandomWalk.sharedInstance.longitudeDelta)
        let region:MKCoordinateRegion = MKCoordinateRegionMake(self.userLocation!, span)
        // Make sure the region fits the mapView area.
        let fittedRegion = mapView.regionThatFits(region)
        // Set the map's view area to the fitted region.
        mapView.setRegion(fittedRegion, animated: true)
    }

    // Replay the last saved random positions.
    @IBAction func btnReplaySaved(sender: AnyObject) {
        // Tell RandomWalk to replay the saved locations.
        RandomWalk.sharedInstance.replay()
    }

    // Reset the map if it has been scrolled, panned, zoomed, etc.
    @IBAction func btnResetMapDisplay(sender: AnyObject) {
        setupMapView()
    }

    // Clear the map of all location annotations and start over.
    @IBAction func btnStartNew(sender: AnyObject) {
        // Tell RandomWalk to start anew.
        RandomWalk.sharedInstance.restart()
        
        // Clear the mapView.
        self.clearRandomLocationAnnotations()
        // Reset the status.
        self.updateStatus("running")
    }

    // MARK: Utility functions.

    // Initialization function called one time as part of the application startup process.
    override func viewDidLoad() {
        super.viewDidLoad()

        // Set the map view to show our own location.
        // Shows the location with the familiar pulsating blue dot.
        mapView.showsUserLocation = true
        mapView.showsScale = true

        // Set our RandomWalkDelegate variable.
        RandomWalk.sharedInstance.rwDelegate = self

        // Start up the RandomWalk.
        RandomWalk.sharedInstance.startup()

        // Update the status message.
        self.updateStatus(" (running)")
    }

    // Update the status label.
    func updateStatus(statusMessage:String) {
        self.lblStatus.text = "Random Walk " + statusMessage
    }

    // setStatusBarStyle() deprecated in iOS 9. This is now how to set the status bar
    // style, override and return the desired style. Also works in iOS 8.
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

