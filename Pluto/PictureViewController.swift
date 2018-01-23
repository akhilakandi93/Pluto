//
//  PictureViewController.swift
//  Pluto
//
//  Created by Akhila Kandi on 1/22/18.
//  Copyright © 2018 Akhila Kandi. All rights reserved.
//


import UIKit

class PictureViewController : UIViewController, UIImagePickerControllerDelegate,
UINavigationControllerDelegate{
    
    
    @IBOutlet var goBack: UIButton!
    
    @IBOutlet var detailPic: UIImageView!
    
    var newPic: UIImage!
    override func viewDidLoad() {
        super.viewDidLoad()
        goBack.layer.cornerRadius = 8
        detailPic.image = newPic
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
