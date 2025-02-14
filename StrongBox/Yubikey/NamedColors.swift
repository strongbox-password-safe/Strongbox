// Copyright 2018-2019 Yubico AB
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.



import UIKit

func UIColorFrom(hex: Int) -> UIColor {
    let red = CGFloat((hex & 0xFF0000) >> 16) / 255.0
    let green = CGFloat((hex & 0x00FF00) >> 8) / 255.0
    let blue = CGFloat(hex & 0x0000FF) / 255.0

    return UIColor(red: red, green: green, blue: blue, alpha: 1.0)
}

/*
 Provided to mantain compatibility with iOS 10 where named colors cannot be added to the assets catalog.
 */
class NamedColor: NSObject {
    static var yubicoGreenColor = UIColorFrom(hex: 0x9ACA3C)
}
