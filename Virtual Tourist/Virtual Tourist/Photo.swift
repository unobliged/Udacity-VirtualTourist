//
//  Photo.swift
//  Virtual Tourist
//
//  Created by Brian Ortega on 5/14/15.
//  Copyright (c) 2015 Brian Ortega. All rights reserved.
//

import Foundation
import CoreData
import UIKit

@objc(Photo)

class Photo: NSManagedObject {

    @NSManaged var imageURL: String
    @NSManaged var imagePath: String
    @NSManaged var pin: Pin
    
    var image: UIImage? {
        get {
            return FlickrClient.Caches.imageCache.imageWithIdentifier(imagePath)
        }
        
        set {
            FlickrClient.Caches.imageCache.storeImage(newValue, withIdentifier: imagePath)
        }
    }
    
    // This deletes images in documents folder when corresponding Photo object deleted
    override func prepareForDeletion() {
        let path = FlickrClient.Caches.imageCache.pathForIdentifier(imagePath)
        let fm = NSFileManager.defaultManager()
        
        var error: NSError?
        if !fm.removeItemAtPath(path, error: &error) {
            println("delete unsuccessful: \(error)")
        }
    }
}
