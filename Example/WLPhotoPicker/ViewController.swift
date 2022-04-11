//
//  ViewController.swift
//  WLPhotoPicker
//
//  Created by Weang on 01/18/2022.
//  Copyright (c) 2022 Weang. All rights reserved.
//

import UIKit
import Eureka
import WLPhotoPicker

class ViewController: FormViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.title = "WLPhotoPicker"
        
        form +++ Section()
        
        <<< LabelRow() { row in
            row.title = "选择图片"
        }.cellSetup { cell, row in
            cell.accessoryType = .disclosureIndicator
        }.onCellSelection { cell, row in
            self.navigationController?.pushViewController(PickerViewController(), animated: true)
        }
        
        <<< LabelRow() { row in
            row.title = "视频压缩"
        }.cellSetup { cell, row in
            cell.accessoryType = .disclosureIndicator
        }
        
    }
    
    
}
