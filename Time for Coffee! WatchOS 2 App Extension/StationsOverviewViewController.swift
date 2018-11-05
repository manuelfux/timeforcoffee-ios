//
//  StationsOverviewViewController.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 13.04.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import WatchKit
import Foundation
import timeforcoffeeKitWatch

class StationsOverviewViewController: WKInterfaceController {

    @IBOutlet weak var stationsTable: WKInterfaceTable!

    @IBOutlet weak var infoGroup: WKInterfaceGroup!
    @IBOutlet weak var infoLabel: WKInterfaceLabel!
    var activatedOnce = false
    var activated = false

    func showOnlyFavorites() -> Bool {
        return false
    }

    lazy var watchdata: TFCWatchData = {
        return TFCWatchData()
    }()

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        DLog("awakeWithContext")
        stationsTable.setNumberOfRows(2, withRowType: "stations")
    }

    override func willActivate() {
        super.willActivate()
        DLog("willActivate")
        self.activated = true
        if (activatedOnce) {
            getStations()
        }
    }

    override func didAppear() {
        DLog("didAppear")
        super.didAppear()
        if (!activatedOnce) {
            if (showOnlyFavorites()) {
                self.setTitle("Favorites")
            } else {
                self.setTitle("Nearby Stations")
                self.addMenuItem(with: WKMenuItemIcon.resume, title: "Reload", action: #selector(StationsOverviewViewController.contextButtonReload))
            }
            activatedOnce = true
            getStations()
        }
       // getStations()
   }

    override func willDisappear() {
        super.willDisappear()
    }

    override func didDeactivate() {
        DLog("didDeactivate")
        self.activated = false
        super.didDeactivate()
    }

    @objc func contextButtonReload() {
        if let ud =  UserDefaults(suiteName: "group.ch.opendata.timeforcoffee") {
            ud.setValue(nil, forKey: "lastFirstStationId")
        }
        getStations()
        TFCDataStore.sharedInstance.requestAllDataFromPhone()
    }

    fileprivate func getStations() {
        func handleReply(_ stations: TFCStations?) {
            if (stations == nil || stations?.count() == nil) {
                return
            }
            if (self.activated) {
                WKInterfaceDevice.current().play(WKHapticType.click)
                infoGroup.setHidden(true)
                if let stations = stations {
                    let ctxStations:Array<TFCStation>
                    // show all stations in favorites
                    if (self.showOnlyFavorites()) {
                        ctxStations = stations.getStationsAsArray()
                    } else {
                        ctxStations = stations.getStationsAsArray(10)
                    }
                    if (self.stationsTable.numberOfRows != ctxStations.count) {
                        self.adjustTableSize(newCount: ctxStations.count)
                    }
                    var i = 0;
                    for (station) in ctxStations {
                        if let sr = stationsTable.rowController(at: i) as? StationsRow {
                            sr.drawCell(station)
                        }
                        i += 1
                    }
                }
            }
        }
        func errorReply(_ text: String) {
            infoGroup.setHidden(false)
            infoLabel.setText(text)
        }

        watchdata.getStations(handleReply, errorReply: errorReply, stopWithFavorites: false, favoritesOnly: self.showOnlyFavorites())
    }

    override func table(_ table: WKInterfaceTable, didSelectRowAt rowIndex: Int) {
        let row = table.rowController(at: rowIndex) as? StationsRow
        if let station = row?.station {
            DLog("call fetchDepartureDataForStation")
            TFCWatchDataFetch.sharedInstance.fetchDepartureDataForStation(station)
            NotificationCenter.default.post(name: Notification.Name(rawValue: "TFCWatchkitSelectStation"), object: nil, userInfo: ["st_id": station.st_id, "name": station.name])
        }
        
    }

    fileprivate func adjustTableSize(newCount: Int) {
        DLog("adjustTableSize to: \(newCount)")
        if let oldCount = stationsTable?.numberOfRows {
            let delta = newCount - oldCount
             DLog("oldCount: \(oldCount)")
            if delta > 0 {
                let rowChangeRange = Range(uncheckedBounds: (lower: oldCount, upper: newCount))
                let rowChangeIndexSet = IndexSet(integersIn:rowChangeRange)
                stationsTable?.insertRows(
                    at: rowChangeIndexSet,
                    withRowType: "stations"
                )
                
            } else if delta < 0 {
                let rowChangeRange = Range(uncheckedBounds: (lower: newCount, upper: oldCount))
                let rowChangeIndexSet = IndexSet(integersIn:rowChangeRange)

                stationsTable?.removeRows(at: rowChangeIndexSet)
            }
        } else {
            stationsTable?.setNumberOfRows(newCount, withRowType: "stations")
        }
    }

}

