//
//  SSHAgentServer.m
//  MacBox
//
//  Created by Strongbox on 14/08/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

#import "SSHAgentServer.h"
#import <Cocoa/Cocoa.h>

#include <sys/types.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/ucred.h>

#include <errno.h>
#import "NSData+Extensions.h"
#import "NSString+Extensions.h"

#import <openssh-portable/sshkey.h>
#import <openssh-portable/sshbuf.h>
#import <openssh-portable/ssherr.h>
#import <openssh-portable/digest.h>
#import <openssh-portable/authfd.h>

#import "NSArray+Extensions.h"
#import "ProcessLister.h"
#import "Strongbox-Swift.h"
#import "OpenSSHPrivateKey.h"
#import "Utils.h"

@interface SSHAgentServer ()


@property int server_sock;

@property (readonly) NSString* symlinkFullPath;
@property (readonly) NSString* symlinkWithTildeInPath;

@end

static NSString* const kSocketFileName = @"agent.sock";
static NSString* const kSymlinkDirectory = @".strongbox";

@implementation SSHAgentServer

+ (instancetype)sharedInstance {
    static SSHAgentServer *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[SSHAgentServer alloc] init];
    });
    
    return sharedInstance;
}

- (NSString *)symlinkFullPath {
    NSURL* home = [Utils userHomeDirectoryEvenInSandbox];
    NSString* homePath = home.path;
    NSString* build = [homePath stringByAppendingPathComponent:kSymlinkDirectory];
    return [build stringByAppendingPathComponent:kSocketFileName];
}

- (NSString *)symlinkWithTildeInPath {
    NSString* build = [@"~" stringByAppendingPathComponent:kSymlinkDirectory];
    return [build stringByAppendingPathComponent:kSocketFileName];
}

- (BOOL)symlinkExists {
    NSError* error;
    NSDictionary<NSFileAttributeKey, id> * attrs = [NSFileManager.defaultManager attributesOfItemAtPath:self.symlinkFullPath error:&error];
    
    if ( error ) {
        slog(@"⚠️ Could not get attributes of SymLink! [%@]", error);
        return NO;
    }
    
    return attrs.fileType == NSFileTypeSymbolicLink;
}

- (BOOL)createSymLink {
    NSString* str = [self getSocketPath];
    if ( str.length == 0 ) {
        slog(@"⚠️ Could not getSocketPath");
        return NO;
    }
    
    if ( self.symlinkExists ) {
        NSError* error;
        BOOL success = [NSFileManager.defaultManager removeItemAtPath:self.symlinkFullPath error:&error];
        
        if ( !success || error ) {
            slog(@"⚠️ Error removing SymLnk [%@]", error);
            return NO;
        }
    }
    
    
    
    NSString* dir = [self.symlinkFullPath stringByDeletingLastPathComponent];
    
    
    
    NSError* error;
    BOOL mkDir = [NSFileManager.defaultManager createDirectoryAtPath:dir
                                         withIntermediateDirectories:YES
                                                          attributes:nil
                                                               error:&error];
    
    if ( !mkDir || error ) {
        slog(@"⚠️ Error creating .strongbox directory for SymLnk [%@]", error);
        return NO;
    }
    
    
    
    NSSavePanel* panel = NSSavePanel.savePanel;
    panel.nameFieldStringValue = kSocketFileName;
    panel.directoryURL = [NSURL fileURLWithPath:dir];
    
    if ( [panel runModal] != NSModalResponseOK ) {
        return NO;
    }
    
    BOOL success = [NSFileManager.defaultManager createSymbolicLinkAtPath:self.symlinkFullPath
                                                      withDestinationPath:str
                                                                    error:&error];
    
    if ( !success || error ) {
        slog(@"⚠️ Error Creating SymLnk [%@]", error);
        return NO;
    }
    
    slog(@"SymLink Create OK");
    
    return YES;
}

- (NSString *)socketPathForSshConfig {
    if ( self.symlinkExists ) {
        return self.symlinkWithTildeInPath;
    }
    else {
        NSString* str = [self getSocketPath];
        if ( str.length == 0 ) {
            return nil;
        }
        
        NSURL* home = [Utils userHomeDirectoryEvenInSandbox];
        if ( [str hasPrefix:home.path] ) {
            NSString* suffix = [str stringByReplacingOccurrencesOfString:home.path withString:@""];
            str = [@"~" stringByAppendingPathComponent:suffix];
        }
        
        if ( [str containsString:@" "] ) {
            str = [NSString stringWithFormat:@"\"%@\"", str];
        }
        
        return str;
    }
}

- (NSString*)getSocketPath {
    static const int MAX_PATH = 103;
    
    NSURL* url = [NSFileManager.defaultManager containerURLForSecurityApplicationGroupIdentifier:@"group.strongbox.mac.mcguill"];
    
    
    NSString* path = [url.path stringByAppendingPathComponent:kSocketFileName];
    
    
    if ( path.length > MAX_PATH ) {
        slog(@"🔴 Could not create socket, socket path > %d chars [%@] = %ld chars", MAX_PATH, path, path.length);
        return nil;
    }
    
    BOOL mkDir = [NSFileManager.defaultManager createDirectoryAtPath:path.stringByDeletingLastPathComponent
                                         withIntermediateDirectories:YES
                                                          attributes:nil
                                                               error:nil];
    
    if ( !mkDir ) {
        slog(@"🔴 Couldn't create directory for local socket");
    }
    
    return path;
}

- (void)stop {
    
    
    if ( !self.isRunning ) {
        return;
    }
    
    
    
    if ( self.server_sock != -1 ) {
        shutdown(self.server_sock, SHUT_RDWR);
        close(self.server_sock);
        self.server_sock = -1;
    }
    
    
    
    
    
    _isRunning = NO;
}

- (BOOL)start {
    
    if ( self.isRunning ) {
        return YES;
    }

    [self stop];
    
    NSString* path = [self getSocketPath];
    if ( !path ) {
        slog(@"🔴 Path too long for getSocketPath - Check users home dir");
        return NO;
    }
    
    struct sockaddr_un sun;
    sun.sun_family = AF_UNIX;
    strcpy (sun.sun_path, [path cStringUsingEncoding:NSUTF8StringEncoding]);
    sun.sun_len = SUN_LEN(&sun);
    
    if (unlink(sun.sun_path) == -1) {
        if ( errno != ENOENT ) {
            slog(@"⚠️ SSHAgentServer unlink: %s\n,%d", strerror(errno), errno);
        }
    }
    
    self.server_sock = socket (AF_UNIX, SOCK_STREAM, 0);
    if ( self.server_sock == -1 ) {
        slog(@"🔴 Error creating socket: %s\n", strerror(errno));
        return NO;
    }
    
    const int kBufferSize = 2 * 1024 * 1024;
    if (setsockopt(self.server_sock, SOL_SOCKET, SO_RCVBUF, &kBufferSize, sizeof(int)) == -1) {
        slog(@"🔴 Error setting socket SO_RCVBUF opts: %s\n", strerror(errno));
        return NO;
    }
    if (setsockopt(self.server_sock, SOL_SOCKET, SO_SNDBUF, &kBufferSize, sizeof(int)) == -1) {
        slog(@"🔴 Error setting socket SO_SNDBUF opts: %s\n", strerror(errno));
        return NO;
    }
    
    
    
    
    if (unlink(sun.sun_path) == -1) {
        if ( errno != ENOENT) {
            slog(@"⚠️ unlink: %s\n,%d", strerror(errno), errno);
        }
    }
    
    int ret = bind (self.server_sock, (struct sockaddr *)&sun, sun.sun_len);
    if ( ret < 0 ) {
        slog(@"🔴 bind failed. %s", strerror(errno));
        return NO;
    }
    
    int listenResult = listen (self.server_sock, 48);
    if ( listenResult == -1 ) {
        slog(@"🔴 Error listening on socket: %s\n", strerror(errno));
        return NO;
    }
    
    [NSThread detachNewThreadWithBlock:^{
        [self acceptNewConnections];
    }];
    

    
    _isRunning = YES;
    return YES;
}

- (void)acceptNewConnections {
    while ( 1 ) {

        
        int socket = accept (self.server_sock, NULL, NULL);
        
        if ( socket == -1 ) {
            slog(@"⚠️ SSHAgentServer failed to accept new connection (possibly due to shutdown...)");
            break;
        }
        

        

        [self handleNewConnection:socket]; 

    }
    
    
}

- (void)sendResponse:(NSOutputStream*)outputStream response:(NSData*)response {
    
    
    uint32_t messageLength = (uint32_t)response.length; 
    uint32_t bigEndianLength = CFSwapInt32HostToBig(messageLength);
    
    NSMutableData *wrapped = NSMutableData.data;
    
    [wrapped appendBytes:&bigEndianLength length:4];
    [wrapped appendData:response];
    
    [outputStream write:wrapped.bytes maxLength:wrapped.length];
}

- (void)sendUnsupportedRequestResponse:(NSOutputStream*)outputStream {
    
    
    uint8_t resp[] = { SSH_AGENT_FAILURE };
    
    NSData* data = [NSData dataWithBytes:resp length:1];
    [self sendResponse:outputStream response:data];
}

- (pid_t)getSocketCallerPid:(int)socket {
    
    
    
    
    
    
    
    
    
    
    
    pid_t pid;
    socklen_t pid_size = sizeof(pid);
    if ( getsockopt(socket, SOL_LOCAL, LOCAL_PEERPID, &pid, &pid_size) == -1 ) { 
        slog(@"🔴 Could not getsockopt LOCAL_PEERPID");
        return -1;
    }
 
    return pid;
}

- (NSString* _Nullable)getSocketCallerId:(int)socket {
    
    
    
    
    
    
    
    
    
    
    
    pid_t pid;
    socklen_t pid_size = sizeof(pid);
    if ( getsockopt(socket, SOL_LOCAL, LOCAL_PEERPID, &pid, &pid_size) == -1 ) { 
        slog(@"🔴 Could not getsockopt LOCAL_PEERPID");
        return nil;
    }
    
    NSArray<ProcessSummary*>* ps = [ProcessLister getBSDProcessList];
    
    
    
    ProcessSummary* process = [ps firstOrDefault:^BOOL(ProcessSummary * _Nonnull obj) {
        return obj.processID == pid;
    }];

    
    return process ? process.processName : nil;
}

- (void)handleNewConnection:(int)socket {


    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    CFStreamCreatePairWithSocket (kCFAllocatorDefault, socket, &readStream, &writeStream);
    
    NSInputStream *inputStream = (__bridge_transfer NSInputStream *)readStream;
    NSOutputStream *outputStream = (__bridge_transfer NSOutputStream *)writeStream;
    
    [outputStream open];
    [inputStream open];
    
    do {
        NSData* response;
        BOOL success = [self readFromInputStream:inputStream response:&response socket:socket];
        if ( !success ) {
            break;
        }
        
        if ( response == nil ) {
            [self sendUnsupportedRequestResponse:outputStream];
        }
        else {
            [self sendResponse:outputStream response:response];
        }
    } while ( YES );
        
    [inputStream close];
    [outputStream close];
    shutdown(socket, SHUT_RDWR);
    close(socket);
    
    
}

- (BOOL)readFromInputStream:(NSInputStream*)inputStream response:(NSData**)response socket:(int)socket {
    uint32_t length;
    if ( [inputStream read:((uint8_t*)(&length)) maxLength:sizeof(uint32_t)] != sizeof(uint32_t)) {
        
        return NO;
    }
    
    length = CFSwapInt32BigToHost(length);
    
    
    
    uint8_t requestId;
    if ( [inputStream read:&requestId maxLength:sizeof(uint8_t)] != sizeof(uint8_t)) {
        slog(@"🔴 read error - could not read request id!");
        return NO;
    }

    
    
    uint32_t messageLength = length - 1;
    NSMutableData* message = [NSMutableData dataWithLength:messageLength];
    
    if ( messageLength > 0 ) {
        if ( [inputStream read:message.mutableBytes maxLength:messageLength] != messageLength) {
            slog(@"🔴 read error - could not message after length and id...");
            return NO;
        }
        
        
    }
    
    switch ( requestId ) {
        case SSH2_AGENTC_REQUEST_IDENTITIES:

            *response = [self getRequestIdentitiesResponse];
            return YES;
            break;
        case SSH2_AGENTC_SIGN_REQUEST:

            *response = [self getSignRequestResponse:message socket:socket];
            return YES;
            break;
        default:

            *response = nil;
            return YES;
    }
}

- (NSData*)getRequestIdentitiesResponse {
    struct sshbuf *msg, *keys;
    if ((msg = sshbuf_new()) == NULL || (keys = sshbuf_new()) == NULL) {
        slog(@"🔴 Could not create buffers");
        return nil;
    }

    NSArray<NSData*>* identities = [SSHAgentRequestHandler.shared getKnownPublicKeys];
    
    u_int nentries = 0;
    for ( NSData* publicKeyBlob in identities ) {
        struct sshkey *public = nil;
        int ret = sshkey_from_blob(publicKeyBlob.bytes, publicKeyBlob.length, &public);
        if ( ret != SSH_ERR_SUCCESS ) {
            slog(@"🔴 Could not get public key from private Key...");
            continue;
        }

        const char* comment = "";
        if (sshkey_puts_opts(public, keys, SSHKEY_SERIALIZE_INFO) != 0 || sshbuf_put_cstring(keys, comment) != 0) {
            sshkey_free(public);
            slog(@"🔴 Could not add key or comment");
            continue;
        }
        
        sshkey_free(public);
        nentries++;
    }

    if (sshbuf_put_u8(msg, SSH2_AGENT_IDENTITIES_ANSWER) != 0 ||
        sshbuf_put_u32(msg, nentries) != 0 ||
        sshbuf_putb(msg, keys) != 0) {
        slog(@"🔴 Could not fill in reply");
        sshbuf_free(keys);
        sshbuf_free(msg);
        return nil;
    }
    sshbuf_free(keys);
    
    size_t length = sshbuf_len(msg);
    NSMutableData* data = [NSMutableData dataWithLength:length];
    int err = sshbuf_get(msg, data.mutableBytes, length);
    if ( err != SSH_ERR_SUCCESS ) {
        slog(@"🔴 Could not copy buf");
        sshbuf_free(msg);
        return nil;
    }
    
    sshbuf_free(msg);
    
    return data;
}

- (NSData*)getSignRequestResponse:(NSData*)message socket:(int)socket {
    struct sshbuf *msg = NULL, *challenge = NULL, *eRequest = NULL;
    if ((msg = sshbuf_new()) == NULL ||
        (eRequest = sshbuf_new()) == NULL ||
        (challenge = sshbuf_new()) == NULL) {
        slog(@"🔴 Error - Could not allocate buffers for sign request");
        return nil;
    }
        
    if ( sshbuf_put(eRequest, message.bytes, message.length) != SSH_ERR_SUCCESS ) {
        slog(@"🔴 getSignRequestResponse - Error Allocating Buffer");
        sshbuf_free(msg);
        sshbuf_free(challenge);
        sshbuf_free(eRequest);
        return nil;
    }

    struct sshkey *requestedKey = NULL;
    u_int flags;

    if (sshkey_froms(eRequest, &requestedKey) != SSH_ERR_SUCCESS ||
        sshbuf_get_stringb(eRequest, challenge) != SSH_ERR_SUCCESS ||
        sshbuf_get_u32(eRequest, &flags) != SSH_ERR_SUCCESS) {
        slog(@"🔴 Error - Could not fill buffers for sign request.");
        sshbuf_free(msg);
        sshbuf_free(challenge);
        sshbuf_free(eRequest);
        return nil;
    }
    NSData* challengeData = [NSData dataWithBytes:sshbuf_ptr(challenge) length:sshbuf_len(challenge)];
    sshbuf_free(challenge);
    sshbuf_free(eRequest);
    
    
    
    u_char* bloop;
    size_t bloopLen;
    int r = sshkey_plain_to_blob(requestedKey, &bloop, &bloopLen);
    if ( r != SSH_ERR_SUCCESS ) {
        slog(@"🔴 Sign Request: Could not convert requested key to blob");
        sshbuf_free(msg);
        return nil;
    }
    sshkey_free(requestedKey);
    
    
    
    NSData* publicKeyBlob = [NSData dataWithBytes:bloop length:bloopLen];
    free(bloop);

    pid_t pid = [self getSocketCallerPid:socket];
    
    NSData* signatureData = [SSHAgentRequestHandler.shared signChallenge:challengeData
                                                     requestedKeyBlobB64:publicKeyBlob.base64String
                                                             processName:[self getSocketCallerId:socket]
                                                               processId:pid == -1 ? nil : @(pid).stringValue
                                                                   flags:flags];
    
    if ( signatureData == nil ) {
        return nil;
    }
    
    

    if ((r = sshbuf_put_u8(msg, SSH2_AGENT_SIGN_RESPONSE)) != 0 ||
        (r = sshbuf_put_string(msg, signatureData.bytes, signatureData.length)) != 0) {
        slog(@"🔴 Error Could not write signature to msg buffer - SIGN");
        sshbuf_free(msg);
        return nil;
    }

    size_t length = sshbuf_len(msg);
    NSMutableData* retData = [NSMutableData dataWithLength:length];
    int err = sshbuf_get(msg, retData.mutableBytes, length);
    sshbuf_free(msg);
    
    if ( err != SSH_ERR_SUCCESS ) {
        slog(@"🔴 Could not store message to NSData");
        return nil;
    }
        


    return retData;
}

@end
