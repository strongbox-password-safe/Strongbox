# FavIcon [![License](https://img.shields.io/badge/license-Apache%202.0-lightgrey.svg)](https://raw.githubusercontent.com/bitserf/FavIcon/master/LICENSE) [![Build Status](https://travis-ci.org/bitserf/FavIcon.svg)](https://travis-ci.org/bitserf/FavIcon) [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage) ![Swift 3.0](https://img.shields.io/badge/Swift-3.0-orange.svg) ![platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20macOS%20-lightgrey.svg)
FavIcon is a tiny Swift library for downloading the favicon representing a website.

Wait, why is a library needed to do this? Surely it's just a simple HTTP GET of
`/favicon.ico`, right? Right?  Well. Go have a read of [this StackOverflow
post](<http://stackoverflow.com/questions/19029342/favicons-best-practices), and
see how you feel afterwards.

This is the Swift 3.0 version of this library, if you are on Swift 2.2, you want release **1.0.9**.

## Quick Start
The project ships with a playground in which you can try it out for yourself.
Just be sure to build the `FavIcon-macOS` target before you try to use the
playground, or you will get an import error when it tries to import the FavIcon
framework.

## Including in your project

1. Add `FavIcon.framework` to the Linked Frameworks and Libraries for your application target.
2. If you're using Carthage, add `FavIcon.framework` to the Input Files for your `carthage copy-frameworks` Build Phase.

## Features
- Detection of `/favicon.ico` if it exists
- Parsing of the HTML at a URL, and scanning for appropriate `<link>` or
  `<meta>` tags that refer to icons using Apple, Google or Microsoft
  conventions.
- Discovery of and parsing of Web Application manifest JSON files to obtain
  lists of icons.
- Discovery of and parsing of Microsoft browser configuration XML files for
  obtaining lists of icons.

Yup. These are all potential ways of indicating that your website has an icon
that can be used in user interfaces. Good work, fellow programmers. 👍

## Reference Documentation

Please see the [documentation reference](http://bitserf.github.io/FavIcon/).

## Usage Example
Perhaps you have a location in your user interface where you want to put
the icon of a website the user is currently visiting?

```swift
try FavIcon.downloadPreferred("https://apple.com") { result in
    if case let .success(image) = result {
      // On iOS, this is a UIImage, do something with it here.
      // This closure will be executed on the main queue, so it's safe to touch
      // the UI here.
    }
}
```

This will detect all of the available icons at the URL, and if it is able to
determine their sizes, it will try to find the icon closest in size to your
desired size, otherwise, it will prefer the largest icon. If it has no idea of
the size of any of the icons, it will prefer the first one it found.

Of course, if this approach is too opaque for you, you can download them all
using `downloadAll(url:completion:)`.

Or perhaps you’d like to take a stab at downloading them yourself at a later
time, choosing which icon you prefer based on your own criteria, in which case
`scan(url:completion:)` will give you information about the detected icons, which
you can feed to `download(url:completion:)` for downloading at your convenience.

## License
Apache 2.0

