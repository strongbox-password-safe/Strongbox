# Strongbox
A Personal Password Manager for iOS & OSX that can be found on the Apple App Store here: 

https://apps.apple.com/app/strongbox-password-safe/id897283731

Strongbox supports the open source Password Safe (version 3) and KeePass file formats (KeePass 1 and 2, i.e. KDB, KDBX (3.1 and 4)). Strongbox uses open source encryption algoritms likes TwoFish, Argon2d, ChaCha20, Aes, Salsa20 and various other cryptographic techniques (SHA256s, HMACs, CSPRNGs) to store groups and entries, containing various secrets, mostly designed around password storage. You can also store File Attachments in KeePass format safes. YubiKey is also supported!

# Beta Testers Wanted
If you'd like to beta test new versions of Strongbox before they are released to the general public please just email support@strongboxsafe.com. You'll need to be fairly technically competent and have a good backup process in place (just in case).

# Localization - Help Wanted
Localization and translation is managed through the parallel Babel project here:

https://github.com/strongbox-password-safe/babel

This is managed under the MIT licence to avoid issues with the Apple's App Store and ownership. There are some efforts underway right now but if you would like to see Strongbox translated into your language just get in touch and we'll try to set you up. Currently we are using Crowd In to manage things and it seems to be working well. Get in touch to get an invite to that system and being work on your language.

You can submit Pull Requests any way you choose, and it will be much appreciated, but please get in touch first so I can make sure the Repo is setup correctly for your language.

Big thank you to all the localization contributors

- Chinese - GY & Attis & Anonymous
- Czech - S474N
- Dutch - Wishes to remain anonymous
- French - Charles-Ivan Chesneau
- German - @Slummi
- Italian - Marco Ermini
- Japanese - Anonymous
- Norwegian - Ole Aldric
- Portuguese (PT-BR) - Wolfgang Marcos
- Russian - Wishes to remain anonymous
- Spanish - Wishes to remain anonymous
- Swedish - Jari Häkkinen
- Ukrainian - Artem Polivanchuk

# License Notes
This software provided here on Github is licensed under the GNU AGPL by default, except for translations of Strings files which are managed under the MIT Licence in the Babel sub project. Copyright/Ownership is held by Mark McGuill. Strongbox is licensed to Apple under a different license which is compatible with the App Store.

If you are interested in using the code, commercially, or in some other fashion for which the GPL is unsuitable, or if you would simply like to discuss an alternative licence or custom builds for your organization, then please get in touch.

# Supporting Development
There are several ways you can help support continuous development. Obviously if you purchase a subscription or lifetime licence that's really helpful. But there are a few other options if you like the app and you are feeling generous... You can help by contributing financially here:

- Patreon: https://www.patreon.com/strongboxpasswordsafe

If you like the app, you can always help out by leaving a *5 star review* in the App Store. This is very helpful, and helps get the word out about Strongbox. If you can, please leave a positive comment too. You can review the App here:

https://apps.apple.com/app/strongbox-password-safe/id897283731

Of course it is also great if you can tell your friends and family about the App, spread the word on Twitter, Reddit or otherwise.

# Help / Tech Support
If you're having trouble, please checkout the following sources:

- [Online Support](https://strongboxsafe.com/support/) 
- [Twitter @StrongboxSafe](https://twitter.com/StrongboxSafe "@StrongboxSafe") 
- [Reddit r/strongbox](https://www.reddit.com/r/strongbox/ "r/strongbox")

Another important step is to restart your device, it's surprising how often this can fix issues. If you are having iCloud trouble, then signing in and out of iCloud/iCloud Drive can help.

# Build Issues
The code is provided here for reasons of security, transparency and openness. Anyone can view the code and verify that everything is above board, the algorithms are correct and there are no backdoors or other malicious features present. You will need Google Drive, OneDrive and Dropbox developer accounts (with keys/secrets) before building. Familiarity with Cocoapods and other build tools is a prerequisite. Please do not file issues about build issues, I can't guarantee what is here will build in your environment. What is here is all of the functional code used in building Strongbox. XCode Interface Builder UI files, XCode project/solution/workspace, and other non functional code files may be removed to hinder copy cat apps. Translation strings files are managed in the separate Babel repository. 

If instead of examining the code, you simply want to use the app, please download from the App Store, the free version is more than functional. Lastly, if you are attempting to bypass built-in Pro/Free limitations for your own app usage, I would ask you to keep that app to yourself and not distribute it. Also, please consider your actions, and consider supporting further development by contributing via the official application (In-App Purchase upgrade). It will be very much appreciated. Finally, if you really need all the Pro features and cannot afford the upgrade, just drop me a mail and I'll help you out.

# Contributions or Pull Requests
I cannot accept outside pull requests from the community for licensing reasons. To release to Apple's App Store I have to manage Strongbox under a dual licence. The code here is under the GPL which Apple will not allow in the App Store. As mentioned above the code is provided here for transparency and openness, something I consider a prerequisite for a Password Manager. I need to maintain full ownership of the code so that I can licence to Apple separately, and also any outside/other licencing that might come along, commercial or otherwise. Accepting contributions (no matter how awesome) would involve the contributer signing their life and probably first born child away... There is probably a way to do this but I believe it will involve legally binding documents and other bureaucracies so to keep things simple I'm just going to manage the development myself. Other people's code sucks anyway, right? 

Sorry... :(

# Acknowledgements
The crypto is mostly from TomCrypt and libsodium. PasswordSafe & KeePass DB parsing/navigation/UI/Cloud interaction is my own work. 

The official PasswordSafe github repository is here:

https://github.com/pwsafe

Kudos to Rony Shapiro, Bruce Schneier and all the Password Safe team for their amazing work and the original Password Safe format and application.

The official KeePass site is here:

https://keepass.info/

Kudos to Dominik Reichl and all the KeePass team for their incredible technical skill, for coming up with a great format, and their seminal KeePass app. 

Hats off to the KeePassXC team for their fantastic cross platform apps. 

https://keepassxc.org/

Another great project is KeeWeb, a fully javascript based client which works cross-platform basically everywhere! Major props to @antelle

https://github.com/keeweb/keeweb
https://keeweb.info/

** Have I Been Pwned **
The ['Have I Been Pwned?'](https://haveibeenpwned.com/) service is provided by Troy Hunt. Strongbox uses the Pwned Passwords API there. Many thanks for some amazing work. Please consider donating to him to keep the service running [here](https://haveibeenpwned.com/Donate).

** zxcvbn Password Strength by Dan Wheeler **
You can read more about this library [here](https://dropbox.tech/security/zxcvbn-realistic-password-strength-estimation). Strongbox uses the C port by tsyrogit [here](https://github.com/tsyrogit/zxcvbn-c). The original CoffeeScript version by Dan Wheeler is available [here](https://github.com/dropbox/zxcvbn). 

I use many different libraries in the app here are just a few:

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
