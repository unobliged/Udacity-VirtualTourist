//
//  MapViewController.swift
//  Virtual Tourist
//
//  Created by Brian Ortega on 5/12/15.
//  Copyright (c) 2015 Brian Ortega. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class MapViewController: UIViewController, MKMapViewDelegate, NSFetchedResultsControllerDelegate {

    @IBOutlet weak var mapView: MKMapView!
    
    let screenSize: CGRect = UIScreen.mainScreen().bounds
    var selectedPin: MKAnnotationView?
    var pinImage: UIImage?
    var headerImage: UIImage?
    
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext!
    }
    
    lazy var fetchedResultsController: NSFetchedResultsController = {
        let fetchRequest = NSFetchRequest(entityName: "Pin")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "latitude", ascending: true)]
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.sharedContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        return fetchedResultsController
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Sets up long press gesture recognizer to add pins
        var lpgr = UILongPressGestureRecognizer(target: self, action: "handleLongPress:")
        lpgr.minimumPressDuration = 2.0
        self.mapView.addGestureRecognizer(lpgr)
        self.mapView.delegate = self
        
        // Grabs previously dropped pins
        fetchedResultsController.delegate = self
        fetchedResultsController.performFetch(nil)
        self.mapView.addAnnotations(self.fetchedResultsController.fetchedObjects)
    }
    
    func handleLongPress(lpgr: UILongPressGestureRecognizer) {
        if lpgr.state == UIGestureRecognizerState.Began {
            // Gets coordinate of long press
            let location = lpgr.locationInView(self.mapView)
            let coordinate = self.mapView.convertPoint(location, toCoordinateFromView: self.mapView)
            
            // Adds annotation using coordinate
            var annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            self.mapView.addAnnotation(annotation)
            
            // Saves Pin with Core Data and searches Flickr for photos
            var newPin = NSEntityDescription.insertNewObjectForEntityForName("Pin", inManagedObjectContext: sharedContext) as! Pin
            newPin.latitude = coordinate.latitude
            newPin.longitude = coordinate.longitude
            newPin.coordinate = CLLocationCoordinate2DMake(coordinate.latitude, coordinate.longitude)
            CoreDataStackManager.sharedInstance().saveContext()
            
            FlickrClient.sharedInstance().getAlbum(coordinate) { (response) in
                if let photoImageURLs = response["photoImagePaths"] as? [String] {
                    FlickrClient.sharedInstance().savePhotos(photoImageURLs, photoPin: newPin, completionHandler: nil)
                } else {
                    self.checkForError(response, type: "Error")
                }
            }
        }
    }
    
    func mapView(mapView: MKMapView!, viewForAnnotation annotation: MKAnnotation!) -> MKAnnotationView! {
        let reuseId = "pin"
        var pinView = mapView.dequeueReusableAnnotationViewWithIdentifier(reuseId) as? MKPinAnnotationView
        
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.canShowCallout = false
            pinView!.pinColor = .Red
        }
        else {
            pinView!.annotation = annotation
        }
        
        self.pinImage = pinView!.image
        return pinView
    }
    
    func mapView(mapView: MKMapView!, didSelectAnnotationView view: MKAnnotationView!) {
        // Specs do not indicate a callout; will directly segue to Album View
        self.selectedPin = view
        self.makeMapImage() { (image, error) in
            if error != nil {
                println(error)
                return
            }
            
            // If snapshot made, pass to album view to use as header image
            self.headerImage = image
            self.performSegueWithIdentifier("AlbumViewSegue", sender: self)
        }
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "AlbumViewSegue" {
            let vc = segue.destinationViewController as! UINavigationController
            let acvc = vc.childViewControllers[0] as! AlbumCollectionViewController
            acvc.headerImage = headerImage
            let albumPin = self.fetchSelectedPin()
            acvc.pin = albumPin
        }
    }
    
    func fetchSelectedPin() -> Pin {
        let fetchRequest = NSFetchRequest(entityName: "Pin")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "latitude", ascending: true)]
        
        // Find pin by coordinate
        let predicateLat = NSPredicate(format: "latitude = %lf", self.selectedPin!.annotation.coordinate.latitude)
        let predicateLon = NSPredicate(format: "longitude = %lf", self.selectedPin!.annotation.coordinate.longitude)
        let finalPredicate = NSCompoundPredicate(type: NSCompoundPredicateType.AndPredicateType, subpredicates: [predicateLat, predicateLon])
        fetchRequest.predicate = finalPredicate
        
        let pinFetch = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.sharedContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        pinFetch.performFetch(nil)
        
        return pinFetch.fetchedObjects?.first as! Pin
    }
    
    // This creates the header image for the album view using the map annotation
    // Derived from SO post: http://stackoverflow.com/questions/18776288/snapshot-of-mkmapview-in-ios7
    func makeMapImage(completionHandler: (image: UIImage!, error: NSError!) -> ()) {
        let options = MKMapSnapshotOptions()
        if let pin = selectedPin {
            options.region = MKCoordinateRegionMake(pin.annotation.coordinate, MKCoordinateSpanMake(10, 10))
        } else {
            completionHandler(image: nil, error: NSError()) // just need to trigger early return in didSelectAnnotationView
            return
        }
        options.size = CGSizeMake(screenSize.width, 100)
        
        let snapshot = MKMapSnapshotter(options: options)
        snapshot.startWithCompletionHandler() { (snapshot, error) in
            if error != nil {
                completionHandler(image: nil, error: error)
                return
            }
            
            let image = snapshot.image
            let imageRect = CGRectMake(0, 0, image.size.width, image.size.height)
            UIGraphicsBeginImageContextWithOptions(image.size, true, image.scale)
            image.drawAtPoint(CGPointZero)
            var pinPoint = snapshot.pointForCoordinate(self.selectedPin!.annotation.coordinate)
            if CGRectContainsPoint(imageRect, pinPoint) {
                let pinCenterOffset = self.selectedPin!.centerOffset
                pinPoint.x -= self.selectedPin!.bounds.size.width / 2.0
                pinPoint.y -= self.selectedPin!.bounds.size.height / 2.0
                pinPoint.x += pinCenterOffset.x
                pinPoint.y += pinCenterOffset.y
                self.pinImage!.drawAtPoint(pinPoint)
            }
            
            let finalImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            completionHandler(image: finalImage, error: nil)
        }
    }
    
    func checkForError(response: NSDictionary, type: String) {
        if let status: AnyObject = response["status"], statusError: AnyObject = response["statusError"] {
            var alert = UIAlertController(title: type, message: "status: \(status), statusError: \(statusError)", preferredStyle: UIAlertControllerStyle.Alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: nil))
            NSOperationQueue.mainQueue().addOperationWithBlock {
                    self.presentViewController(alert, animated: true, completion: nil)
            }
        }
    }
}

