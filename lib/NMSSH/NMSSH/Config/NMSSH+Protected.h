#ifndef NMSSH_Protected_h
#define NMSSH_Protected_h

#import <CoreFoundation/CoreFoundation.h>
#import <netinet/in.h>
#import <sys/socket.h>
#import <arpa/inet.h>
#import "socket_helper.h"

#define kNMSSHBufferSize (0x4000)

#define NMSSHLogVerbose(frmt, ...) [[NMSSHLogger logger] logVerbose:[NSString stringWithFormat:frmt, ##__VA_ARGS__]]
#define NMSSHLogInfo(frmt, ...) [[NMSSHLogger logger] logInfo:[NSString stringWithFormat:frmt, ##__VA_ARGS__]]
#define NMSSHLogWarn(frmt, ...) [[NMSSHLogger logger] logWarn:[NSString stringWithFormat:frmt, ##__VA_ARGS__]]
#define NMSSHLogError(frmt, ...) [[NMSSHLogger logger] logError:[NSString stringWithFormat:frmt, ##__VA_ARGS__]]

#define strlen (unsigned int)strlen

#endif
