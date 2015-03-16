//
//  StationTableViewCell.swift
//  timeforcoffee
//
//  Created by Jan Hug on 04.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import UIKit
import timeforcoffeeKit

class StationTableViewCell: UITableViewCell {
    @IBOutlet weak var StationIconView: UIView!
    @IBOutlet weak var StationNameLabel: UILabel!
    @IBOutlet weak var StationDescriptionLabel: UILabel!
    @IBOutlet weak var StationFavoriteButton: UIButton!

    lazy var station: TFCStation = TFCStation()

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        StationIconView.layer.cornerRadius = StationIconView.layer.bounds.width / 2
        StationIconView.clipsToBounds = true
        
        StationFavoriteButton.addTarget(self, action: "favoriteButtonTouched:", forControlEvents: UIControlEvents.TouchUpInside)
    }

    deinit {
        println("cell deinit")
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    func favoriteButtonTouched(sender: UIButton) {

        func completion() -> Void {
            self.drawIcon()
        }

        self.station.toggleIcon(self.StationFavoriteButton!, icon: StationIconView, completion: completion)

    }

    func drawCell() {
        self.selectionStyle = UITableViewCellSelectionStyle.None;
        drawIcon()
        let parent = self.superview?.superview as StationTableView
        let locManager = parent.locManager
        StationNameLabel?.text = station.getName(false)

        if (locManager.currentLocation == nil) {
            StationDescriptionLabel.text = ""
            return
        }

        StationDescriptionLabel.text = station.getDistanceForDisplay(locManager.currentLocation, completion: {
            text in
            if (text != nil) {
                self.StationDescriptionLabel.text = text
            }
        })
    }

    func drawIcon() {
        StationFavoriteButton.setImage(station.getIcon(), forState: UIControlState.Normal)
        StationIconView.transform = CGAffineTransformMakeScale(1, 1);
        StationIconView.alpha = 1.0

    }

}
