# Strongbox Password Safe
A Personal Password Manager for iOS & OSX that can be found on the Apple App Store here: 

https://itunes.apple.com/us/app/strongbox-password-safe/id897283731

Strongbox supports the open source Password Safe (version 3) and KeePass file formats (KeePass 1 and 2, i.e. KDB, KDBX (3.1 and 4)). Strongbox uses open source encryption algoritms likes TwoFish, Argon2d, ChaCha20, Aes, Salsa20 and various other cryptographic techniques (SHA256s, HMACs, CSPRNGs) to store groups and entries, containing various secrets, mostly designed around password storage. You can also store File Attachments in KeePass format safes.

# Supporting Development through Patreon
If you like the app and are feeling generous you can help by contributing financially on Patreon here:

https://www.patreon.com/strongboxpasswordsafe

Obviously the more support I get here the more time I can allocate to development, I rely on the community to support the work as in-app purchases are a one off payment and just about cover Apple's yearly developer program fee. If you can chip in the price of a cup of coffee every month I'd be very grateful.

# Build Issues
The code is provided here for reasons of security, transparency and openness. Anyone can view the code and verify that everything is above board, the algorithms are correct and there are no backdoors or other malicious features present. You will need Google Drive, OneDrive and Dropbox developer accounts (with keys/secrets) before building. Familiarity with Cocoapods and other build tools is a prerequisite. Please do not file issues about build issues, I can't guarantee what is here will build in your environment. If instead of examining the code, you simply want to use the app, please download from the App Store, the free version is more than functional. Lastly, if you are attempting to bypass built-in Pro/Free limitations for your own app usage, please consider your actions, and consider supporting further development by contributing via the official application (in app purchase upgrade). It will be very much appreciated. If you need all the Pro features and cannot afford the in app purchase upgrade, just drop me a mail and I'll help you out.

# Licence Notes
This software is licensed under the GNU AGPL by default. If you are interested in using the code in some other fashion, or require an alternative licence then please contact me directly: mark.mcguill@gmail.com.

# Acknowledgements
The crypto is mostly from TomCrypt and libsodium. PasswordSafe & KeePass DB parsing/navigation/UI/Cloud interaction is my own work. 

The official PasswordSafe github repository is here:

https://github.com/pwsafe

Kudos to Rony Shapiro, Bruce Schneier and all the Password Safe team for their amazing work and the original Password Safe format and applicaiton.

The official KeePass site is here:

https://keepass.info/

Kudos to Dominik Reichl and all the KeePass team for their incredible technical skill, for coming up with a great format, and their seminal KeePass app. 

I use many different libraries in the app here are just a few:

- Dropbox-iOS-SDK
- Google-API-Client
- JNKeychain
- SVProgressHUD
- Reachability
- ISMessages
- libsodium
- DZNEmptyDataSet
- XWSI
- DAVKit
- NMSSH
- FavIcon 
