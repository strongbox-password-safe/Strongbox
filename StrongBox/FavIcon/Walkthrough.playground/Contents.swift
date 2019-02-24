//: # FavIcon
//: Welcome to the introduction for the FavIcon library. I hope you find it useful and easy to use.
//: I'll walk you through the various usage scenarios.
//:
//: *Important:* You'll need Internet access to get the most out of this playground.
//:
//: First, you need to import `FavIcon` to pull in the library into the current file.
import FavIcon
//: We'll use `downloadPreferred(url:width:height:completion:)` first, which tries to download the "best" icon.
//: If you know the size you want, you can provide values for the optional `width` and `height` parameters,
//: and the icon closest to that width and height will be downloaded. Of course, if the website does not have
//: many icons to choose from, you may not get the size you desire.
//:
//: Since downloads happen asynchronously, you need to provide a closure that will get
//: called when the downloading is finished. This closure will be called on the main queue, so you can safely
//: touch the UI inside of it.
try FavIcon.downloadPreferred("https://apple.com") { result in
//: The `result` parameter passed to the closure is a `DownloadResultType`.
//: This is a Swift enum type that will be `.Success` or `.Failure`.
    switch result {
    case let .success(image):
//: In the case of success, the associated value is a `UIImage` on iOS (or a `NSImage` on OS X).
//: Expand the details for the icon variable in the result view on the right to see the downloaded icon 👍
        let icon = image
    case let .failure(error):
//: Hmm, this should not have executed. Do you have Internet connectivity? 🤔
        print("failed - \(error)")
    }
}

//: If you want to download all detected icons (maybe you like collecting them), call
//: `downloadAll(url:completion:)`.
try FavIcon.downloadAll("https://microsoft.com") { results in
    let numberOfIcons = results.count
    for (index, result) in results.enumerated() {
        if case let .success(image) = result {
            let icon = image
        }
    }
}

//: If you just want to know which icons are available, you can use the `scan(url:completion:)` method instead.
//: Note that the width and height of the icons are not always available at time of scanning, since some
//: methods of declaring icons don't require specifying icon width and height.
FavIcon.scan(URL(string: "https://google.com")!) { icons in
    for icon in icons {
        let details = "icon: \(icon.url), type \(icon.type), width: \(icon.width), height: \(icon.height)"

//: If one is to your liking, you can download it using `download(url:completion:)`.
        FavIcon.download([icon]) { results in
            for result in results {
                if case let .success(image) = result {
                    let icon = image
                }
            }
        }
    }
}




//: That's it. Good luck, have fun!














//: You don't actually need the next two lines when you're using this library, they're just here so
//: that network requests get a chance to execute when inside a playground.
import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true
