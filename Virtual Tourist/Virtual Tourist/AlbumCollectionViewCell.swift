//
//  AlbumCollectionViewCell.swift
//  Virtual Tourist
//
//  Created by Brian Ortega on 5/14/15.
//  Copyright (c) 2015 Brian Ortega. All rights reserved.
//

import UIKit

class AlbumCollectionViewCell: UICollectionViewCell {
    
    var photoImageView: UIImageView!
    var label: UILabel!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        label = UILabel(frame: CGRectMake(0, 0, frame.size.width, frame.size.height))
        label.text = ""
        contentView.addSubview(label)
        
        photoImageView = UIImageView(frame: CGRectMake(0, 0, frame.size.width, frame.size.height))
        contentView.addSubview(photoImageView)
    }

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
