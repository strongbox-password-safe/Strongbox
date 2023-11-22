# Strongbox
A Personal Password Manager for iOS & OSX that can be found on the Apple App Store here: 

https://apps.apple.com/app/strongbox-password-safe/id897283731

Strongbox supports the open source Password Safe (version 3) and KeePass file formats (KeePass 1 and 2, i.e. KDB, KDBX (3.1 and 4)). Strongbox uses open source encryption algoritms likes TwoFish, Argon2d, ChaCha20, Aes, Salsa20 and various other cryptographic techniques (SHA256s, HMACs, CSPRNGs) to store groups and entries, containing various secrets, mostly designed around password storage. You can also store File Attachments in KeePass format safes. YubiKey is also supported!

# Localization - Help Wanted
If you would like to see Strongbox translated into your language just get in touch (support@strongboxsafe.com) and we'll get you access to our localization platform. Localization and translation is managed through the parallel Babel project. This is managed under the MIT licence to avoid issues with the Apple's App Store and ownership:

https://github.com/strongbox-password-safe/babel

Big thank you to all the localization contributors

- Chinese - GY & Attis & Anonymous
- Czech - S474N
- Dutch - Wishes to remain anonymous
- French - Charles-Ivan Chesneau
- German - @Slummi
- Greek - John Spiropoulos
- Italian - Marco Ermini
- Japanese - Anonymous
- Norwegian - Ole Aldric
- Polish - Łukasz Oryński
- Portuguese (PT-BR) - Wolfgang Marcos
- Russian - Wishes to remain anonymous
- Spanish - Wishes to remain anonymous
- Swedish - Jari Häkkinen
- Turkish - evreka
- Ukrainian - Artem Polivanchuk

# Beta Testers Wanted
If you'd like to beta test new versions of Strongbox before they are released to the general public please just email support@strongboxsafe.com. You'll need to be fairly technically competent and have a good backup process in place (just in case).

# License Notes (AGPL)
This software provided here on Github is licensed under the GNU AGPL by default, except for translations of Strings files which are managed under the MIT Licence in the Babel sub project. Copyright/Ownership is held by Mark McGuill. Strongbox is licensed to Apple under a different license which is compatible with the App Store.

If you are interested in using the code, commercially, or in some other fashion for which the GPL is unsuitable, or if you would simply like to discuss an alternative licence or custom builds for your organization, then please get in touch.

# Supporting Development
There are several ways you can help support continuous development. 

### App Store Purchase
Obviously if you purchase a subscription or lifetime licence Apple's App Stores that's really helpful. 

### Leave a Review
If you like the app, you can always help out by leaving a *5 star review* in the App Store(s) (Apple, Mozilla or Google's stores). This is very helpful, and helps get the word out about Strongbox. If you can, please leave a positive comment too. You can review the App on Apple here:

Apple App Store: https://apps.apple.com/app/strongbox-password-safe/id897283731
Chrome/Chromium: https://chrome.google.com/webstore/detail/strongbox-autofill/mnilpkfepdibngheginihjpknnopchbn
Firefox: https://addons.mozilla.org/firefox/addon/strongbox-autofill/

# Help / Tech Support
If you're having trouble, please checkout the following sources:

- [Online Support](https://strongboxsafe.com/support/) 
- [Twitter @StrongboxSafe](https://twitter.com/StrongboxSafe "@StrongboxSafe") 
- [Reddit r/strongbox](https://www.reddit.com/r/strongbox/ "r/strongbox")

Another important step is to restart your device, it's surprising how often this can fix issues. If you are having iCloud trouble, then signing in and out of iCloud/iCloud Drive can help.

# Build Issues
The code is provided here in the spirit of transparency, security and openness. Anyone can view the code and verify that everything is above board, the algorithms are correct and there are no backdoors or other malicious features present. Please do not file issues about build trouble or problems. What is here is all of the functional code used in building Strongbox Browser AutoFill, other non functional files (e.g. artwork, images, auxilliary and build configs) are not present. Translation strings files are managed in the separate Babel repository. You will need Google Drive, OneDrive and Dropbox developer accounts (with keys/secrets) before building. Familiarity with Cocoapods and other build tools is a prerequisite.

If instead of examining the code, you simply want to use the app, please download from the App Store, the free version is more than functional. Lastly, if you are attempting to bypass built-in Pro/Free limitations for your own app usage, we would ask you to keep that app to yourself and not distribute it. Also, please consider your actions, and consider supporting further development by contributing via a license purchase.

# Open Source not Open Contribution
At the moment, we are not accepting pull requests and do not want to manage contributions from others. The code here is under the AGPL which Apple will not allow in the App Store. The code is provided here in the spirit of transparency, security and openness. We licence the code to Apple separately under a different license which is compatible with the App Store.

# Acknowledgements
The crypto is mostly from TomCrypt and libsodium. PasswordSafe & KeePass DB parsing/navigation/UI/Cloud interaction is our own work. 

The official PasswordSafe github repository is here:

https://github.com/pwsafe

Kudos to Rony Shapiro, Bruce Schneier and all the Password Safe team for their amazing work and the original Password Safe format and application.

The official KeePass site is here:

https://keepass.info/

Kudos to Dominik Reichl and all the KeePass team for their incredible technical skill, for coming up with a great format, and their seminal KeePass app. 

Hats off to the KeePassXC team for their fantastic cross platform apps. 

https://keepassxc.org/

** Have I Been Pwned **
The ['Have I Been Pwned?'](https://haveibeenpwned.com/) service is provided by Troy Hunt. Strongbox uses the Pwned Passwords API there. Many thanks for some amazing work. Please consider donating to him to keep the service running [here](https://haveibeenpwned.com/Donate).

** zxcvbn Password Strength by Dan Wheeler **
You can read more about this library [here](https://dropbox.tech/security/zxcvbn-realistic-password-strength-estimation). Strongbox uses the C port by tsyrogit [here](https://github.com/tsyrogit/zxcvbn-c). The original CoffeeScript version by Dan Wheeler is available [here](https://github.com/dropbox/zxcvbn). 

** Diceware Wordlists **
Major credit to Sam Schlinkert and his fantastic [Orchard Street Wordlists](https://github.com/sts10/orchard-street-wordlists) project. Sam has been super helpful in pointing out various issues and suggesting corrections to our wordlists. Thanks Sam! Also, credit to Aaron Toponce for his "Fandom" wordlists which improve upon the EFF Fandom lists.

** Various Libraries **
We use many different libraries in the app here are just a few, many thanks to all involved:

- Dropbox-iOS-SDK
- Google-API-Client
- SVProgressHUD
- Reachability
- ISMessages
- libsodium
- DAVKit
- NMSSH
- FavIcon 
- KSPasswordField
- RMStore (https://github.com/robotmedia/RMStore)
- GZIP (https://github.com/nicklockwood/GZIP)
- TPKeyboardAvoiding (https://github.com/michaeltyson/TPKeyboardAvoiding)
- StaticDataTableViewController (https://github.com/peterpaulis/StaticDataTableViewController)
- Diceware Wordlists: (https://github.com/micahflee/passphrases)
- GCDWebServer (https://github.com/swisspol/GCDWebServer)
- NameDatabases (https://github.com/smashew/NameDatabases)
- WSTagsField (https://github.com/whitesmith/WSTagsField)
- Common Passwords List from https://github.com/danielmiessler/SecLists
- Finnish & Icelandic diceware word lists - SmirGel
- OTPAuth - https://github.com/hectorm/otpauth
- SwiftDomainParser - https://github.com/Dashlane/SwiftDomainParser
- cmark-gfm - https://github.com/github/cmark-gfm
- libcmark_gfm - https://github.com/KristopherGBaker/libcmark_gfm
- highlight.js - https://github.com/highlightjs/highlight.js 
- github-markdown-css - https://github.com/sindresorhus/github-markdown-css
