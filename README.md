# Strongbox
A native Password Manager for iOS & macOS crafted by artisan Indie developers!

https://apps.apple.com/app/strongbox-password-safe/id897283731

Strongbox supports the well-known, portable and open Password Safe (version 3) and KeePass file formats (KeePass 1 and 2, i.e. KDB, KDBX (3.1 and 4)). Strongbox uses encryption algoritms likes TwoFish, Argon2d, ChaCha20, Aes, Salsa20 and various other cryptographic techniques (SHA256s, HMACs, CSPRNGs) to store groups and entries, containing various secrets, mostly designed around password storage. You can also store file attachments in KeePass format safes. YubiKey is also supported.

---

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

---

# Supporting Development
There are several ways you can help support continuous development. 

1. App Store Purchase
Obviously if you purchase a subscription or lifetime licence Apple's App Stores that's really helpful. 

2. Leave a Review
If you like the app, you can always help out by leaving a *5 star review* in the App Store(s) (Apple, Mozilla or Google's stores). This is very helpful, and helps get the word out about Strongbox. If you can, please leave a positive comment too. You can review the App on Apple here:

Apple App Store: https://apps.apple.com/app/strongbox-password-safe/id897283731
Chrome/Chromium: https://chrome.google.com/webstore/detail/strongbox-autofill/mnilpkfepdibngheginihjpknnopchbn
Firefox: https://addons.mozilla.org/firefox/addon/strongbox-autofill/

---

# Help / Tech Support
If you're having trouble, please checkout the following sources:

- [Online Support](https://strongboxsafe.com/support/) 
- [Twitter @StrongboxSafe](https://twitter.com/StrongboxSafe "@StrongboxSafe") 
- [Reddit r/strongbox](https://www.reddit.com/r/strongbox/ "r/strongbox")

Another important step is to restart your device, it's surprising how often this can fix issues. If you are having iCloud trouble, then signing in and out of iCloud/iCloud Drive can help.

---

# Licensing & Building

### On Making Contributions
At the moment, we are not accepting pull requests and do not want to manage contributions from others. The code is provided here in the spirit of transparency, security and openness. 

### On Build Issues
As mentioned above, we do not make our App easy to build from this source code. The code is provided here in the spirit of transparency, security and openness. Anyone can view the code and verify that everything is above board, the algorithms are correct and there are no backdoors or other malicious features present. Please do not file issues about build trouble or problems. What is here is all of the functional code used in building Strongbox, other non functional files (e.g. artwork, images, auxilliary and build configs) are not present. Translation strings files are managed in the separate Babel repository. You will need Google Drive, OneDrive and Dropbox developer accounts (with keys/secrets) before building. Familiarity with Cocoapods and other build tools is a prerequisite.

If instead of examining the code, you simply want to use the app, please download from the App Store, the free version is more than functional. Lastly, if you are attempting to bypass built-in Pro/Free limitations for your own app usage, we would ask you to keep that app to yourself and not distribute it. Also, please consider your actions, and consider supporting further development by contributing via a license purchase.

### Clarification on OSI compliance 
December 3, 2024
Please note this repo are not compliant with the OSI definition of Open Source, because we have never provided an easy way to build our native App directly from this repo for anti-piracy reasons. We do not include some non-code files (images, artwork, build configs, metadata) to make piracy more difficult. Depending on your point of view or stance on the OSI definition as the de facto standard, this means we could be considered proprietary software. Others might use the term "Source Available". However, we still feel there is value in releasing our code to the community and so we make it available here, under whatever label you prefer for that policy. Whereever we can, we will endeavour to release our work publicly and freely while ensuring we can keep running a viable commercial operation, so that we can sustain development. For example, we release our [Browser AutoFill Extension](https://github.com/strongbox-password-safe/browser-autofill) which (we believe) is in fact OSI compliant.

---

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
