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


class ViewController: UIViewController, MGLMapViewDelegate {
    var mapView: NavigationMapView!
    var directionsRoute: Route?
    let toCoordinate = CLLocationCoordinate2D(latitude: 33.6494657, longitude: -117.8100549)
    var navigateButton: UIButton!
    @IBOutlet weak var findPeaksButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Format findPeaksButton
        findPeaksButton.setTitle("Find Peaks Near Me", for: .normal)
        findPeaksButton.layer.cornerRadius = 10
        findPeaksButton.clipsToBounds = true
        findPeaksButton.layer.shadowOffset = CGSize(width:0, height: 10)
            
    }
    
    func callOverpass(radius: Int, lat: Double, lon: Double, completionHandler: @escaping (_ infos:Infos) -> Void){
        let api = "https://overpass-api.de/api/interpreter?data="
        let query = String(format: "[out:json];node['natural'='peak'](around:\(Float(radius)*1609.344),\(lat),\(lon));out;")
        guard let url = URL(string: api + query) else {return}


        print("About to GET")
        let session = URLSession.shared
        session.dataTask(with: url) { (data, _, error) in
            
            if let data = data{
           
                do{
                    let infos = try JSONDecoder().decode(Infos.self, from: data)
                    completionHandler(infos)

                } catch{
                    print("We got an error \(error)")
                }
                
            }
            }.resume()
    }
    
    func findPeaks(){
        // Access Overpass API to get the nearest peaks
        let lat = 33.658704
        let lon = -117.936080
        
        for radius in stride(from:5, to:100, by: 5){
            print(radius)
            callOverpass(radius: radius, lat: lat, lon:lon, completionHandler: { (infos) -> Void in
                var resultDict: [Double: [String: String]] = [:]
                for element in infos.elements!{
                    //print(element.id)
                    if element != nil{
                        if element.lon != nil && element.lat != nil && element.tags!.name != nil{
                            let from = CLLocation(latitude: lat, longitude: lon)
                            let to = CLLocation(latitude: element.lat!, longitude: element.lon!)
                            resultDict[to.distance(from: from)] = ["name": element.tags!.name!, "lat":String(element.lat!), "lon": String(element.lon!)]
                            print(resultDict)
                        }
                        
                    }
                }
            })
        
            }
        }
    


    @IBAction func findPeaksButtonWasPressed(_ sender: Any) {
        //print("Button was pressed")

        findPeaks()
        
        /*
         mapView = NavigationMapView(frame: view.bounds) // view.bounds makes the map cover the entire screen
         mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
         view.addSubview(mapView) // Makes the Map view show up
         
         mapView.delegate = self
         mapView.showsUserLocation = true // Display user's location on the map
         
         mapView.setUserTrackingMode(.follow, animated: true)
         
         addButton()
    */
        //print("Hello")
        
    }

    
    func addButton(){
        navigateButton = UIButton(frame: CGRect(x: (view.frame.width/2) - 100, y: view.frame.height-75, width: 200, height: 50))
        navigateButton.backgroundColor =  #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        navigateButton.setTitle("NAVIGATE", for: .normal)
        navigateButton.setTitleColor(UIColor(red:59/255, green: 178/255, blue: 208/255, alpha: 1), for: .normal)
        navigateButton.titleLabel?.font = UIFont(name: "AvenirNext-DemiBold", size:18)
        navigateButton.layer.cornerRadius = 25
        navigateButton.layer.shadowOffset = CGSize(width:0, height: 10)
        navigateButton.addTarget(self, action: #selector(navigateButtonWasPressed(_:)), for: .touchUpInside)
        view.addSubview(navigateButton)
    }
    
    @objc func navigateButtonWasPressed(_ sender: UIButton) {
        // Start nagivation from current location to destination
        
        mapView.setUserTrackingMode(.none, animated: true)
        
        let annotation = MGLPointAnnotation()
        annotation.coordinate = toCoordinate
        annotation.title = "Start Navigation"
        mapView.addAnnotation(annotation)
        
        calculateRoute(from: mapView.userLocation!.coordinate, to: toCoordinate) { (route, error) in
            if error != nil {
                print("Error getting route")
            }
        }
    }
    
    func calculateRoute(from originCoor: CLLocationCoordinate2D, to destinationCoor: CLLocationCoordinate2D, completion: @escaping (Route?, Error?) -> Void) {
        // Calculate the route from current location to destination. Returns error if no route can be calculated
        
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
        let navigationVC = NavigationViewController(for: directionsRoute!)
        present(navigationVC, animated: true, completion: nil)
        
    }
    
    
    
}

