//
//  ComplicationData.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 12.02.17.
//  Copyright © 2017 opendata.ch. All rights reserved.
//

import Foundation
import ClockKit
private struct Constants {
    static let DepartureDuration = TimeInterval(60) // 1 minute
}


public final class ComplicationData: NSObject, NSCoding {

    private var _station:TFCStation? = nil
    private var stationId:String

    private var station:TFCStation {
        get {
            if let st = _station {
                return st
            }
            if let station = TFCStation.initWithCache(id: self.stationId) {
                self._station = station
            } else {
                self._station = TFCStation(name: "unknown", id: "4242424242", coord: nil)
            }
            return self._station!
        }
    }

    private var isDisplayedOnWatch:Bool = false

    private var lastUpdate:Date? = nil

    private struct timelineCacheDataStruct {
        var firstDepartureDate:Date?
        var lastDepartureDate:Date?
        var count: Int
    }

    private var timelineCacheData:timelineCacheDataStruct = timelineCacheDataStruct(firstDepartureDate: nil, lastDepartureDate: nil, count: 0)

    private var timelineEntries:[timelineEntry] = []

    init(station:TFCStation) {
        self.stationId = station.st_id
        super.init()
    }

    init(instance: ComplicationData) {
        self.stationId = instance.stationId
        self.timelineCacheData = instance.timelineCacheData
        self.timelineEntries = instance.timelineEntries
    }

    override public func copy() -> Any {
        return ComplicationData(instance: self)
    }

    public func encode(with aCoder: NSCoder) {
        aCoder.encode(self.stationId, forKey: "stationId")
        aCoder.encode(self.timelineCacheData.count, forKey: "timelineCacheData.count")
        aCoder.encode(self.timelineCacheData.firstDepartureDate, forKey: "timelineCacheData.count.firstDepartureDate")
        aCoder.encode(self.timelineCacheData.lastDepartureDate, forKey: "timelineCacheData.count.lastDepartureDate")
        aCoder.encode(self.timelineEntries, forKey: "timelineEntries")
        aCoder.encode(self.lastUpdate, forKey: "lastUpdate")
        aCoder.encode(self.isDisplayedOnWatch, forKey: "isDisplayedOnWatch")
    }

    required public init?(coder aDecoder: NSCoder) {
        self.stationId = aDecoder.decodeObject(forKey: "stationId") as! String
        if let timelineCacheDataCount = aDecoder.decodeObject(forKey: "timelineCacheData.count") as? Int {
            self.timelineCacheData.count = timelineCacheDataCount
            self.timelineCacheData.firstDepartureDate = aDecoder.decodeObject(forKey: "timelineCacheData.firstDepartureDate") as! Date?
            self.timelineCacheData.lastDepartureDate = aDecoder.decodeObject(forKey: "timelineCacheData.lastDepartureDate") as! Date?
        }
        if let timelineEntries = aDecoder.decodeObject(forKey: "timelineEntries") as? [timelineEntry] {
            self.timelineEntries = timelineEntries
        }
        self.lastUpdate = aDecoder.decodeObject(forKey: "lastUpdate") as? Date
        self.isDisplayedOnWatch = aDecoder.decodeBool(forKey: "isDisplayedOnWatch")
    }

    public static func initWithCache(station:TFCStation) -> ComplicationData {
        if let compldata = TFCCache.objects.stations.object(forKey: "compldata_\(station.st_id)") as? ComplicationData {
            DLog("ComplicationData from cache")
            return compldata
        }
        let compldata = ComplicationData(station: station)
        DLog("ComplicationData not from cache")
        compldata.setPinCache()
        return compldata
    }

    public static func initDisplayed() -> ComplicationData? {
        if let compldata = TFCCache.objects.stations.object(forKey: "compldata_displayed") as? ComplicationData {
            return compldata
        }
        DLog("ComplicationData displayed was nil")
        return nil

    }

    private func setPinCache() {
        TFCCache.objects.stations.setObject(self, forKey: "compldata_\(stationId)")
    }

    public func setIsDisplayedOnWatch() {
        self.lastUpdate = Date()
        self.setPinCache()
        self.isDisplayedOnWatch = true
        TFCCache.objects.stations.setObject(self, forKey: "compldata_displayed")
    }

    public func getStation() -> TFCStation {
        return self.station
    }

    public func getLastEntryDate() -> Date? {
        return self.timelineEntries.last?.entryDate
    }

    public func getFirstDepartureDate() -> Date? {
        return timelineCacheData.firstDepartureDate

    }

    public func getLastDepartureDate() -> Date? {
        return timelineCacheData.lastDepartureDate
    }

    public func getLastUpdate() -> Date? {
        return self.lastUpdate
    }

    public func clearLastUpdate() {
        self.lastUpdate = nil
        TFCCache.objects.stations.setObject(self, forKey: "compldata_displayed")
    }

    public func getTimelineEntries(for complication: CLKComplication, after date:Date? = nil, limit:Int? = nil) -> [CLKComplicationTimelineEntry] {
        var entries = [CLKComplicationTimelineEntry]()
        DLog("__")
        self.buildTimelineEntries()
        var lastDepartureTimeNew:Date? = timelineEntries.first?.departure1?.getScheduledTimeAsNSDate()

        for (entry) in timelineEntries {
            if let date = date {
                if (!(date.compare(entry.entryDate) == .orderedAscending)) { // check if the entry date is "correctly" after the given date
                    continue;
                }
            }
            if let clkentry = self.getClkEntryFor(entry: entry, complication: complication) {
                entries.append(clkentry)
                if let lastDepartureTime = entry.departure1?.getScheduledTimeAsNSDate() {
                    lastDepartureTimeNew  = lastDepartureTime
                }
                if let limit = limit, entries.count >= (limit - 1) {
                    break; // break if we reached the limit of entries
                }
            }
        }
        // if after date is set, add an endentry
        if (date != nil) {
            if let limit = limit {
                // remove all end entries until we're one below the limit
                while (entries.count >= limit) {
                    let _ = entries.popLast()
                }
            }
            if let lastEntry = self.getLastEntry(lastDeparture: lastDepartureTimeNew),
                let  clkentryLast = getClkEntryFor(entry: lastEntry, complication: complication) {
                entries.append(clkentryLast)
            }
        }
        return entries
    }

    public func getStartDate() -> Date {
        DLog("__")
        self.buildTimelineEntries()
        if let first = timelineEntries.first {
            return first.entryDate
        }
        return Date()
    }

    public func getEndDate() -> Date {
        DLog("__")
        self.buildTimelineEntries()
        if let last = timelineEntries.last {
            return last.entryDate
        }
        return Date().addingTimeInterval(60)
    }

    private func getClkEntryFor(entry:timelineEntry, complication: CLKComplication) -> CLKComplicationTimelineEntry? {
        if let tmpl = templateForStationDepartures(station, departure: entry.departure1, nextDeparture: entry.departure2, complication: complication) {
            return CLKComplicationTimelineEntry(date: entry.entryDate, complicationTemplate: tmpl)
        }
        return nil
    }

    private func buildTimelineEntries() {
        DLog("__")

        if let departures = station.getScheduledFilteredDepartures() {
            DLog("__")

             /*if (isDisplayedOnWatch) {
                DLog("\(station.name) is displayed on Watch already, don't build Timeline")
                return
            }*/
            //check if cached...
            if let lastDepartureDate = timelineCacheData.lastDepartureDate,
                let firstDepartureDate = timelineCacheData.firstDepartureDate
            {
                if (timelineCacheData.count == departures.count
                    && lastDepartureDate == departures.last?.getScheduledTimeAsNSDate()
                    && firstDepartureDate == departures.first?.getScheduledTimeAsNSDate()) {
                    DLog("\(station.name) didn't change, don't update timeline")
                    return;
                }
            }

            DLog("firstStation: \(station.name) with \(departures.count) filtered departures", toFile: true)
            self.timelineEntries = []
            var index = 0
            var previousDeparture: TFCDeparture? = nil
            var departure: TFCDeparture? = departures.first
            var nextDeparture: TFCDeparture? = (departures.count >= 2) ? departures[1] : nil
            while let thisDeparture = departure {
                let thisEntryDate = timelineEntryDateForDeparture(thisDeparture, previousDeparture: previousDeparture)
                // only add it, if previous departure is before this departure (when they are the same, it was added with the previous one (or if we have more than 2, then nr 3+ won't be added, which is fine)
                if (previousDeparture == nil ||
                    previousDeparture?.getScheduledTime() == nil ||
                    thisDeparture.getScheduledTime() == nil ||
                    previousDeparture!.getScheduledTime()! < thisDeparture.getScheduledTime()!) {

                    let entry = timelineEntry(entryDate: thisEntryDate, departure1: thisDeparture, departure2: nextDeparture)
                    timelineEntries.append(entry)
                    logTimelineEntry(entry)

                }
                index += 1
                previousDeparture = thisDeparture
                departure = (departures.count - 1 >= index) ? departures[index] : nil
                nextDeparture = (departures.count > index + 1) ? departures[index + 1] : nil
            }
            //append a last entry with no departure info one minute later
            DLog("entries count: \(timelineEntries.count)", toFile: true)
            timelineCacheData.count = departures.count
            timelineCacheData.firstDepartureDate = departures.first?.getScheduledTimeAsNSDate()
            timelineCacheData.lastDepartureDate = departures.last?.getScheduledTimeAsNSDate()
            self.setIsDisplayedOnWatch()
            TFCDataStore.sharedInstance.watchdata.scheduleNextUpdate(noBackOffIncr: true)
            if #available(watchOSApplicationExtension 5.0, *) {
                station.updateRelevantShortCuts()
            } 
        }
    }

    private func getLastEntry(lastDeparture:Date?) -> timelineEntry? {
        if let lastDeparture = lastDeparture {
            let entry = timelineEntry(entryDate: lastDeparture.addingTimeInterval(60), departure1: nil, departure2: nil)
            return entry
        }
        return nil
    }

    private func logTimelineEntry(_ entry:timelineEntry) {
        #if DEBUG
            DLog("tl 0: \(entry.entryDate)")
            if let thisDeparture = entry.departure1 {
                DLog("tl 1: \(thisDeparture.getLine()): \(thisDeparture.getDestination()) \(thisDeparture.getScheduledTime()!)")
            }
            if let nextDeparture = entry.departure2 {
                DLog("tl 2: \(nextDeparture.getLine()): \(nextDeparture.getDestination()) \(nextDeparture.getScheduledTime()!) ")
            }
        #endif
    }

    private func timelineEntryDateForDeparture(_ departure: TFCDeparture, previousDeparture: TFCDeparture?) -> Date {

        // If previous departure, show the next scheduled departure 1 minute after the last scheduled departure
        // => If a bus is scheduled at 13:00, it will be displayed till 13:01
        if let pd = previousDeparture, let date = pd.getScheduledTimeAsNSDate() {
            return date.addingTimeInterval(Constants.DepartureDuration)
        } else {
            if let schedTime = departure.getScheduledTimeAsNSDate() {
                return schedTime.addingTimeInterval(-6*60*60) // If no previous departure, show the departure 6 hours in advance
            }
        }
        return Date()
    }
    fileprivate func templateForStationDepartures(_ station: TFCStation, departure: TFCDeparture?, nextDeparture: TFCDeparture?, complication: CLKComplication) -> CLKComplicationTemplate? {

        switch (complication.family) {
        case CLKComplicationFamily.modularLarge:
            return getModularLargeTemplate(station, departure: departure, nextDeparture: nextDeparture)
        case CLKComplicationFamily.modularSmall:
            return getModularSmallTemplate(station, departure: departure)
        case CLKComplicationFamily.utilitarianLarge:
            return getUtilitarianLargeTemplate(station, departure: departure, nextDeparture: nextDeparture)
        case CLKComplicationFamily.utilitarianSmall:
            return getUtilitarianSmallTemplate(station, departure: departure, nextDeparture: nextDeparture)
        case CLKComplicationFamily.utilitarianSmallFlat:
            return getUtilitarianSmallTemplate(station, departure: departure, nextDeparture: nextDeparture)
        case CLKComplicationFamily.circularSmall:
            return getCircularSmallTemplate(station, departure: departure, nextDeparture: nextDeparture)
        case CLKComplicationFamily.extraLarge:
            return getExtraLargeTemplate(station, departure: departure, nextDeparture: nextDeparture)
        case .graphicCorner:
            if #available(watchOSApplicationExtension 5.0, *) {
                return getGraphicsCornerTemplate(station, departure: departure)
            } else {
                return CLKComplicationTemplate()
            }
        case .graphicBezel:
            if #available(watchOSApplicationExtension 5.0, *) {
                return getGraphicBezelTemplate(station, departure: departure)
            } else {
                return CLKComplicationTemplate()
            }
        case .graphicCircular:
            if #available(watchOSApplicationExtension 5.0, *) {
                return getGraphicCircularTemplate(departure: departure, bottomText: true)
            } else {
                return CLKComplicationTemplate()
            }
        case .graphicRectangular:
            if #available(watchOSApplicationExtension 5.0, *) {
                return getGraphicsRectangularTemplate(station, departure: departure, nextDeparture: nextDeparture)
            } else {
                return CLKComplicationTemplate()
            }
        }
    }


    fileprivate func getCircularSmallTemplate(_ station: TFCStation, departure: TFCDeparture?, nextDeparture: TFCDeparture?) -> CLKComplicationTemplateCircularSmallStackText {

        if let departure = departure, let departureTime = departure.getScheduledTimeAsNSDate() {
            let tmpl = CLKComplicationTemplateCircularSmallStackText()
            let departureLine = departure.getLine()
            tmpl.line1TextProvider = getDateProvider(departureTime)
            tmpl.line2TextProvider = CLKSimpleTextProvider(text: "\(departureLine)")
            return tmpl

        }
        return ComplicationData.getTemplateForComplication(CLKComplicationFamily.circularSmall) as! CLKComplicationTemplateCircularSmallStackText
    }

    fileprivate func getTextProviderLong(_ departure: TFCDeparture?, _ station: TFCStation) -> CLKTextProvider {
        var departureDestination = "-"
        var departureLine = "-"

        let textProvider:CLKTextProvider
        if let departure = departure {
            departureLine = departure.getLine()
            departureDestination = departure.getDestination(station)
            
            let date:CLKTextProvider
            if let departureDate = departure.getScheduledTimeAsNSDate() {
                date = getDateProvider(departureDate)
            } else {
                date = CLKSimpleTextProvider(text: "-")
            }
            textProvider = CLKTextProvider(
                byJoining: [
                    date,
                    CLKSimpleTextProvider(text: " \(departureLine) "),
                    CLKSimpleTextProvider(text: "\(departureDestination)")
                ],
                separator: nil
            )
        } else {
            textProvider = CLKSimpleTextProvider(text: "No data stored")
        }
        return textProvider
    }
    
    fileprivate func getTextProviderTimeAndLine (_ departure: TFCDeparture?) -> CLKTextProvider {
        var departureLine = "-"
        
        let textProvider:CLKTextProvider
        if let departure = departure {
            departureLine = departure.getLine()
            let date:CLKTextProvider
            if let departureDate = departure.getScheduledTimeAsNSDate() {
                date = getDateProvider(departureDate)
            } else {
                date = CLKSimpleTextProvider(text: "-")
            }
            textProvider = CLKTextProvider(
                byJoining: [
                    date,
                    CLKSimpleTextProvider(text: " \(departureLine)"),
                ],
                separator: nil
            )
        } else {
            textProvider = CLKSimpleTextProvider(text: "No data stored")
        }
        return textProvider
    }
    
    @available(watchOSApplicationExtension 5.0, *)
    fileprivate func getGraphicsRectangularTemplate(_ station: TFCStation, departure: TFCDeparture?, nextDeparture: TFCDeparture?) -> CLKComplicationTemplateGraphicRectangularStandardBody {
        let tmpl = CLKComplicationTemplateGraphicRectangularStandardBody()

        tmpl.headerTextProvider = CLKSimpleTextProvider(text: station.getName(true))
        
        tmpl.body1TextProvider = getTextProviderLong(departure, station)
        if let nextDeparture = nextDeparture{
            tmpl.body2TextProvider = getTextProviderLong(nextDeparture, station)
        } else {
            tmpl.body2TextProvider = CLKSimpleTextProvider(text: "-")
        }

        return tmpl
    }
    
    fileprivate func getExtraLargeTemplate(_ station: TFCStation, departure: TFCDeparture?, nextDeparture: TFCDeparture?) -> CLKComplicationTemplateExtraLargeStackText {

        if let departure = departure, let departureTime = departure.getScheduledTimeAsNSDate() {
            let tmpl = CLKComplicationTemplateExtraLargeStackText()

            tmpl.highlightLine2 = false
            let departureLine = departure.getLine()
            tmpl.line1TextProvider = getDateProvider(departureTime)
            tmpl.line2TextProvider = CLKSimpleTextProvider(text: "\(departureLine)")
            return tmpl

        }
        return ComplicationData.getTemplateForComplication(CLKComplicationFamily.extraLarge) as! CLKComplicationTemplateExtraLargeStackText
    }

    fileprivate func getUtilitarianLargeTemplate(_ station: TFCStation, departure: TFCDeparture?, nextDeparture: TFCDeparture?) -> CLKComplicationTemplateUtilitarianLargeFlat {

        if let departure = departure {

            let tmpl = CLKComplicationTemplateUtilitarianLargeFlat()
            tmpl.textProvider = getTextProviderLong(departure, station)
            return tmpl
        }
        return ComplicationData.getTemplateForComplication(CLKComplicationFamily.utilitarianLarge) as! CLKComplicationTemplateUtilitarianLargeFlat

    }

    fileprivate func getUtilitarianSmallTemplate(_ station: TFCStation, departure: TFCDeparture?, nextDeparture: TFCDeparture?) -> CLKComplicationTemplateUtilitarianSmallFlat {

        if let departure = departure {
            let tmpl = CLKComplicationTemplateUtilitarianSmallFlat()
            tmpl.textProvider = getTextProviderTimeAndLine(departure)
            return tmpl
        }
        return ComplicationData.getTemplateForComplication(CLKComplicationFamily.utilitarianSmall) as! CLKComplicationTemplateUtilitarianSmallFlat
    }

    fileprivate func getModularSmallTemplate(_ station: TFCStation, departure: TFCDeparture?) -> CLKComplicationTemplateModularSmallStackText {

        if let  departure = departure, let departureTime = departure.getScheduledTimeAsNSDate() {
            let tmpl = CLKComplicationTemplateModularSmallStackText()
            let departureLine = departure.getLine()
            tmpl.line1TextProvider = getDateProvider(departureTime)
            tmpl.line2TextProvider = CLKSimpleTextProvider(text: "\(departureLine)")
            return tmpl
        }
        return ComplicationData.getTemplateForComplication(CLKComplicationFamily.modularSmall) as! CLKComplicationTemplateModularSmallStackText

    }
    
    @available(watchOSApplicationExtension 5.0, *)
    fileprivate func getGraphicsCornerTemplate(_ station: TFCStation, departure: TFCDeparture?) -> CLKComplicationTemplateGraphicCornerStackText {
        
        if let departure = departure, let departureTime = departure.getScheduledTimeAsNSDate()
            {
            let departureDestination = departure.getDestination(station)
            let tmpl = CLKComplicationTemplateGraphicCornerStackText()
            let departureLine = departure.getLine()
            tmpl.innerTextProvider = CLKSimpleTextProvider(text: "\(departureLine) \(departureDestination)")
            tmpl.outerTextProvider = getDateProvider(departureTime)
            return tmpl
        }
        return ComplicationData.getTemplateForComplication(CLKComplicationFamily.graphicCorner) as! CLKComplicationTemplateGraphicCornerStackText
    }
    
    @available(watchOSApplicationExtension 5.0, *)
    fileprivate func getGraphicBezelTemplate(_ station: TFCStation, departure: TFCDeparture?) -> CLKComplicationTemplateGraphicBezelCircularText {
        
        if let departure = departure
        {
            let tmpl = CLKComplicationTemplateGraphicBezelCircularText()
            let departureLine = departure.getLine()
            let departureDestination = departure.getDestination(station)

            tmpl.textProvider = CLKSimpleTextProvider(text: "\(departureLine) \(departureDestination)")
            tmpl.circularTemplate = getGraphicCircularTemplate(departure: departure, bottomText: false)
            return tmpl
        }
        return ComplicationData.getTemplateForComplication(CLKComplicationFamily.graphicBezel) as! CLKComplicationTemplateGraphicBezelCircularText
    }

    @available(watchOSApplicationExtension 5.0, *)
    fileprivate func getGraphicCircularTemplate(departure: TFCDeparture?, bottomText: Bool) -> CLKComplicationTemplateGraphicCircularOpenGaugeSimpleText {
        
        if let departure = departure, let departureTime = departure.getScheduledTimeAsNSDate()
        {
            let tmpl = CLKComplicationTemplateGraphicCircularOpenGaugeSimpleText()
            let departureLine = departure.getLine()
            if (bottomText) {
                tmpl.bottomTextProvider = CLKSimpleTextProvider(text: "\(departureLine)")
            } else {
                tmpl.bottomTextProvider = CLKSimpleTextProvider(text: "")
            }
            tmpl.centerTextProvider = getDateProviderAbbreviated(departureTime)
            tmpl.gaugeProvider =  CLKSimpleGaugeProvider(style: CLKGaugeProviderStyle.ring, gaugeColor: UIColor.black, fillFraction: CLKSimpleGaugeProviderFillFractionEmpty)
            return tmpl
        }
        return ComplicationData.getTemplateForComplication(CLKComplicationFamily.graphicCircular) as! CLKComplicationTemplateGraphicCircularOpenGaugeSimpleText
    }

    fileprivate func getModularLargeTemplate(_ station: TFCStation, departure: TFCDeparture?, nextDeparture: TFCDeparture?) -> CLKComplicationTemplateModularLargeTable {

        // if let departure = departure {
        let tmpl = CLKComplicationTemplateModularLargeTable() // Currently supports only ModularLarge

        tmpl.headerTextProvider = CLKSimpleTextProvider(text: station.getName(true))

        var departureDestination = "-"
        var departureLine = "-"
        if let departure = departure {
            departureLine = departure.getLine()
            departureDestination = departure.getDestination(station)
            tmpl.row1Column2TextProvider = CLKSimpleTextProvider(text: "\(departureLine) \(departureDestination)")

        } else {
            tmpl.row1Column2TextProvider = CLKSimpleTextProvider(text: "No data stored")
        }

        var nextDepartureDestination = "-"
        let nextDepartureLine = nextDeparture?.getLine() ?? "-"

        if let nextDeparture = nextDeparture {
            nextDepartureDestination = nextDeparture.getDestination(station)
        }

        if let departureDate = departure?.getScheduledTimeAsNSDate() {
            tmpl.row1Column1TextProvider = getDateProvider(departureDate)
        } else {
            tmpl.row1Column1TextProvider = CLKSimpleTextProvider(text: "-")
        }

        tmpl.row2Column2TextProvider = CLKSimpleTextProvider(text: "\(nextDepartureLine) \(nextDepartureDestination)")

        if let nextDepartureDate = nextDeparture?.getScheduledTimeAsNSDate() {
            tmpl.row2Column1TextProvider = getDateProvider(nextDepartureDate)
        } else {
            tmpl.row2Column1TextProvider = CLKSimpleTextProvider(text: "-")
        }
        return tmpl

    }

    fileprivate func getDateProvider(_ date: Date) -> CLKRelativeDateTextProvider {
        let units: NSCalendar.Unit = [.minute, .hour]
        let style: CLKRelativeDateStyle = .natural
        return CLKRelativeDateTextProvider(date: date, style: style, units: units)
    }
    
    fileprivate func getDateProviderAbbreviated(_ date: Date) -> CLKRelativeDateTextProvider {
        let units: NSCalendar.Unit = [.minute, .hour]
        let style: CLKRelativeDateStyle = .naturalAbbreviated
        return CLKRelativeDateTextProvider(date: date, style: style, units: units)
    }
    
    public static func getTemplateForComplication(_ family: CLKComplicationFamily) -> CLKComplicationTemplate {
        switch family {
            
        case CLKComplicationFamily.modularLarge:
            let tmpl = CLKComplicationTemplateModularLargeTable()
            
            tmpl.headerTextProvider = CLKSimpleTextProvider(text: "Station")
            tmpl.row1Column1TextProvider = CLKSimpleTextProvider(text: "-- ------", shortText: nil)
            tmpl.row1Column2TextProvider = CLKSimpleTextProvider(text: "--", shortText: nil)
            tmpl.row2Column1TextProvider = CLKSimpleTextProvider(text: "-- ------", shortText: nil)
            tmpl.row2Column2TextProvider = CLKSimpleTextProvider(text: "--", shortText: nil)
            return tmpl
        case CLKComplicationFamily.modularSmall:
            let tmpl = CLKComplicationTemplateModularSmallStackText()
            tmpl.line1TextProvider = CLKSimpleTextProvider(text: "--");
            tmpl.line2TextProvider = CLKSimpleTextProvider(text: "-");
            return tmpl
        case CLKComplicationFamily.utilitarianLarge:
            let tmpl = CLKComplicationTemplateUtilitarianLargeFlat()
            tmpl.textProvider = CLKSimpleTextProvider(text: "-- -- ------")
            return tmpl
        case CLKComplicationFamily.utilitarianSmallFlat:
            let tmpl = CLKComplicationTemplateUtilitarianSmallFlat()
            tmpl.textProvider = CLKSimpleTextProvider(text: "-- --");
            return tmpl
        case CLKComplicationFamily.utilitarianSmall:
            let tmpl = CLKComplicationTemplateUtilitarianSmallFlat()
            tmpl.textProvider = CLKSimpleTextProvider(text: "-- --");
            return tmpl
        case CLKComplicationFamily.circularSmall:
            let tmpl = CLKComplicationTemplateCircularSmallStackText()
            tmpl.line1TextProvider = CLKSimpleTextProvider(text: "--");
            tmpl.line2TextProvider = CLKSimpleTextProvider(text: "-");
            return tmpl
        case CLKComplicationFamily.extraLarge:
            let tmpl = CLKComplicationTemplateExtraLargeStackText()
            tmpl.line1TextProvider = CLKSimpleTextProvider(text: "--");
            tmpl.line2TextProvider = CLKSimpleTextProvider(text: "-");
            return tmpl
        case .graphicCorner:
            if #available(watchOSApplicationExtension 5.0, *) {
                let tmpl = CLKComplicationTemplateGraphicCornerStackText()
                tmpl.innerTextProvider =  CLKSimpleTextProvider(text: "-- ------");
                tmpl.outerTextProvider =  CLKSimpleTextProvider(text: "--");
                return tmpl
            } else {
                return  CLKComplicationTemplate()
            }
        case .graphicBezel:
            if #available(watchOSApplicationExtension 5.0, *) {
                let tmpl = CLKComplicationTemplateGraphicBezelCircularText()
                tmpl.textProvider =  CLKSimpleTextProvider(text: "-- ------");
                tmpl.circularTemplate = getTemplateForComplication(.graphicCircular) as! CLKComplicationTemplateGraphicCircular
                return tmpl
            } else {
                return  CLKComplicationTemplate()
            }
        case .graphicCircular:
            if #available(watchOSApplicationExtension 5.0, *) {
                let tmpl = CLKComplicationTemplateGraphicCircularOpenGaugeSimpleText()
                tmpl.bottomTextProvider = CLKSimpleTextProvider(text: "");
                tmpl.centerTextProvider = CLKSimpleTextProvider(text: "--");
                
                tmpl.gaugeProvider = CLKSimpleGaugeProvider(style: CLKGaugeProviderStyle.ring, gaugeColor: UIColor.black, fillFraction: CLKSimpleGaugeProviderFillFractionEmpty)
                return tmpl
            } else {
                return  CLKComplicationTemplate()
            }
        case .graphicRectangular:
            if #available(watchOSApplicationExtension 5.0, *) {
                let tmpl = CLKComplicationTemplateGraphicRectangularStandardBody()
                tmpl.headerTextProvider = CLKSimpleTextProvider(text: "Station")
                tmpl.body1TextProvider = CLKSimpleTextProvider(text: "-- -- ------")
                tmpl.body2TextProvider = CLKSimpleTextProvider(text: "-- -- ------")
                return tmpl
            } else {
                return  CLKComplicationTemplate()
            }
        }
    }
}

class timelineEntry: NSObject, NSCoding {
    var entryDate:Date
    var departure1:TFCDeparture?
    var departure2:TFCDeparture?

    init(entryDate: Date, departure1:TFCDeparture?, departure2: TFCDeparture?) {
        self.entryDate = entryDate
        self.departure1 = departure1
        self.departure2 = departure2
        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        self.entryDate = aDecoder.decodeObject(forKey: "entryDate") as! Date
        self.departure1 = aDecoder.decodeObject(forKey: "departure1") as! TFCDeparture?
        self.departure2 = aDecoder.decodeObject(forKey: "departure2") as! TFCDeparture?
    }

    func encode(with aCoder: NSCoder) {
        aCoder.encode(self.entryDate, forKey: "entryDate")
        aCoder.encode(self.departure1, forKey: "departure1")
        aCoder.encode(self.departure2, forKey: "departure2")
    }
}

