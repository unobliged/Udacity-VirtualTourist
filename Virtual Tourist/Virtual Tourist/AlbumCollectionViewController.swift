//
//  AlbumCollectionViewController.swift
//  Virtual Tourist
//
//  Created by Brian Ortega on 5/12/15.
//  Copyright (c) 2015 Brian Ortega. All rights reserved.
//

import UIKit
import CoreData

let reuseIdentifier = "AlbumCell"

class AlbumCollectionViewController: UICollectionViewController, UICollectionViewDataSource, NSFetchedResultsControllerDelegate  {

    @IBOutlet weak var newCollectionButton: UIBarButtonItem!
    
    var pin: Pin!
    var headerImage: UIImage?
    
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext!
    }
    
    lazy var fetchedResultsController: NSFetchedResultsController = {
        let fetchRequest = NSFetchRequest(entityName: "Photo")
        let predicate = NSPredicate(format: "pin = %@", self.pin)
        fetchRequest.predicate = predicate
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "imagePath", ascending: true)]
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.sharedContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        return fetchedResultsController
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.collectionView!.backgroundColor = UIColor.whiteColor()
        self.collectionView!.registerClass(AlbumCollectionViewCell.self, forCellWithReuseIdentifier: reuseIdentifier)
        
        if FlickrClient.sharedInstance().downloadCounter != 0 {
            newCollectionButton.enabled = false
        }
        
        // Grabs photos for selected pin
        fetchedResultsController.delegate = self
        fetchedResultsController.performFetch(nil)
    }

    // MARK: UICollectionViewDataSource

    override func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if fetchedResultsController.fetchedObjects!.isEmpty {
            return 1
        }
        
        return fetchedResultsController.fetchedObjects!.count
    }

    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(reuseIdentifier, forIndexPath: indexPath) as! AlbumCollectionViewCell
        
        self.checkDownloads()
        
        // Handles scenario where no images found
        if fetchedResultsController.fetchedObjects!.isEmpty {
            cell.label.text = "No Images"
            cell.photoImageView.image = UIImage()
            return cell
        }
        
        let photo = fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
        if photo.image != nil {
            cell.photoImageView.image = photo.image
        } else {
            cell.label.text = "Loading..."
            FlickrClient.sharedInstance().getPhotoImage(photo.imageURL) { (response) in
                if let data = response {
                    if let photoImage = UIImage(data: data) {
                        photo.image = photoImage
                        dispatch_async(dispatch_get_main_queue()) {
                            cell.label.text = ""
                            cell.photoImageView.image = photoImage
                            self.checkDownloads()
                        }
                    }
                }
            }
        }
        
        return cell
    }
    
    // This will enable New Collection button when downloads are done
    func checkDownloads() {
        if FlickrClient.sharedInstance().downloadCounter == 0 {
            NSOperationQueue.mainQueue().addOperationWithBlock {
                self.newCollectionButton.enabled = true
            }
        }
    }

    // Sets header image passed from map view controller
    override func collectionView(collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionReusableView {
        if kind == UICollectionElementKindSectionHeader {
            let header = collectionView.dequeueReusableSupplementaryViewOfKind(kind, withReuseIdentifier: "AlbumHeader", forIndexPath: indexPath) as! UICollectionReusableView
            if let img = headerImage {
                header.addSubview(UIImageView(image: img))
            }
            
            return header
        } else {
            return UICollectionReusableView()
        }
    }
    
    // MARK: UICollectionViewDelegate

    override func collectionView(collectionView: UICollectionView, shouldSelectItemAtIndexPath indexPath: NSIndexPath) -> Bool {
        if !fetchedResultsController.fetchedObjects!.isEmpty {
            let photo = fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
            sharedContext.deleteObject(photo)
            CoreDataStackManager.sharedInstance().saveContext()
            
            dispatch_async(dispatch_get_main_queue()) {
                self.fetchedResultsController.performFetch(nil)
                self.collectionView!.reloadData()
            }
        }
        
        return true
    }

    // This is the code for the New Collection button
    @IBAction func reloadAlbum(sender: AnyObject) {
        newCollectionButton.enabled = false
        let photos = fetchedResultsController.fetchedObjects as! [Photo]
        for photo in photos {
            sharedContext.deleteObject(photo)
            photo.image = nil
        }
        CoreDataStackManager.sharedInstance().saveContext()
        
        // Provides visual cue that the album photos are being deleted first, then downloaded again
        dispatch_async(dispatch_get_main_queue()) {
            self.fetchedResultsController.performFetch(nil)
            self.collectionView!.reloadData()
        }
        
        // Photos downloaded again, updated as the downloads are completed
        FlickrClient.sharedInstance().getAlbum(self.pin.coordinate) { (response) in
            if let photoImageURLs = response["photoImagePaths"] as? [String] {
                FlickrClient.sharedInstance().savePhotos(photoImageURLs, photoPin: self.pin) {
                    dispatch_async(dispatch_get_main_queue()) {
                        self.fetchedResultsController.performFetch(nil)
                        self.collectionView!.reloadData()
                    }
                }
            } else {
                self.checkForError(response, type: "Error")
            }
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
