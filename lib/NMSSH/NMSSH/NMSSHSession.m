#import "NMSSHSession.h"
#import "NMSSH+Protected.h"
#import "NMSSHConfig.h"
#import "NMSSHHostConfig.h"

@interface NMSSHSession ()
@property (nonatomic, assign) LIBSSH2_AGENT *agent;

@property (nonatomic, assign, getter = rawSession) LIBSSH2_SESSION *session;
@property (nonatomic, readwrite, getter = isConnected) BOOL connected;
@property (nonatomic, strong) NSString *host;
@property (nonatomic, strong) NSString *username;

@property (nonatomic, copy) NSString *(^kbAuthenticationBlock)(NSString *);

@property (nonatomic, strong) NMSSHChannel *channel;
@property (nonatomic, strong) NMSFTP *sftp;
@property (nonatomic, strong) NSNumber *port;
@property (nonatomic, strong) NMSSHHostConfig *hostConfig;
@property (nonatomic, assign) LIBSSH2_SESSION *sessionToFree;
@end

@implementation NMSSHSession

// -----------------------------------------------------------------------------
#pragma mark - INITIALIZE A NEW SSH SESSION
// -----------------------------------------------------------------------------

+ (instancetype)connectToHost:(NSString *)host port:(NSInteger)port withUsername:(NSString *)username {
    NMSSHSession *session = [[NMSSHSession alloc] initWithHost:host
                                                          port:port
                                                   andUsername:username];
    [session connect];

    return session;
}

+ (instancetype)connectToHost:(NSString *)host withUsername:(NSString *)username {
    NMSSHSession *session = [[NMSSHSession alloc] initWithHost:host
                                                   andUsername:username];
    [session connect];

    return session;
}

- (instancetype)initWithHost:(NSString *)host port:(NSInteger)port andUsername:(NSString *)username {
    if ((self = [super init])) {
        [self setHost:host];
        [self setPort:@(port)];
        [self setUsername:username];
        [self setConnected:NO];
        [self setFingerprintHash:NMSSHSessionHashMD5];
    }

    return self;
}

- (instancetype)initWithHost:(NSString *)host
                     configs:(NSArray *)configs
             withDefaultPort:(NSInteger)defaultPort
             defaultUsername:(NSString *)defaultUsername {
    // Merge matching entries from configs together.
    NMSSHHostConfig *hostConfig = [[NMSSHHostConfig alloc] init];
    for (NMSSHConfig *config in configs) {
        NMSSHHostConfig *matchingHostConfig = [config hostConfigForHost:host];
        if (matchingHostConfig) {
            [hostConfig mergeFrom:matchingHostConfig];
        }
    }

    // Merge in defaults.
    NMSSHHostConfig *defaultHostConfig = [[NMSSHHostConfig alloc] init];
    [defaultHostConfig setHostname:host];
    [defaultHostConfig setPort:@(defaultPort)];
    [defaultHostConfig setUser:defaultUsername];
    [hostConfig mergeFrom:defaultHostConfig];

    // Initialize with resulting config.
    self = [self initWithHost:hostConfig.hostname
                         port:[hostConfig.port integerValue]
                  andUsername:hostConfig.user];
    if (self) {
        [self setHostConfig:hostConfig];
    }

    return self;
}

- (instancetype)initWithHost:(NSString *)host andUsername:(NSString *)username {
    NSURL *url = [[self class] URLForHost:host];
    return [self initWithHost:[url host]
                         port:[([url port] ?: @22) intValue]
                  andUsername:username];
}

+ (NSURL *)URLForHost:(NSString *)host {
    // Check if host is IPv6 and wrap in square brackets.
    if ([[host componentsSeparatedByString:@":"] count] >= 3 &&
        ![host hasPrefix:@"["]) {
        host = [NSString stringWithFormat:@"[%@]", host];
    }

    return [NSURL URLWithString:[@"ssh://" stringByAppendingString:host]];
}

- (void)dealloc {
    if (self.sessionToFree) {
        libssh2_session_free(self.sessionToFree);
    }
}

// -----------------------------------------------------------------------------
#pragma mark - CONNECTION SETTINGS
// -----------------------------------------------------------------------------

- (NSArray *)hostIPAddresses {
    NSArray *hostComponents = [_host componentsSeparatedByString:@":"];
    NSInteger components = [hostComponents count];
    NSString *address = hostComponents[0];

    // Check if the host is [{IPv6}]:{port}
    if (components >= 4 && [hostComponents[0] hasPrefix:@"["] && [hostComponents[components-2] hasSuffix:@"]"]) {
        address = [_host substringWithRange:NSMakeRange(1, [_host rangeOfString:@"]" options:NSBackwardsSearch].location-1)];
    } // Check if the host is {IPv6}
    else if (components >= 3) {
        address = _host;
    }

    CFHostRef host = CFHostCreateWithName(kCFAllocatorDefault, (__bridge CFStringRef)address);
    CFStreamError error;
    NSArray *addresses = nil;

    if (host) {
        NMSSHLogVerbose(@"Start %@ resolution", address);

        if (CFHostStartInfoResolution(host, kCFHostAddresses, &error)) {
            addresses = (__bridge NSArray *)(CFHostGetAddressing(host, NULL));
        }
        else {
            NMSSHLogError(@"Unable to resolve host %@", address);
        }

        CFRelease(host);
    }
    else {
        NMSSHLogError(@"Error allocating CFHost for %@", address);
    }

    return addresses;
}

- (NSNumber *)timeout {
    if (self.session) {
        return @(libssh2_session_get_timeout(self.session) / 1000);
    }

    return @0;
}

- (void)setTimeout:(NSNumber *)timeout {
    if (self.session) {
        libssh2_session_set_timeout(self.session, [timeout longValue] * 1000);
    }
}

- (NSError *)lastError {
    if(!self.rawSession) {
        return [NSError errorWithDomain:@"libssh2" code:LIBSSH2_ERROR_NONE userInfo:@{NSLocalizedDescriptionKey : @"Error retrieving last session error due to absence of an active session."}];
    }
    
    char *message;
    int error = libssh2_session_last_error(self.rawSession, &message, NULL, 0);

    return [NSError errorWithDomain:@"libssh2"
                               code:error
                           userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithUTF8String:message] }];
}

- (NSString *)remoteBanner {
    const char *banner = libssh2_session_banner_get(self.session);

    if (!banner) {
        return nil;
    }

    return [[NSString alloc] initWithCString:banner encoding:NSUTF8StringEncoding];
}

// -----------------------------------------------------------------------------
#pragma mark - OPEN/CLOSE A CONNECTION TO THE SERVER
// -----------------------------------------------------------------------------

- (BOOL)connect {
    return [self connectWithTimeout:[NSNumber numberWithLong:10]];
}

- (BOOL)connectWithTimeout:(NSNumber *)timeout {
    if (self.isConnected) {
        [self disconnect];
    }

    __block BOOL initialized = YES;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Try to initialize libssh2
        if (libssh2_init(0) != 0) {
            NMSSHLogError(@"libssh2 initialization failed");
            initialized = NO;
        }

        NMSSHLogVerbose(@"libssh2 (v%s) initialized", libssh2_version(0));
    });

    if (!initialized) {
        return NO;
    }
    // Try to establish a connection to the server
    NSUInteger index = -1;
    NSInteger port = [self.port integerValue];
    NSArray *addresses = [self hostIPAddresses];
    CFSocketError error = 1;
    CFDataRef address = NULL;
    SInt32 addressFamily;

    while (addresses && ++index < [addresses count] && error) {
        NSData *addressData = addresses[index];
        NSString *ipAddress;

        // IPv4
        if ([addressData length] == sizeof(struct sockaddr_in)) {
            struct sockaddr_in address4;
            [addressData getBytes:&address4 length:sizeof(address4)];
            address4.sin_port = htons(port);

            char str[INET_ADDRSTRLEN];
            inet_ntop(AF_INET, &(address4.sin_addr), str, INET_ADDRSTRLEN);
            ipAddress = [NSString stringWithCString:str encoding:NSUTF8StringEncoding];
            addressFamily = AF_INET;
            address = CFDataCreate(kCFAllocatorDefault, (UInt8 *)&address4, sizeof(address4));
        } // IPv6
        else if([addressData length] == sizeof(struct sockaddr_in6)) {
            struct sockaddr_in6 address6;
            [addressData getBytes:&address6 length:sizeof(address6)];
            address6.sin6_port = htons(port);

            char str[INET6_ADDRSTRLEN];
            inet_ntop(AF_INET6, &(address6.sin6_addr), str, INET6_ADDRSTRLEN);
            ipAddress = [NSString stringWithCString:str encoding:NSUTF8StringEncoding];
            addressFamily = AF_INET6;
            address = CFDataCreate(kCFAllocatorDefault, (UInt8 *)&address6, sizeof(address6));
        }
        else {
            NMSSHLogVerbose(@"Unknown address, it's not IPv4 or IPv6!");
            continue;
        }
        
        // Try to create the socket
        _socket = CFSocketCreate(kCFAllocatorDefault, addressFamily, SOCK_STREAM, IPPROTO_IP, kCFSocketNoCallBack, NULL, NULL);
        if (!_socket) {
            NMSSHLogError(@"Error creating the socket");
            CFRelease(address);
            return NO;
        }
        
        // Set NOSIGPIPE
        int set = 1;
        if (setsockopt(CFSocketGetNative(_socket), SOL_SOCKET, SO_NOSIGPIPE, (void *)&set, sizeof(set)) != 0) {
            NMSSHLogError(@"Error setting socket option");
            CFRelease(address);
            [self disconnect];
            return NO;
        }
        
        error = CFSocketConnectToAddress(_socket, address, [timeout doubleValue]);
        CFRelease(address);

        if (error) {
            NMSSHLogVerbose(@"Socket connection to %@ on port %ld failed with reason %li, trying next address...", ipAddress, (long)port, error);
        }
        else {
            NMSSHLogInfo(@"Socket connection to %@ on port %ld succesful", ipAddress, (long)port);
        }
    }

    if (error) {
        NMSSHLogError(@"Failure establishing socket connection");
        [self disconnect];

        return NO;
    }

    // Create a session instance
    [self setSession:libssh2_session_init_ex(NULL, NULL, NULL, (__bridge void *)(self))];

    // Set a callback for disconnection
    libssh2_session_callback_set(self.session, LIBSSH2_CALLBACK_DISCONNECT, &disconnect_callback);

    // Set blocking mode
    libssh2_session_set_blocking(self.session, 1);

    // Set the custom banner
    if (self.banner && libssh2_session_banner_set(self.session, [self.banner UTF8String])) {
        NMSSHLogError(@"Failure setting the banner");
    }

    // Start the session
    if (libssh2_session_handshake(self.session, CFSocketGetNative(_socket))) {
        NMSSHLogError(@"Failure establishing SSH session");
        [self disconnect];

        return NO;
    }

    NMSSHLogVerbose(@"Remote host banner is %@", [self remoteBanner]);

    // Get the fingerprint of the host
    NSString *fingerprint = [self fingerprint:self.fingerprintHash];
    NMSSHLogInfo(@"The host's fingerprint is %@", fingerprint);

    if (self.delegate && [self.delegate respondsToSelector:@selector(session:shouldConnectToHostWithFingerprint:)] &&
        ![self.delegate session:self shouldConnectToHostWithFingerprint:fingerprint]) {
        NMSSHLogWarn(@"Fingerprint refused, aborting connection...");
        [self disconnect];

        return NO;
    }

    NMSSHLogVerbose(@"SSH session started");

    // We managed to successfully setup a connection
    [self setConnected:YES];

    return self.isConnected;
}


- (void)disconnect {
    if (_channel) {
        [_channel closeShell];
        [self setChannel:nil];
    }

    if (_sftp) {
        if ([_sftp isConnected]) {
            [_sftp disconnect];
        }
        [self setSftp:nil];
    }

    if (self.agent) {
        libssh2_agent_disconnect(self.agent);
        libssh2_agent_free(self.agent);
        [self setAgent:NULL];
    }

    if (self.session) {
        libssh2_session_disconnect(self.session, "NMSSH: Disconnect");
        [self setSessionToFree:self.session];
        [self setSession:NULL];
    }

    if (_socket) {
        CFSocketInvalidate(_socket);
        CFRelease(_socket);
        _socket = NULL;
    }

    NMSSHLogVerbose(@"Disconnected");
    [self setConnected:NO];
}

// -----------------------------------------------------------------------------
#pragma mark - AUTHENTICATION
// -----------------------------------------------------------------------------

- (BOOL)isAuthorized {
    if (self.session) {
        return libssh2_userauth_authenticated(self.session) == 1;
    }

    return NO;
}

- (BOOL)authenticateByPassword:(NSString *)password {

    if (!password) {
        return NO;
    }

    if (![self supportsAuthenticationMethod:@"password"]) {
        return NO;
    }

    // Try to authenticate by password
    int error = libssh2_userauth_password(self.session, [self.username UTF8String], [password UTF8String]);
    if (error) {
        NMSSHLogError(@"Password authentication failed with reason %i", error);
        return NO;
    }

    NMSSHLogVerbose(@"Password authentication succeeded.");

    return self.isAuthorized;
}

- (BOOL)authenticateByPublicKey:(NSString *)publicKey
                     privateKey:(NSString *)privateKey
                    andPassword:(NSString *)password {
    if (![self supportsAuthenticationMethod:@"publickey"]) {
        return NO;
    }

    if (password == nil) {
        password = @"";
    }

    // Get absolute paths for private/public key pair
    const char *pubKey = [[publicKey stringByExpandingTildeInPath] UTF8String] ?: NULL;
    const char *privKey = [[privateKey stringByExpandingTildeInPath] UTF8String] ?: NULL;

    // Try to authenticate with key pair and password
    int error = libssh2_userauth_publickey_fromfile(self.session,
                                                    [self.username UTF8String],
                                                    pubKey,
                                                    privKey,
                                                    [password UTF8String]);

    if (error) {
        NMSSHLogError(@"Public key authentication failed with reason %i", error);
        return NO;
    }

    NMSSHLogVerbose(@"Public key authentication succeeded.");

    return self.isAuthorized;
}

- (BOOL)authenticateByInMemoryPublicKey:(NSString *)publicKey
                             privateKey:(NSString *)privateKey
                            andPassword:(NSString *)password {
    if (![self supportsAuthenticationMethod:@"publickey"]) {
        return NO;
    }

    if (password == nil) {
        password = @"";
    }

    // Try to authenticate with key pair and password
    int error = libssh2_userauth_publickey_frommemory(self.session,
                                                    [self.username UTF8String],
                                                    [self.username length],
                                                    [publicKey UTF8String] ?: nil,
                                                    [publicKey length] ?: 0,
                                                    [privateKey UTF8String] ?: nil,
                                                    [privateKey length] ?: 0,
                                                    [password UTF8String]);

    if (error) {
        NMSSHLogError(@"Public key authentication failed with reason %i", error);
        return NO;
    }

    NMSSHLogVerbose(@"Public key authentication succeeded.");

    return self.isAuthorized;
}

- (BOOL)authenticateByKeyboardInteractive {
    return [self authenticateByKeyboardInteractiveUsingBlock:nil];
}

- (BOOL)authenticateByKeyboardInteractiveUsingBlock:(NSString *(^)(NSString *request))authenticationBlock {
    if (![self supportsAuthenticationMethod:@"keyboard-interactive"]) {
        return NO;
    }

    self.kbAuthenticationBlock = authenticationBlock;
    int rc = libssh2_userauth_keyboard_interactive(self.session, [self.username UTF8String], &kb_callback);
    self.kbAuthenticationBlock = nil;

    if (rc != 0) {
        NMSSHLogError(@"Keyboard-interactive authentication failed with reason %i", rc);
        return NO;
    }

    NMSSHLogVerbose(@"Keyboard-interactive authentication succeeded.");

    return self.isAuthorized;
}

- (BOOL)connectToAgent {
    if (![self supportsAuthenticationMethod:@"publickey"]) {
        return NO;
    }

    // Try to setup a connection to the SSH-agent
    [self setAgent:libssh2_agent_init(self.session)];
    if (!self.agent) {
        NMSSHLogError(@"Could not start a new agent");
        return NO;
    }

    // Try connecting to the agent
    if (libssh2_agent_connect(self.agent)) {
        NMSSHLogError(@"Failed connection to agent");
        return NO;
    }

    // Try to fetch available SSH identities
    if (libssh2_agent_list_identities(self.agent)) {
        NMSSHLogError(@"Failed to request agent identities");
        return NO;
    }

    // Search for the correct identity and try to authenticate
    struct libssh2_agent_publickey *identity, *prev_identity = NULL;
    while (1) {
        int error = libssh2_agent_get_identity(self.agent, &identity, prev_identity);
        if (error) {
            NMSSHLogError(@"Failed to find a valid identity for the agent");
            return NO;
        }

        error = libssh2_agent_userauth(self.agent, [self.username UTF8String], identity);
        if (!error) {
            return self.isAuthorized;
        }

        prev_identity = identity;
    }

    return NO;
}

- (NSArray *)supportedAuthenticationMethods {
    if (!self.session) {
        return nil;
    }
    
    char *userauthlist = libssh2_userauth_list(self.session, [self.username UTF8String],
                                               (unsigned int)strlen([self.username UTF8String]));
    if (userauthlist == NULL){
        NMSSHLogInfo(@"Failed to get authentication method for host %@:%@", self.host, self.port);
        return nil;
    }

    NSString *authList = [NSString stringWithCString:userauthlist encoding:NSUTF8StringEncoding];
    NMSSHLogVerbose(@"User auth list: %@", authList);

    return [authList componentsSeparatedByString:@","];
}

- (BOOL)supportsAuthenticationMethod:(NSString *)method {
    return [[self supportedAuthenticationMethods] containsObject:method];
}

- (NSString *)fingerprint:(NMSSHSessionHash)hashType {
    if (!self.session) {
        return nil;
    }

    int libssh2_hash, hashLength;
    switch (hashType) {
        case NMSSHSessionHashMD5:
            libssh2_hash = LIBSSH2_HOSTKEY_HASH_MD5;
            hashLength = 16;
            break;

        case NMSSHSessionHashSHA1:
            libssh2_hash = LIBSSH2_HOSTKEY_HASH_SHA1;
            hashLength = 20;
            break;
    }

    const char *hash = libssh2_hostkey_hash(self.session, libssh2_hash);
    if (!hash) {
        NMSSHLogWarn(@"Unable to retrive host's fingerprint");
        return nil;
    }

    NSMutableString *fingerprint = [[NSMutableString alloc] initWithFormat:@"%02X", (unsigned char)hash[0]];

    for (int i = 1; i < hashLength; i++) {
        [fingerprint appendFormat:@":%02X", (unsigned char)hash[i]];
    }

    return [fingerprint copy];
}

// -----------------------------------------------------------------------------
#pragma mark - KNOWN HOSTS
// -----------------------------------------------------------------------------

- (NSString *)applicationSupportDirectory {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *applicationSupportDirectory = paths[0];
    NSString *nmsshDirectory = [applicationSupportDirectory stringByAppendingPathComponent:@"NMSSH"];

    if (![[NSFileManager defaultManager] fileExistsAtPath:nmsshDirectory]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:nmsshDirectory
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:NULL];
    }

    return nmsshDirectory;
}

- (NSString *)userKnownHostsFileName {
#if TARGET_OS_IPHONE
    return [[self applicationSupportDirectory] stringByAppendingPathComponent:@"known_hosts"];
#else
    return [@"~/.ssh/known_hosts" stringByExpandingTildeInPath];
#endif
}

#if !TARGET_OS_IPHONE
- (NSString *)systemKnownHostsFileName {
    return @"/etc/ssh/ssh_known_hosts";
}
#endif

- (NMSSHKnownHostStatus)knownHostStatusInFiles:(NSArray *)files {
    if (!files) {
#if TARGET_OS_IPHONE
        files = @[[self userKnownHostsFileName]];
#else
        files = @[[self systemKnownHostsFileName], [self userKnownHostsFileName]];
#endif
    }

    NMSSHKnownHostStatus status = NMSSHKnownHostStatusFailure;
    for (NSString *filename in files) {
        status = [self knownHostStatusWithFile:filename];

        if (status != NMSSHKnownHostStatusNotFound && status != NMSSHKnownHostStatusFailure) {
            return status;
        }
    }

    return status;
}

- (NMSSHKnownHostStatus)knownHostStatusWithFile:(NSString *)filename {
    LIBSSH2_KNOWNHOSTS *knownHosts = libssh2_knownhost_init(self.session);
    if (!knownHosts) {
        return NMSSHKnownHostStatusFailure;
    }

    int rc = libssh2_knownhost_readfile(knownHosts,
                                        [filename UTF8String],
                                        LIBSSH2_KNOWNHOST_FILE_OPENSSH);
    if (rc < 0) {
        libssh2_knownhost_free(knownHosts);

        if (rc == LIBSSH2_ERROR_FILE) {
            NMSSHLogInfo(@"No known hosts file %@.", filename);
            return NMSSHKnownHostStatusNotFound;
        }
        else {
            NMSSHLogError(@"Failed to read known hosts file %@.", filename);
            return NMSSHKnownHostStatusFailure;
        }
    }

    int keytype;
    size_t keylen;
    const char *remotekey = libssh2_session_hostkey(self.session, &keylen, &keytype);
    if (!remotekey) {
        NMSSHLogError(@"Failed to get host key.");
        libssh2_knownhost_free(knownHosts);

        return NMSSHKnownHostStatusFailure;
    }

    int keybit = (keytype == LIBSSH2_HOSTKEY_TYPE_RSA ? LIBSSH2_KNOWNHOST_KEY_SSHRSA : LIBSSH2_KNOWNHOST_KEY_SSHDSS);
    struct libssh2_knownhost *host;
    NMSSHLogInfo(@"Check for host %@, port %@ in file %@", self.host, self.port, filename);
    int check = libssh2_knownhost_checkp(knownHosts,
                                         [self.host UTF8String],
                                         [self.port intValue],
                                         remotekey,
                                         keylen,
                                         (LIBSSH2_KNOWNHOST_TYPE_PLAIN |
                                          LIBSSH2_KNOWNHOST_KEYENC_RAW |
                                          keybit),
                                         &host);

    libssh2_knownhost_free(knownHosts);

    switch (check) {
        case LIBSSH2_KNOWNHOST_CHECK_MATCH:
            NMSSHLogInfo(@"Match");
            return NMSSHKnownHostStatusMatch;

        case LIBSSH2_KNOWNHOST_CHECK_MISMATCH:
            NMSSHLogInfo(@"Mismatch");
            return NMSSHKnownHostStatusMismatch;

        case LIBSSH2_KNOWNHOST_CHECK_NOTFOUND:
            NMSSHLogInfo(@"Not found");
            return NMSSHKnownHostStatusNotFound;

        case LIBSSH2_KNOWNHOST_CHECK_FAILURE:
        default:
            NMSSHLogInfo(@"Failure");
            return NMSSHKnownHostStatusFailure;
    }
}

- (BOOL)addKnownHostName:(NSString *)host port:(NSInteger)port toFile:(NSString *)fileName withSalt:(NSString *)salt {
    const char *hostkey;
    size_t hklen;
    int hktype;
    NSString *hostname;  // Formatted as {host} or [{host}]:{port}.

    if (port == 22) {
        hostname = host;
    }
    else {
        hostname = [NSString stringWithFormat:@"[%@]:%d", host, (int)port];
    }

    if (!fileName) {
        fileName = [self userKnownHostsFileName];
    }

    hostkey = libssh2_session_hostkey(self.session, &hklen, &hktype);
    if (!hostkey) {
        NMSSHLogError(@"Failed to get host key.");
        return NO;
    }

    LIBSSH2_KNOWNHOSTS *knownHosts = libssh2_knownhost_init(self.session);
    if (!knownHosts) {
        NMSSHLogError(@"Failed to initialize knownhosts.");
        return NO;
    }

    int rc = libssh2_knownhost_readfile(knownHosts, [fileName UTF8String], LIBSSH2_KNOWNHOST_FILE_OPENSSH);
    if (rc < 0 && rc != LIBSSH2_ERROR_FILE) {
        NMSSHLogError(@"Failed to read known hosts file.");
        libssh2_knownhost_free(knownHosts);

        return NO;
    }

    int keybit = LIBSSH2_KNOWNHOST_KEYENC_RAW;
    if (hktype == LIBSSH2_HOSTKEY_TYPE_RSA) {
        keybit |= LIBSSH2_KNOWNHOST_KEY_SSHRSA;
    }
    else {
        keybit |= LIBSSH2_KNOWNHOST_KEY_SSHDSS;
    }

    if (salt) {
        keybit |= LIBSSH2_KNOWNHOST_TYPE_SHA1;
    }
    else {
        keybit |= LIBSSH2_KNOWNHOST_TYPE_PLAIN;
    }

    int result = libssh2_knownhost_addc(knownHosts,
                                        [hostname UTF8String],
                                        [salt UTF8String],
                                        hostkey,
                                        hklen,
                                        NULL,
                                        0,
                                        keybit,
                                        NULL);
    if (result) {
        NMSSHLogError(@"Failed to add host to known hosts: error %d (%@)",
                      result,
                      [self lastError]);
    }
    else {
        result = libssh2_knownhost_writefile(knownHosts,
                                             [fileName UTF8String],
                                             LIBSSH2_KNOWNHOST_FILE_OPENSSH);
        if (result < 0) {
            NMSSHLogError(@"Couldn't write to %@: %@",
                          [self userKnownHostsFileName], [self lastError]);
        }
        else {
            NMSSHLogInfo(@"Host added to known hosts.");
        }
    }

    libssh2_knownhost_free(knownHosts);
    return result == 0;
}

- (NSString *)keyboardInteractiveRequest:(NSString *)request {
    NMSSHLogVerbose(@"Server request '%@'", request);

    if (self.kbAuthenticationBlock) {
        return self.kbAuthenticationBlock(request);
    }
    else if (self.delegate && [self.delegate respondsToSelector:@selector(session:keyboardInteractiveRequest:)]) {
        return [self.delegate session:self keyboardInteractiveRequest:request];
    }

    NMSSHLogWarn(@"Keyboard interactive requires a delegate that responds to session:keyboardInteractiveRequest: or a block!");

    return @"";
}

void kb_callback(const char *name, int name_len, const char *instr, int instr_len,
                 int num_prompts, const LIBSSH2_USERAUTH_KBDINT_PROMPT *prompts, LIBSSH2_USERAUTH_KBDINT_RESPONSE *res, void **abstract) {
    int i;

    NMSSHSession *self = (__bridge NMSSHSession *)*abstract;

    for (i = 0; i < num_prompts; i++) {
        NSString *request = [[NSString alloc] initWithBytes:prompts[i].text length:prompts[i].length encoding:NSUTF8StringEncoding];
        NSString *response = [self keyboardInteractiveRequest:request];

        if (!response) {
            response = @"";
        }

        res[i].text = strdup([response UTF8String]);
        res[i].length = (unsigned int)strlen([response UTF8String]);
    }
}

void disconnect_callback(LIBSSH2_SESSION *session, int reason, const char *message, int message_len, const char *language, int language_len, void **abstract) {
    NMSSHSession *self = (__bridge NMSSHSession *)*abstract;

    // Build a raw error to encapsulate the disconnect
    NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] initWithCapacity:2];
    if (message) {
        NSString *string = [[NSString alloc] initWithBytes:message length:message_len encoding:NSUTF8StringEncoding];
        [userInfo setObject:string forKey:NSLocalizedDescriptionKey];
    }

    if (language) {
        NSString *string = [[NSString alloc] initWithBytes:language length:language_len encoding:NSUTF8StringEncoding];
        [userInfo setObject:string forKey:@"language"];
    }

    NSError *error = [NSError errorWithDomain:@"NMSSH" code:reason userInfo:userInfo];
    if (self.delegate && [self.delegate respondsToSelector:@selector(session:didDisconnectWithError:)]) {
        [self.delegate session:self didDisconnectWithError:error];
    }

    [self disconnect];
}

// -----------------------------------------------------------------------------
#pragma mark - QUICK CHANNEL/SFTP ACCESS
// -----------------------------------------------------------------------------

- (NMSSHChannel *)channel {
    if (!_channel) {
        _channel = [[NMSSHChannel alloc] initWithSession:self];
    }

    return _channel;
}

- (NMSFTP *)sftp {
    if (!_sftp) {
        _sftp = [[NMSFTP alloc] initWithSession:self];
    }

    return _sftp;
}

@end
