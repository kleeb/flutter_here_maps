//
//  NativeViewFactory.swift
//  Runner
//
//  Created by Rohit Nisal on 12/24/18.
//  Copyright © 2018 The Chromium Authors. All rights reserved.
//

import Foundation
import NMAKit
import SwiftProtobuf

class MapViewFactory : NSObject, FlutterPlatformViewFactory {

    var registerar: FlutterPluginRegistrar!


    init(with registerar: FlutterPluginRegistrar) {
        self.registerar = registerar
    }

    public func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?) -> FlutterPlatformView {
        return MapView(frame, viewId:viewId, args:args, registerar: registerar)
    }
}

public class MapView : NSObject, FlutterPlatformView {
    let frame : CGRect
    let viewId : Int64
    let registerar: FlutterPluginRegistrar

    var map: NMAMapView!

    init(_ frame:CGRect, viewId:Int64, args: Any?, registerar: FlutterPluginRegistrar){
        self.frame = frame
        self.viewId = viewId
        self.registerar = registerar
        if let argsDict = args as? Dictionary<String, AnyObject> {
            let cameraPosition = argsDict["initialCameraPosition"]
            print(cameraPosition ?? "No camera position")
        } else {
            print(args.debugDescription)
        }
        map = NMAMapView(frame: self.frame)
    }

    func initMethodCallHanlder() {
        let chanel = FlutterMethodChannel(name: "flugins.etzuk.flutter_here_maps/MapViewChannel", binaryMessenger: registerar.messenger())
        chanel.setMethodCallHandler { [weak self] (call, result) in
            self?.onMethodCallHanler(call, result: result)
        }
    }

    public func view() -> UIView {
        initMethodCallHanlder()
        return map
    }


    public func onMethodCallHanler(_ call: FlutterMethodCall, result: @escaping FlutterResult) {

        guard let arg = call.arguments as? FlutterStandardTypedData else { fatalError("Non standart type")}
        //TODO: Optimize this by sending in the function name the decoder and split into
        // two .proto file. one for objects and one for chanel method.


        var responseObject: Any? = nil
        switch call.method {
        case "request":
            if let request = try? FlutterHereMaps_MapChannelRequest(serializedData: arg.data) {
                responseObject = invoke(request: request)
            }
        case "replay":
            if let replay = try? FlutterHereMaps_MapChannelReplay(serializedData: arg.data) {
                responseObject = invoke(replay: replay)
            }
        default: break;
        }

        if let replay = responseObject as? Message {
            do {
                result(try replay.serializedData())
            } catch {
                result("Error when try to serialized data")
            }
        } else {
            result(nil)
        }

    }

    private func invoke(request: FlutterHereMaps_MapChannelRequest) -> Any?{
        switch request.object {
        case .setMapObject(let mapObject)?:
            return map.add(mapObject: mapObject)
        case .setConfiguration(let configuration)?:
            return map.set(configuration: configuration)
        case .setCenter(let center)?:
            return map.set(center: center)
        default:break
        }
        return nil
    }

    private func invoke(replay: FlutterHereMaps_MapChannelReplay) -> Any? {
        switch replay.object {
        case .getCenter(_)?:
            return map.getCenter()
        default:
            break
        }
        return nil
    }
}

protocol FlutterHereMapView : class {
    func set(center: FlutterHereMaps_MapCenter);
    func set(configuration: FlutterHereMaps_Configuration)
    func add(mapObject: FlutterHereMaps_MapObject)
    func getCenter() -> FlutterHereMaps_MapCenter
}

extension NMAMapView : FlutterHereMapView {

// MARK -MapObjects

    internal func add(mapObject: FlutterHereMaps_MapObject) {
        switch mapObject.object {
        case .marker(let marker)?: self.add(mapMarker: marker)
        default: break
        }
    }

    private func add(mapMarker: FlutterHereMaps_MapMarker) {
        let hereMapMarker = NMAMapMarker(geoCoordinates: mapMarker.coordinate.toGeo())
        if let image = UIImage(named: "AppIcon") {
            hereMapMarker.icon = NMAImage(uiImage: image)
        }
        self.add(mapObject: hereMapMarker)
    }

    internal func set(configuration: FlutterHereMaps_Configuration) {
        self.isTrafficVisible = configuration.trafficVisible;
        self.positionIndicator.isVisible = configuration.positionIndicator.isVisible.value;
        self.positionIndicator.isAccuracyIndicatorVisible = configuration.positionIndicator.isAccuracyIndicatorVisible.value;
    }

    internal func set(center: FlutterHereMaps_MapCenter) {

        if center.hasZoomLevel {
            self.set(zoomLevel: center.zoomLevel.value, animation: .none);
        }

        if center.hasTilt {
            self.set(tilt: center.tilt.value, animation: .none);
        }

        if center.hasOrientation {
            self.set(orientation: center.orientation.value, animation: .none);
        }

        if center.hasCoordinate {
            self.set(geoCenter: NMAGeoCoordinates(latitude: center.coordinate.lat, longitude: center.coordinate.lng), animation: .none)
        }
    }

    internal func getCenter() -> FlutterHereMaps_MapCenter {
        var center = FlutterHereMaps_MapCenter()
        var coordinate = FlutterHereMaps_Coordinate()
        coordinate.lat = self.geoCenter.latitude
        coordinate.lng = self.geoCenter.longitude
        center.coordinate = coordinate
        var zoomLevel = FlutterHereMaps_FloatValue()
        zoomLevel.value = self.zoomLevel
        center.zoomLevel = zoomLevel
        var orientation = FlutterHereMaps_FloatValue()
        orientation.value = self.orientation
        center.orientation = orientation
        var tilt = FlutterHereMaps_FloatValue()
        tilt.value = self.tilt
        center.tilt = tilt
        return center
    }
}
