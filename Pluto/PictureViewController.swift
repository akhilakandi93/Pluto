//
//  PictureViewController.swift
//  Pluto
//
//  Created by Akhila Kandi on 1/22/18.
//  Copyright © 2018 Akhila Kandi. All rights reserved.
//


import UIKit
import SwiftyJSON

class PictureViewController : UIViewController, UIImagePickerControllerDelegate,
UINavigationControllerDelegate{
    
    
    @IBOutlet var goBack: UIButton!
    
    @IBOutlet var detailPic: UIImageView!
    
    var newPic: UIImage!
    
    @IBOutlet var labelResults: UITextView!
    
    
    @IBOutlet var faceResults: UITextView!
    
    var googleAPIKey = "AIzaSyDzpx0_Q1kqTMRj87DUnEbday8YwhmZY0A"
    var googleURL: URL {
        return URL(string: "https://vision.googleapis.com/v1/images:annotate?key=\(googleAPIKey)")!
    }
    let session = URLSession.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        goBack.layer.cornerRadius = 8
        detailPic.image = newPic
        labelResults.scrollRangeToVisible(NSMakeRange(0, 0))
        faceResults.scrollRangeToVisible(NSMakeRange(0, 0))
        let binaryImageData = base64EncodeImage(detailPic.image!)
        createRequest(with: binaryImageData)
        labelResults.isHidden = false
        faceResults.isHidden = false
        
    }
    
    @IBAction func goBackToHome(_ sender: Any) {
        self.performSegue(withIdentifier: "goHome", sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "goHome" {
            let dvc = segue.destination as! ViewController
            dvc.homePic = detailPic.image
        }
    }
}

extension PictureViewController{
    func analyzeResults(_ dataToParse: Data) {

        DispatchQueue.main.async(execute: {
            
            
            // Use SwiftyJSON to parse results
            let json = JSON(data: dataToParse)
            let errorObj: JSON = json["error"]
            
            self.faceResults.text = ""
            
            // Check for errors
            if (errorObj.dictionaryValue != [:]) {
                self.labelResults.text = "Error code \(errorObj["code"]): \(errorObj["message"])"
            } else {
                // Parse the response
                print(json)
                let responses: JSON = json["responses"][0]
                
                // Get face annotations
                let faceAnnotations: JSON = responses["faceAnnotations"]
                if faceAnnotations != nil {
                    let emotions: Array<String> = ["joy", "sorrow", "surprise", "anger"]
                    
                    let numPeopleDetected:Int = faceAnnotations.count
                    
                    self.faceResults.text = "People detected: \(numPeopleDetected)\n\nEmotions detected:\n"
                    
                    var emotionTotals: [String: Double] = ["sorrow": 0, "joy": 0, "surprise": 0, "anger": 0]
                    var emotionLikelihoods: [String: Double] = ["VERY_LIKELY": 0.9, "LIKELY": 0.75, "POSSIBLE": 0.5, "UNLIKELY":0.25, "VERY_UNLIKELY": 0.0]
                    
                    for index in 0..<numPeopleDetected {
                        let personData:JSON = faceAnnotations[index]
                        
                        // Sum all the detected emotions
                        for emotion in emotions {
                            let lookup = emotion + "Likelihood"
                            let result:String = personData[lookup].stringValue
                            emotionTotals[emotion]! += emotionLikelihoods[result]!
                        }
                    }
                    // Get emotion likelihood as a % and display in UI
                    for (emotion, total) in emotionTotals {
                        let likelihood:Double = total / Double(numPeopleDetected)
                        let percent: Int = Int(round(likelihood * 100))
                        self.faceResults.text! += "\(emotion): \(percent)%\n"
                    }
                } else {
                    self.faceResults.text = "No faces found"
                }
                
                // Get label annotations
                let labelAnnotations: JSON = responses["labelAnnotations"]
                let numLabels: Int = labelAnnotations.count
                var labels: Array<String> = []
                if numLabels > 0 {
                    var labelResultsText:String = "Labels found: "
                    for index in 0..<numLabels {
                        let label = labelAnnotations[index]["description"].stringValue
                        labels.append(label)
                    }
                    for label in labels {
                        // if it's not the last item add a comma
                        if labels[labels.count - 1] != label {
                            labelResultsText += "\(label), "
                        } else {
                            labelResultsText += "\(label)"
                        }
                    }
                    self.labelResults.text = labelResultsText
                } else {
                    self.labelResults.text = "No labels found"
                }
            }
        })

    }
    
    func resizeImage(_ imageSize: CGSize, image: UIImage) -> Data {
        UIGraphicsBeginImageContext(imageSize)
        image.draw(in: CGRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        let resizedImage = UIImagePNGRepresentation(newImage!)
        UIGraphicsEndImageContext()
        return resizedImage!
    }

}

extension PictureViewController {
    func base64EncodeImage(_ image: UIImage) -> String {
        var imagedata = UIImagePNGRepresentation(image)
        
        // Resize the image if it exceeds the 2MB API limit
        if ((imagedata?.count)! > 2097152) {
            let oldSize: CGSize = image.size
            let newSize: CGSize = CGSize(width: 800, height: oldSize.height / oldSize.width * 800)
            imagedata = resizeImage(newSize, image: image)
        }
        
        return imagedata!.base64EncodedString(options: .endLineWithCarriageReturn)
    }
    
    func createRequest(with imageBase64: String) {
        // Create our request URL
        
        var request = URLRequest(url: googleURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(Bundle.main.bundleIdentifier ?? "", forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        
        // Build our API request
        let jsonRequest = [
            "requests": [
                "image": [
                    "content": imageBase64
                ],
                "features": [
                    [
                        "type": "LABEL_DETECTION",
                        "maxResults": 10
                    ],
                    [
                        "type": "FACE_DETECTION",
                        "maxResults": 10
                    ]
                ]
            ]
        ]
        let jsonObject = JSON(jsonDictionary: jsonRequest)
        
        // Serialize the JSON
        guard let data = try? jsonObject.rawData() else {
            return
        }
        request.httpBody = data
        
        // Run the request on a background thread
        DispatchQueue.global().async { self.runRequestOnBackgroundThread(request) }
    }
    
    func runRequestOnBackgroundThread(_ request: URLRequest) {
        // run the request
        
        let task: URLSessionDataTask = session.dataTask(with: request) { (data, response, error) in
            guard let data = data, error == nil else {
                print(error?.localizedDescription ?? "")
                return
            }
            
            self.analyzeResults(data)
        }
        
        task.resume()
    }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l < r
    case (nil, _?):
        return true
    default:
        return false
    }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l > r
    default:
        return rhs < lhs
    }
}



