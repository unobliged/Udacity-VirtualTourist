//
//  FlickrClient.swift
//  Virtual Tourist
//
//  Created by Brian Ortega on 5/19/15.
//  Copyright (c) 2015 Brian Ortega. All rights reserved.
//

import Foundation
import MapKit
import CoreData

class FlickrClient {
    
    var session : NSURLSession
    var downloadCounter = 0
    
    // Please add the appropriate api key value locally before running
    var flickrAPIKey: String = ""
    
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext!
    }
    
    init() {
        session = NSURLSession.sharedSession()
    }
    
    // This searches for pictures at a given coordinate but does not download the images yet
    func getAlbum(coordinate: CLLocationCoordinate2D, completionHandler: (response: NSDictionary) -> Void) -> NSURLSessionDataTask {
        let request = NSMutableURLRequest(URL: NSURL(string: "https://api.flickr.com/services/rest/?method=flickr.photos.search&api_key=\(flickrAPIKey)&lat=\(coordinate.latitude)&lon=\(coordinate.longitude)&radius=10&format=json&nojsoncallback=1")!)
        let task = session.dataTaskWithRequest(request) { (data, response, error) in
            if error != nil {
                println(error)
                completionHandler(response: ["status": "???", "statusError": "network error"])
                return
            }
            
            FlickrClient.parseJSONWithCompletionHandler(data, completionHandler: { (data, error) in
                if error != nil {
                    println(error)
                    completionHandler(response: ["status": "???", "statusError": "error parsing response"])
                    return
                }
                
                FlickrClient.parseFlickrResponse(data) { (response) in
                    completionHandler(response: response)
                }
            })
        }
        task.resume()
        
        return task
    }
    
    class func parseFlickrResponse(parsedJSON: AnyObject, completionHandler: (response: NSDictionary) -> Void) {
        if let status: AnyObject = parsedJSON["stat"], statusError: AnyObject = parsedJSON["message"] {
                let response = ["status": status, "statusError": statusError]
                completionHandler(response: response)
        } else if let photos: AnyObject = parsedJSON["photos"] {
            if let photo = photos["photo"] as? NSMutableArray {
                FlickrClient.getPhotoImageURLs(photo) { (response) in
                    completionHandler(response: response)
                }
            } else {
                let response = ["status": "...", "statusError": "no images found"]
                completionHandler(response: response)
            }
        }
    }
    
    class func getPhotoImageURLs(photos: NSMutableArray, completionHandler: (response: NSDictionary) -> Void) {
        var photoArray = [String]()
        for photo in photos {
            if let farm = photo["farm"] as? Int, id = photo["id"] as? String, secret = photo["secret"] as? String, server = photo["server"] as? String {
                let imageURL = "https://farm\(farm).staticflickr.com/\(server)/\(id)_\(secret)_t.jpg"
                photoArray.append(imageURL)
            }
        }
        let response = ["photoImagePaths": photoArray]
        completionHandler(response: response)
    }
    
    // This downloads the photos and associates them with a given Pin
    func savePhotos(photos: [String], photoPin: Pin, completionHandler: (() -> Void)?) {
        // Download counter used to check for when all images downloaded
        self.downloadCounter = photos.count
    
        // Saves photos with Core Data
        for photo in photos {
            var newPhoto = NSEntityDescription.insertNewObjectForEntityForName("Photo", inManagedObjectContext: sharedContext) as! Photo
            newPhoto.imageURL = photo
            newPhoto.pin = photoPin
            let url = NSURL(string: photo)
            newPhoto.imagePath = url!.lastPathComponent!
            CoreDataStackManager.sharedInstance().saveContext()
            
            // Initiates download of photos
            self.getPhotoImage(photo) { (response) in
                if let data = response {
                    if let photoImage = UIImage(data: data) {
                        newPhoto.image = photoImage
                        self.downloadCounter--
                    }
                }
            }
        }
        
        // Runs optional closure
        if let ch = completionHandler {
            ch()
        }
    }
    
    func getPhotoImage(imageURL: String, completionHandler: ((response: NSData?) -> Void)) -> NSURLSessionDataTask {
        let imageURL = NSURL(string: imageURL)
        let task = session.dataTaskWithURL(imageURL!) { (data, response, error) in
            if error != nil {
                completionHandler(response: nil)
                return
            }
            
            completionHandler(response: NSData(data: data))
        }
        task.resume()
        
        return task
    }
    
    class func parseJSONWithCompletionHandler(data: NSData, completionHandler: (result: AnyObject!, error: NSError?) -> Void) {
        var parsingError: NSError? = nil
        
        let parsedResult: AnyObject? = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments, error: &parsingError)
        
        if let error = parsingError {
            completionHandler(result: nil, error: error)
        } else {
            completionHandler(result: parsedResult, error: nil)
        }
    }
    
    class func sharedInstance() -> FlickrClient {
        struct Singleton {
            static var sharedInstance = FlickrClient()
        }
        
        return Singleton.sharedInstance
    }
    
    // Using Image Cache code from Favorite Actors
    struct Caches {
        static let imageCache = ImageCache()
    }
}