//
//  ViewController.swift
//  Peak Finder
//
//  Created by Andres on 1/16/19.
//  Copyright © 2019 Andres. All rights reserved.
//

import UIKit
import Mapbox
import MapboxDirections
import MapboxCoreNavigation
import MapboxNavigation
import CoreLocation

// JSON Response Structure from Overpass API

struct Infos: Decodable{
    let elements: [Element]?
    
    init(elements: [Element]? = nil){
        
        self.elements = elements
    }
}

struct Element: Decodable{
    let id: Int?
    let lat: Double?
    let lon: Double?
    let tags: Tag?

}

struct Tag: Decodable{
    let name: String?
}


class ViewController: UIViewController, MGLMapViewDelegate, CLLocationManagerDelegate {
    var mapView: NavigationMapView!
    var directionsRoute: Route?
    let toCoordinate = CLLocationCoordinate2D(latitude: 33.6494657, longitude: -117.8100549)
    var refreshButton: UIButton!
    var navigateButton: UIButton!
    var currentLocation: CLLocationCoordinate2D!
    @IBOutlet weak var findPeaksButton: UIButton!
    let locationManager = CLLocationManager()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Request user location
        locationManager.requestWhenInUseAuthorization()
        
        if CLLocationManager.locationServicesEnabled(){
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.startUpdatingLocation()
        }
        
        // Format findPeaksButton
        findPeaksButton.setTitle("Find Peaks Near Me", for: .normal)
        findPeaksButton.layer.cornerRadius = 25
        findPeaksButton.clipsToBounds = true
        findPeaksButton.layer.shadowOffset = CGSize(width:0, height: 10)
            
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first{
            currentLocation = location.coordinate
        }
    }
    
    func callOverpass(radius: Int, lat: Double, lon: Double) -> Infos{
        let api = "https://overpass-api.de/api/interpreter?data="
        let query = String(format: "[out:json];node['natural'='peak'](around:\(Float(radius)*1609.344),\(lat),\(lon));out;")
        var infos = Infos()
        guard let url = URL(string: api + query) else {return infos}

        print("About to GET")
        let semaphore = DispatchSemaphore(value: 0)

        let _ = URLSession.shared.dataTask(with: url) { (data, _, error) in
            
            if let data = data{
           
                do{
                    infos = try JSONDecoder().decode(Infos.self, from: data)

                } catch{
                    print("We got an error \(error)")
                }
                
            }
            semaphore.signal()
            }.resume()
        
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        return infos
    }
    
    func findPeaks() -> [Double: [String: String]]{
        // Access Overpass API to get the nearest peak
        
        let lat = currentLocation.latitude
        let lon = currentLocation.longitude
        
        var resultDict: [Double: [String: String]] = [:]
        
        for radius in stride(from:10, to:100, by: 20){
            
            let infos = callOverpass(radius: radius, lat: lat, lon:lon)

            for element in infos.elements!{

                if element.lon != nil && element.lat != nil && element.tags!.name != nil{
                    let from = CLLocation(latitude: lat, longitude: lon)
                    let to = CLLocation(latitude: element.lat!, longitude: element.lon!)
                    resultDict[to.distance(from: from)] = ["name": element.tags!.name!, "lat":String(element.lat!), "lon": String(element.lon!)] // Is distance in miles or km?
                }
                
            }
            if resultDict != [:] {break}
        }
        return resultDict
    }

    @IBAction func findPeaksButtonWasPressed(_ sender: Any) {
        //print("Button was pressed")

        let peaks = findPeaks() // Finds mountain peaks nearby using the Overpass API
        
        mapView = NavigationMapView(frame: view.bounds) // view.bounds makes the map cover the entire screen
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(mapView) // Makes the Map view show up
        
        // Add Nearby mountain peaks to the map
        let peaksSorted = peaks.keys.sorted()
        var count = 1
        for peak in peaksSorted{
            let annotation = MGLPointAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(latitude: Double(peaks[peak]!["lat"]!)!, longitude: Double(peaks[peak]!["lon"]!)!)
            let peakName = peaks[peak]!["name"]!
            annotation.title = "Find Directions to \"\(peakName)\""
            mapView.addAnnotation(annotation)
            if count == 5 {break} // Limit to top 5 results
            else {count = count + 1}
        }
        
        mapView.delegate = self
        mapView.showsUserLocation = true // Display user's location on the map
        mapView.setUserTrackingMode(.follow, animated: true)

        addRefreshButton()

        
    }
    
    func addSmallRefreshButton(){
        refreshButton = UIButton(frame: CGRect(x: (view.frame.width/2) - 175, y: view.frame.height-90, width: 150, height: 50))
        refreshButton.backgroundColor =  #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        refreshButton.setTitle("Refresh", for: .normal)
        refreshButton.setTitleColor(UIColor(red:59/255, green: 178/255, blue: 208/255, alpha: 1), for: .normal)
        refreshButton.titleLabel?.font = UIFont(name: "AvenirNext-DemiBold", size:18)
        refreshButton.layer.cornerRadius = 25
        refreshButton.layer.shadowOffset = CGSize(width:0, height: 10)
        refreshButton.addTarget(self, action: #selector(findPeaksButtonWasPressed(_:)), for: .touchUpInside)
        view.addSubview(refreshButton)
    }
    
    func addRefreshButton(){
        
        refreshButton = UIButton(frame: CGRect(x: (view.frame.width/2) - 100, y: view.frame.height-90, width: 200, height: 50))
        refreshButton.backgroundColor =  #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        refreshButton.setTitle("Refresh", for: .normal)
        refreshButton.setTitleColor(UIColor(red:59/255, green: 178/255, blue: 208/255, alpha: 1), for: .normal)
        refreshButton.titleLabel?.font = UIFont(name: "AvenirNext-DemiBold", size:18)
        refreshButton.layer.cornerRadius = 25
        refreshButton.layer.shadowOffset = CGSize(width:0, height: 10)
        refreshButton.addTarget(self, action: #selector(findPeaksButtonWasPressed(_:)), for: .touchUpInside)
        view.addSubview(refreshButton)
    }
    
    func addNavigateButton(){
        navigateButton = UIButton(frame: CGRect(x: (view.frame.width/2) - 15, y: view.frame.height-90, width: 195, height: 50))
        navigateButton.backgroundColor =  #colorLiteral(red: 0.3387691593, green: 0.5320139941, blue: 1, alpha: 1)
        navigateButton.setTitle("Start Navigation", for: .normal)
        navigateButton.setTitleColor(UIColor(red:255/255, green: 255/255, blue: 255/255, alpha: 1), for: .normal)
        navigateButton.titleLabel?.font = UIFont(name: "AvenirNext-DemiBold", size:18)
        navigateButton.layer.cornerRadius = 25
        navigateButton.layer.shadowOffset = CGSize(width:0, height: 10)
        navigateButton.addTarget(self, action: #selector(navigateButtonWasPressed(_:)), for: .touchUpInside)
        view.addSubview(navigateButton)
    }
    
    @objc func navigateButtonWasPressed(_ sender: UIButton){
        let navigationVC = NavigationViewController(for: directionsRoute!)
        present(navigationVC, animated: true, completion: nil)
    }
    
    
    func calculateRoute(from originCoor: CLLocationCoordinate2D, to destinationCoor: CLLocationCoordinate2D, completion: @escaping (Route?, Error?) -> Void) {
        // Calculate the route from current location to destination. Returns error if no route can be calculated
        
        refreshButton.removeFromSuperview()
        addSmallRefreshButton()
        
        let origin = Waypoint(coordinate: originCoor, coordinateAccuracy: -1, name: "Start")
        let destination = Waypoint(coordinate: destinationCoor, coordinateAccuracy: -1, name: "Finish")
        
        let options = NavigationRouteOptions(waypoints: [origin, destination], profileIdentifier: .automobileAvoidingTraffic) // Navigation via automobile by default
        
        _ = Directions.shared.calculate(options, completionHandler: {(waypoints, routes, error) in
            self.directionsRoute = routes?.first
            
            // Draw Line on Map
            self.drawRoute(route: self.directionsRoute!)
            
            let coordinateBounds = MGLCoordinateBounds(sw: destinationCoor, ne: originCoor) // Bounding box around the directions route
            let insets = UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50) // Cushion around bounding box above
            let routeCam = self.mapView.cameraThatFitsCoordinateBounds(coordinateBounds, edgePadding: insets)
            self.mapView.setCamera(routeCam, animated: true)
            
            
            
        })
        
        addNavigateButton()
    }
    
    func drawRoute(route: Route){
        guard route.coordinateCount > 0 else {return} // Make sure that a valid route was passed
        
        var routeCoordinates = route.coordinates!
        
        let polyline = MGLPolylineFeature(coordinates: &routeCoordinates, count: route.coordinateCount)
        
        if let source = mapView.style?.source(withIdentifier: "route-source") as? MGLShapeSource{ // If have a layer
            source.shape = polyline
        }
            
        else { // Create layer from scratch
            let source = MGLShapeSource(identifier: "route-source", features:[polyline], options: nil)
            
            let lineStyle = MGLLineStyleLayer(identifier: "route-style", source: source)
            lineStyle.lineColor = NSExpression(forConstantValue: #colorLiteral(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529, alpha: 1))
            lineStyle.lineWidth = NSExpression(forConstantValue: 4.0)
            
            mapView.style?.addSource(source)
            mapView.style?.addLayer(lineStyle)
        }
        
        
    }
    
    func mapView(_ mapView: MGLMapView, annotationCanShowCallout annotation: MGLAnnotation) -> Bool{
        return true
    }
    
    func mapView(_ mapView: MGLMapView, tapOnCalloutFor annotation: MGLAnnotation){
        
        calculateRoute(from: mapView.userLocation!.coordinate, to: annotation.coordinate) { (route, error) in
            if error != nil {
                print("Error getting route")
            }
        }
        
    }
    
}

