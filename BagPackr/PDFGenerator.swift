//
//  PDFGenerator.swift
//  BagPackr
//

import UIKit
import PDFKit

class PDFGenerator {
    static let shared = PDFGenerator()
    
    private init() {}
    
    // MARK: - Generate PDF for Single City Itinerary
    
    func generatePDF(for itinerary: Itinerary) -> URL? {
        let pdfMetaData = [
            kCGPDFContextCreator: "BagPackr",
            kCGPDFContextAuthor: "BagPackr Travel Planner",
            kCGPDFContextTitle: "\(itinerary.location) Itinerary"
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageWidth = 8.5 * 72.0  // Letter size
        let pageHeight = 11 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { context in
            var yPosition: CGFloat = 60
            
            // Page 1: Cover & Summary
            context.beginPage()
            
            // Header gradient background
            let headerRect = CGRect(x: 0, y: 0, width: pageWidth, height: 200)
            let colors = [UIColor.systemBlue.cgColor, UIColor.systemPurple.cgColor]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: colors as CFArray,
                                        locations: [0.0, 1.0]) {
                context.cgContext.drawLinearGradient(gradient,
                                                     start: CGPoint(x: 0, y: 0),
                                                     end: CGPoint(x: pageWidth, y: 200),
                                                     options: [])
            }
            
            // Title
            yPosition = 80
            let titleText = itinerary.location
            let titleFont = UIFont.boldSystemFont(ofSize: 36)
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.white
            ]
            titleText.draw(at: CGPoint(x: 60, y: yPosition), withAttributes: titleAttributes)
            
            // Duration & Budget
            yPosition = 140
            let subtitleFont = UIFont.systemFont(ofSize: 18)
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: subtitleFont,
                .foregroundColor: UIColor.white
            ]
            let subtitle = "\(itinerary.duration) Days • Budget: $\(Int(itinerary.budgetPerDay * Double(itinerary.duration)))"
            subtitle.draw(at: CGPoint(x: 60, y: yPosition), withAttributes: subtitleAttributes)
            
            // Interests
            yPosition = 240
            let sectionFont = UIFont.boldSystemFont(ofSize: 20)
            let sectionAttributes: [NSAttributedString.Key: Any] = [
                .font: sectionFont,
                .foregroundColor: UIColor.black
            ]
            "Interests".draw(at: CGPoint(x: 60, y: yPosition), withAttributes: sectionAttributes)
            
            yPosition += 30
            let bodyFont = UIFont.systemFont(ofSize: 14)
            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: bodyFont,
                .foregroundColor: UIColor.darkGray
            ]
            itinerary.interests.joined(separator: " • ").draw(at: CGPoint(x: 60, y: yPosition), withAttributes: bodyAttributes)
            
            // Daily Plans
            yPosition += 60
            
            for (dayIndex, plan) in itinerary.dailyPlans.enumerated() {
                // Check if need new page
                if yPosition > pageHeight - 200 {
                    context.beginPage()
                    yPosition = 60
                }
                
                // Day header
                let dayTitle = "Day \(dayIndex + 1)"
                let dayFont = UIFont.boldSystemFont(ofSize: 24)
                let dayAttributes: [NSAttributedString.Key: Any] = [
                    .font: dayFont,
                    .foregroundColor: UIColor.systemBlue
                ]
                dayTitle.draw(at: CGPoint(x: 60, y: yPosition), withAttributes: dayAttributes)
                yPosition += 40
                
                // Activities
                for activity in plan.activities {
                    // Check page break
                    if yPosition > pageHeight - 150 {
                        context.beginPage()
                        yPosition = 60
                    }
                    
                    // Time
                    let timeFont = UIFont.boldSystemFont(ofSize: 14)
                    let timeAttributes: [NSAttributedString.Key: Any] = [
                        .font: timeFont,
                        .foregroundColor: UIColor.systemPurple
                    ]
                    activity.time.draw(at: CGPoint(x: 70, y: yPosition), withAttributes: timeAttributes)
                    
                    // Activity name
                    yPosition += 20
                    let activityFont = UIFont.boldSystemFont(ofSize: 16)
                    let activityAttributes: [NSAttributedString.Key: Any] = [
                        .font: activityFont,
                        .foregroundColor: UIColor.black
                    ]
                    activity.name.draw(at: CGPoint(x: 70, y: yPosition), withAttributes: activityAttributes)
                    
                    // Description
                    yPosition += 25
                    let descFont = UIFont.systemFont(ofSize: 12)
                    let descAttributes: [NSAttributedString.Key: Any] = [
                        .font: descFont,
                        .foregroundColor: UIColor.darkGray
                    ]
                    
                    let descRect = CGRect(x: 70, y: yPosition, width: pageWidth - 130, height: 100)
                    let boundingRect = activity.description.boundingRect(
                        with: CGSize(width: pageWidth - 130, height: .greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        attributes: descAttributes,
                        context: nil
                    )
                    activity.description.draw(in: descRect, withAttributes: descAttributes)
                    yPosition += boundingRect.height + 10
                    
                    // Cost
                    if activity.cost > 0 {
                        let costText = "Cost: $\(Int(activity.cost))"
                        let costFont = UIFont.systemFont(ofSize: 12)
                        let costAttributes: [NSAttributedString.Key: Any] = [
                            .font: costFont,
                            .foregroundColor: UIColor.systemGreen
                        ]
                        costText.draw(at: CGPoint(x: 70, y: yPosition), withAttributes: costAttributes)
                        yPosition += 20
                    }
                    
                    yPosition += 15
                }
                
                yPosition += 20
            }
            
            // Footer on last page
            let footerText = "Created with BagPackr • Travel Smarter"
            let footerFont = UIFont.systemFont(ofSize: 10)
            let footerAttributes: [NSAttributedString.Key: Any] = [
                .font: footerFont,
                .foregroundColor: UIColor.gray
            ]
            footerText.draw(at: CGPoint(x: 60, y: pageHeight - 40), withAttributes: footerAttributes)
        }
        
        // Save to temporary directory
        let fileName = "\(itinerary.location.replacingOccurrences(of: " ", with: "_"))_Itinerary.pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: url)
            print("✅ PDF generated: \(url.path)")
            return url
        } catch {
            print("❌ Error saving PDF: \(error)")
            return nil
        }
    }
    
    // MARK: - Generate PDF for Multi-City Itinerary
    
    func generatePDF(for multiCity: MultiCityItinerary) -> URL? {
        let pdfMetaData = [
            kCGPDFContextCreator: "BagPackr",
            kCGPDFContextAuthor: "BagPackr Travel Planner",
            kCGPDFContextTitle: "\(multiCity.title) Multi-City Trip"
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageWidth = 8.5 * 72.0
        let pageHeight = 11 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { context in
            var yPosition: CGFloat = 60
            
            // Cover page
            context.beginPage()
            
            // Header
            let headerRect = CGRect(x: 0, y: 0, width: pageWidth, height: 200)
            let colors = [UIColor.systemPurple.cgColor, UIColor.systemBlue.cgColor]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: colors as CFArray,
                                        locations: [0.0, 1.0]) {
                context.cgContext.drawLinearGradient(gradient,
                                                     start: CGPoint(x: 0, y: 0),
                                                     end: CGPoint(x: pageWidth, y: 200),
                                                     options: [])
            }
            
            // Title
            let titleFont = UIFont.boldSystemFont(ofSize: 36)
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.white
            ]
            multiCity.title.draw(at: CGPoint(x: 60, y: 80), withAttributes: titleAttributes)
            
            // Subtitle
            let subtitleFont = UIFont.systemFont(ofSize: 18)
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: subtitleFont,
                .foregroundColor: UIColor.white
            ]
            let subtitle = "\(multiCity.citiesCount) Cities • \(multiCity.totalDuration) Days"
            subtitle.draw(at: CGPoint(x: 60, y: 140), withAttributes: subtitleAttributes)
            
            yPosition = 240
            
            // Cities overview
            let sectionFont = UIFont.boldSystemFont(ofSize: 20)
            let sectionAttributes: [NSAttributedString.Key: Any] = [
                .font: sectionFont,
                .foregroundColor: UIColor.black
            ]
            "Cities".draw(at: CGPoint(x: 60, y: yPosition), withAttributes: sectionAttributes)
            yPosition += 30
            
            let bodyFont = UIFont.systemFont(ofSize: 14)
            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: bodyFont,
                .foregroundColor: UIColor.darkGray
            ]
            multiCity.cityNames.draw(at: CGPoint(x: 60, y: yPosition), withAttributes: bodyAttributes)
            yPosition += 60
            
            // Each city
            for (cityIndex, cityStop) in multiCity.cityStops.enumerated() {
                guard let itinerary = multiCity.itineraries[cityStop.id] else { continue }
                
                context.beginPage()
                yPosition = 60
                
                // City header
                let cityTitleFont = UIFont.boldSystemFont(ofSize: 28)
                let cityTitleAttributes: [NSAttributedString.Key: Any] = [
                    .font: cityTitleFont,
                    .foregroundColor: UIColor.systemPurple
                ]
                "Stop \(cityIndex + 1): \(cityStop.location.name)".draw(at: CGPoint(x: 60, y: yPosition), withAttributes: cityTitleAttributes)
                yPosition += 40
                
                let durationText = "\(cityStop.duration) days"
                durationText.draw(at: CGPoint(x: 60, y: yPosition), withAttributes: bodyAttributes)
                yPosition += 40
                
                // Activities for this city
                for (dayIndex, plan) in itinerary.dailyPlans.enumerated() {
                    if yPosition > pageHeight - 200 {
                        context.beginPage()
                        yPosition = 60
                    }
                    
                    let dayTitle = "Day \(dayIndex + 1)"
                    let dayFont = UIFont.boldSystemFont(ofSize: 20)
                    let dayAttributes: [NSAttributedString.Key: Any] = [
                        .font: dayFont,
                        .foregroundColor: UIColor.systemBlue
                    ]
                    dayTitle.draw(at: CGPoint(x: 60, y: yPosition), withAttributes: dayAttributes)
                    yPosition += 35
                    
                    for activity in plan.activities {
                        if yPosition > pageHeight - 150 {
                            context.beginPage()
                            yPosition = 60
                        }
                        
                        // Time & Name
                        let timeFont = UIFont.boldSystemFont(ofSize: 12)
                        let timeAttributes: [NSAttributedString.Key: Any] = [
                            .font: timeFont,
                            .foregroundColor: UIColor.systemPurple
                        ]
                        activity.time.draw(at: CGPoint(x: 70, y: yPosition), withAttributes: timeAttributes)
                        yPosition += 18
                        
                        let activityFont = UIFont.boldSystemFont(ofSize: 14)
                        let activityAttributes: [NSAttributedString.Key: Any] = [
                            .font: activityFont,
                            .foregroundColor: UIColor.black
                        ]
                        activity.name.draw(at: CGPoint(x: 70, y: yPosition), withAttributes: activityAttributes)
                        yPosition += 22
                        
                        // Description
                        let descFont = UIFont.systemFont(ofSize: 11)
                        let descAttributes: [NSAttributedString.Key: Any] = [
                            .font: descFont,
                            .foregroundColor: UIColor.darkGray
                        ]
                        let descRect = CGRect(x: 70, y: yPosition, width: pageWidth - 130, height: 100)
                        let boundingRect = activity.description.boundingRect(
                            with: CGSize(width: pageWidth - 130, height: .greatestFiniteMagnitude),
                            options: [.usesLineFragmentOrigin, .usesFontLeading],
                            attributes: descAttributes,
                            context: nil
                        )
                        activity.description.draw(in: descRect, withAttributes: descAttributes)
                        yPosition += boundingRect.height + 8
                        
                        if activity.cost > 0 {
                            let costText = "$\(Int(activity.cost))"
                            let costAttributes: [NSAttributedString.Key: Any] = [
                                .font: UIFont.systemFont(ofSize: 11),
                                .foregroundColor: UIColor.systemGreen
                            ]
                            costText.draw(at: CGPoint(x: 70, y: yPosition), withAttributes: costAttributes)
                            yPosition += 18
                        }
                        
                        yPosition += 10
                    }
                    yPosition += 15
                }
            }
            
            // Footer
            let footerText = "Created with BagPackr • Travel Smarter"
            let footerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.gray
            ]
            footerText.draw(at: CGPoint(x: 60, y: pageHeight - 40), withAttributes: footerAttributes)
        }
        
        let fileName = "\(multiCity.title.replacingOccurrences(of: " ", with: "_"))_Trip.pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: url)
            print("✅ Multi-city PDF generated: \(url.path)")
            return url
        } catch {
            print("❌ Error saving PDF: \(error)")
            return nil
        }
    }
}
