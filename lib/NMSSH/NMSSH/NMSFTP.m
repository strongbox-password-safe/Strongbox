#import "NMSFTP.h"
#import "NMSSH+Protected.h"

@interface NMSFTP ()
@property (nonatomic, strong) NMSSHSession *session;
@property (nonatomic, assign) LIBSSH2_SFTP *sftpSession;
@property (nonatomic, readwrite, getter = isConnected) BOOL connected;

- (BOOL)writeStream:(NSInputStream *)inputStream toSFTPHandle:(LIBSSH2_SFTP_HANDLE *)handle;
- (BOOL)writeStream:(NSInputStream *)inputStream toSFTPHandle:(LIBSSH2_SFTP_HANDLE *)handle progress:(BOOL (^)(NSUInteger))progress;
- (BOOL)readContentsAtPath:(NSString *)path toStream:(NSOutputStream *)stream progress:(BOOL (^)(NSUInteger, NSUInteger))progress;
@end

@implementation NMSFTP


// -----------------------------------------------------------------------------
#pragma mark - INITIALIZER
// -----------------------------------------------------------------------------

+ (instancetype)connectWithSession:(NMSSHSession *)session {
    NMSFTP *sftp = [[NMSFTP alloc] initWithSession:session];
    [sftp connect];

    return sftp;
}

- (instancetype)initWithSession:(NMSSHSession *)session {
    if ((self = [super init])) {
        [self setSession:session];

        // Make sure we were provided a valid session
        if (![session isKindOfClass:[NMSSHSession class]]) {
            @throw @"You have to provide a valid NMSSHSession!";
        }
    }

    return self;
}

// -----------------------------------------------------------------------------
#pragma mark - CONNECTION
// -----------------------------------------------------------------------------

- (BOOL)connect {
    // Set blocking mode
    libssh2_session_set_blocking(self.session.rawSession, 1);

    [self setSftpSession:libssh2_sftp_init(self.session.rawSession)];

    if (!self.sftpSession) {
        NMSSHLogError(@"Unable to init SFTP session");
        return NO;
    }

    [self setConnected:YES];
    [self setBufferSize:kNMSSHBufferSize];

    return self.isConnected;
}

- (void)disconnect {
    libssh2_sftp_shutdown(self.sftpSession);
    [self setConnected:NO];
}

// -----------------------------------------------------------------------------
#pragma mark - MANIPULATE FILE SYSTEM ENTRIES
// -----------------------------------------------------------------------------

- (BOOL)moveItemAtPath:(NSString *)sourcePath toPath:(NSString *)destPath {
    return libssh2_sftp_rename(self.sftpSession, [sourcePath UTF8String], [destPath UTF8String]) == 0;
}

// -----------------------------------------------------------------------------
#pragma mark - MANIPULATE DIRECTORIES
// -----------------------------------------------------------------------------

- (LIBSSH2_SFTP_HANDLE *)openDirectoryAtPath:(NSString *)path {
    LIBSSH2_SFTP_HANDLE *handle = libssh2_sftp_opendir(self.sftpSession, [path UTF8String]);

    if (!handle) {
        NSError *error = [self.session lastError];
        NMSSHLogError(@"Could not open directory at path %@ (Error %li: %@)", path, (long)error.code, error.localizedDescription);

        if ([error code] == LIBSSH2_ERROR_SFTP_PROTOCOL) {
            NMSSHLogError(@"SFTP error %lu", libssh2_sftp_last_error(self.sftpSession));
        }
    }

    return handle;
}

- (BOOL)directoryExistsAtPath:(NSString *)path {
    LIBSSH2_SFTP_HANDLE *handle = [self openFileAtPath:path flags:LIBSSH2_FXF_READ mode:0];

    if (!handle) {
        return NO;
    }

    LIBSSH2_SFTP_ATTRIBUTES fileAttributes;
    int rc = libssh2_sftp_fstat(handle, &fileAttributes);
    libssh2_sftp_close(handle);

    return rc == 0 && LIBSSH2_SFTP_S_ISDIR(fileAttributes.permissions);
}

- (BOOL)createDirectoryAtPath:(NSString *)path {
    int rc = libssh2_sftp_mkdir(self.sftpSession, [path UTF8String],
                                LIBSSH2_SFTP_S_IRWXU|
                                LIBSSH2_SFTP_S_IRGRP|LIBSSH2_SFTP_S_IXGRP|
                                LIBSSH2_SFTP_S_IROTH|LIBSSH2_SFTP_S_IXOTH);

    return rc == 0;
}

- (BOOL)removeDirectoryAtPath:(NSString *)path {
    return libssh2_sftp_rmdir(self.sftpSession, [path UTF8String]) == 0;
}

- (NSArray *)contentsOfDirectoryAtPath:(NSString *)path {
    LIBSSH2_SFTP_HANDLE *handle = [self openDirectoryAtPath:path];

    if (!handle) {
        return nil;
    }

    NSArray *ignoredFiles = @[@".", @".."];
    NSMutableArray *contents = [NSMutableArray array];

    int rc;
    do {
        char buffer[512];
        LIBSSH2_SFTP_ATTRIBUTES fileAttributes;

        rc = libssh2_sftp_readdir(handle, buffer, sizeof(buffer), &fileAttributes);

        if (rc > 0) {
            NSString *fileName = [[NSString alloc] initWithBytes:buffer length:rc encoding:NSUTF8StringEncoding];
            if (![ignoredFiles containsObject:fileName]) {
                // Append a "/" at the end of all directories
                if (LIBSSH2_SFTP_S_ISDIR(fileAttributes.permissions)) {
                    fileName = [fileName stringByAppendingString:@"/"];
                }

                NMSFTPFile *file = [[NMSFTPFile alloc] initWithFilename:fileName];
                [file populateValuesFromSFTPAttributes:fileAttributes];
                [contents addObject:file];
            }
        }
    } while (rc > 0);

    if (rc < 0) {
        NMSSHLogError(@"Unable to read directory");
    }

    rc = libssh2_sftp_closedir(handle);

    if (rc < 0) {
        NMSSHLogError(@"Failed to close directory");
    }

    return [contents sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [obj1 compare:obj2];
    }];
}

// -----------------------------------------------------------------------------
#pragma mark - MANIPULATE SYMLINKS AND FILES
// -----------------------------------------------------------------------------

- (NMSFTPFile *)infoForFileAtPath:(NSString *)path {
    LIBSSH2_SFTP_HANDLE *handle = [self openFileAtPath:path flags:LIBSSH2_FXF_READ mode:0];

    if (!handle) {
        return nil;
    }

    LIBSSH2_SFTP_ATTRIBUTES fileAttributes;
    ssize_t rc = libssh2_sftp_fstat(handle, &fileAttributes);
    libssh2_sftp_close(handle);

    if (rc < 0) {
        return nil;
    }

    NMSFTPFile *file = [[NMSFTPFile alloc] initWithFilename:path.lastPathComponent];
    [file populateValuesFromSFTPAttributes:fileAttributes];

    return file;
}

- (LIBSSH2_SFTP_HANDLE *)openFileAtPath:(NSString *)path flags:(unsigned long)flags mode:(long)mode {
    LIBSSH2_SFTP_HANDLE *handle = libssh2_sftp_open(self.sftpSession, [path UTF8String], flags, mode);

    if (!handle) {
        NSError *error = [self.session lastError];
        NMSSHLogError(@"Could not open file at path %@ (Error %li: %@)", path, (long)error.code, error.localizedDescription);

        if ([error code] == LIBSSH2_ERROR_SFTP_PROTOCOL) {
            NMSSHLogError(@"SFTP error %lu", libssh2_sftp_last_error(self.sftpSession));
        }
    }

    return handle;
}

- (BOOL)fileExistsAtPath:(NSString *)path {
    LIBSSH2_SFTP_HANDLE *handle = [self openFileAtPath:path flags:LIBSSH2_FXF_READ mode:0];

    if (!handle) {
        return NO;
    }

    LIBSSH2_SFTP_ATTRIBUTES fileAttributes;
    int rc = libssh2_sftp_fstat(handle, &fileAttributes);
    libssh2_sftp_close(handle);

    return rc == 0 && !LIBSSH2_SFTP_S_ISDIR(fileAttributes.permissions);
}

- (BOOL)createSymbolicLinkAtPath:(NSString *)linkPath
             withDestinationPath:(NSString *)destPath {
    int rc = libssh2_sftp_symlink(self.sftpSession, [destPath UTF8String], (char *)[linkPath UTF8String]);

    return rc == 0;
}

- (BOOL)removeFileAtPath:(NSString *)path {
    return libssh2_sftp_unlink(self.sftpSession, [path UTF8String]) == 0;
}

- (NSData *)contentsAtPath:(NSString *)path {
    return [self contentsAtPath:path progress:nil];
}

- (NSData *)contentsAtPath:(NSString *)path progress:(BOOL (^)(NSUInteger, NSUInteger))progress {
    NSOutputStream *outputStream = [NSOutputStream outputStreamToMemory];
    
    BOOL success = [self readContentsAtPath:path toStream:outputStream progress:progress];
    
    if (success) {
        return [outputStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey];
    } else {
        return nil;
    }
}

- (BOOL)contentsAtPath:(NSString *)path toStream:(NSOutputStream *)outputStream progress:(BOOL (^)(NSUInteger, NSUInteger))progress {
    return [self readContentsAtPath:path toStream:outputStream progress:progress];
}

- (BOOL)readContentsAtPath:(NSString *)path toStream:(NSOutputStream *)outputStream progress:(BOOL (^)(NSUInteger, NSUInteger))progress {
    LIBSSH2_SFTP_HANDLE *handle = [self openFileAtPath:path flags:LIBSSH2_FXF_READ mode:0];
    
    if (!handle) {
        return NO;
    }
    
    NMSFTPFile *file = [self infoForFileAtPath:path];
    if (!file) {
        NMSSHLogWarn(@"contentsAtPath:progress: failed to get file attributes");
        return NO;
    }
    
    if ([outputStream streamStatus] == NSStreamStatusNotOpen) {
        [outputStream open];
    }
    
    char buffer[self.bufferSize];
    ssize_t rc;
    NSUInteger got = 0;
    while ((rc = libssh2_sftp_read(handle, buffer, (ssize_t)sizeof(buffer))) > 0) {
        NSUInteger remainingBytes = rc;
        NSInteger writeResult;
        do {
            writeResult = [outputStream write:(const uint8_t *)&buffer maxLength:remainingBytes];
            remainingBytes -= MAX(0, writeResult);
        } while (remainingBytes > 0 && writeResult > 0);
        
        if (writeResult < 0 || (writeResult == 0 && remainingBytes > 0)) {
            libssh2_sftp_close(handle);
            [outputStream close];
            return NO;
        }
        
        got += rc;
        if (progress && !progress(got, (NSUInteger)[file.fileSize integerValue])) {
            libssh2_sftp_close(handle);
            [outputStream close];
            return NO;
        }
    }
    
    libssh2_sftp_close(handle);
    [outputStream close];
    
    if (rc < 0) {
        return NO;
    }
    
    return YES;
}

- (BOOL)writeContents:(NSData *)contents toFileAtPath:(NSString *)path {
    return [self writeContents:contents toFileAtPath:path progress:nil];
}

- (BOOL)writeContents:(NSData *)contents toFileAtPath:(NSString *)path progress:(BOOL (^)(NSUInteger))progress {
    return [self writeStream:[NSInputStream inputStreamWithData:contents] toFileAtPath:path progress:progress];
}

- (BOOL)writeFileAtPath:(NSString *)localPath toFileAtPath:(NSString *)path {
    return [self writeFileAtPath:localPath toFileAtPath:path progress:nil];
}

- (BOOL)writeFileAtPath:(NSString *)localPath toFileAtPath:(NSString *)path progress:(BOOL (^)(NSUInteger))progress {
    return [self writeStream:[NSInputStream inputStreamWithFileAtPath:localPath] toFileAtPath:path progress:progress];
}

- (BOOL)writeStream:(NSInputStream *)inputStream toFileAtPath:(NSString *)path {
    return [self writeStream:inputStream toFileAtPath:path progress:nil];
}

- (BOOL)writeStream:(NSInputStream *)inputStream toFileAtPath:(NSString *)path progress:(BOOL (^)(NSUInteger))progress {
    if ([inputStream streamStatus] == NSStreamStatusNotOpen) {
        [inputStream open];
    }

    if (![inputStream hasBytesAvailable]) {
        NMSSHLogWarn(@"No bytes available in the stream");
        return NO;
    }

    LIBSSH2_SFTP_HANDLE *handle = [self openFileAtPath:path
                                                 flags:LIBSSH2_FXF_WRITE|LIBSSH2_FXF_CREAT|LIBSSH2_FXF_TRUNC
                                                  mode:LIBSSH2_SFTP_S_IRUSR|LIBSSH2_SFTP_S_IWUSR|LIBSSH2_SFTP_S_IRGRP|LIBSSH2_SFTP_S_IROTH];

    if (!handle) {
        [inputStream close];
        return NO;
    }

    BOOL success = [self writeStream:inputStream toSFTPHandle:handle progress:progress];

    libssh2_sftp_close(handle);
    [inputStream close];

    return success;
}

- (BOOL)resumeFileAtPath:(NSString *)localPath toFileAtPath:(NSString *)path progress:(BOOL (^)( NSUInteger, NSUInteger ))progress {
    return [self resumeStream:[NSInputStream inputStreamWithFileAtPath:localPath] toFileAtPath:path progress:progress];
}

- (BOOL)resumeStream:(NSInputStream *)inputStream toFileAtPath:(NSString *)path progress:(BOOL (^)( NSUInteger, NSUInteger ))progress {
    if ([inputStream streamStatus] == NSStreamStatusNotOpen) {
        [inputStream open];
    }
    
    if (![inputStream hasBytesAvailable]) {
        NMSSHLogWarn(@"No bytes available in the stream");
        return NO;
    }
    
    LIBSSH2_SFTP_HANDLE *handle = [self openFileAtPath:path
                                                 flags:LIBSSH2_FXF_WRITE|LIBSSH2_FXF_CREAT|LIBSSH2_FXF_READ
                                                  mode:LIBSSH2_SFTP_S_IRUSR|LIBSSH2_SFTP_S_IWUSR|LIBSSH2_SFTP_S_IRGRP|LIBSSH2_SFTP_S_IROTH];
    
    if (!handle) {
        [inputStream close];
        return NO;
    }
    
    NMSSHLogVerbose(@"Resume destFile %@", path);

    BOOL success = [self resumeStream:inputStream toSFTPHandle:handle progress:progress];

    libssh2_sftp_close(handle);
    [inputStream close];
    
    return success;
}

- (BOOL)resumeStream:(NSInputStream *)inputStream toSFTPHandle:(LIBSSH2_SFTP_HANDLE *)handle progress:(BOOL (^)( NSUInteger, NSUInteger ))progress {
    uint8_t buffer[self.bufferSize];
    NSInteger bytesRead = -1;
    long rc = 0;
    NSUInteger delta = 0;

    LIBSSH2_SFTP_ATTRIBUTES attributes;
    if (libssh2_sftp_fstat(handle, &attributes) < 0) {
        [inputStream close];
        NMSSHLogError(@"Unable to get attributes of handle");
        return NO;
    }
    
    libssh2_sftp_seek64(handle, attributes.filesize);
    NMSSHLogVerbose(@"Seek to position %llu of destFile", attributes.filesize);
    
    [inputStream setProperty:[NSNumber numberWithUnsignedLongLong:attributes.filesize] forKey:NSStreamFileCurrentOffsetKey];
    
    while (rc >= 0 && [inputStream hasBytesAvailable]) {
        bytesRead = [inputStream read:buffer maxLength:self.bufferSize];
        if (bytesRead > 0) {
            uint8_t *ptr = buffer;
            do {
                rc = libssh2_sftp_write(handle, (const char *)ptr, bytesRead);
                if(rc < 0){
                    NMSSHLogWarn(@"libssh2_sftp_write failed (Error %li)", rc);
                    break;
                }
                delta += rc;
                ptr += rc;
                bytesRead -= rc;
                if (progress && !progress(delta, delta + (NSUInteger)attributes.filesize))
                {
                    return NO;
                }
            }while(bytesRead);
        }
    }
    
    if (bytesRead < 0 || rc < 0) {
        return NO;
    }
    
    return YES;
}

- (BOOL)appendContents:(NSData *)contents toFileAtPath:(NSString *)path {
    return [self appendStream:[NSInputStream inputStreamWithData:contents] toFileAtPath:path];
}

- (BOOL)appendStream:(NSInputStream *)inputStream toFileAtPath:(NSString *)path {
    if ([inputStream streamStatus] == NSStreamStatusNotOpen) {
        [inputStream open];
    }

    if (![inputStream hasBytesAvailable]) {
        NMSSHLogWarn(@"No bytes available in the stream");
        return NO;
    }

    LIBSSH2_SFTP_HANDLE *handle = [self openFileAtPath:path
                                                 flags:LIBSSH2_FXF_WRITE|LIBSSH2_FXF_CREAT|LIBSSH2_FXF_READ
                                                  mode:LIBSSH2_SFTP_S_IRUSR|LIBSSH2_SFTP_S_IWUSR|LIBSSH2_SFTP_S_IRGRP|LIBSSH2_SFTP_S_IROTH];

    if (!handle) {
        [inputStream close];
        return NO;
    }

    LIBSSH2_SFTP_ATTRIBUTES attributes;
    if (libssh2_sftp_fstat(handle, &attributes) < 0) {
        [inputStream close];
        NMSSHLogError(@"Unable to get attributes of file %@", path);
        return NO;
    }

    libssh2_sftp_seek64(handle, attributes.filesize);
    NMSSHLogVerbose(@"Seek to position %ld", (long)attributes.filesize);

    BOOL success = [self writeStream:inputStream toSFTPHandle:handle];

    libssh2_sftp_close(handle);
    [inputStream close];

    return success;
}

- (BOOL)writeStream:(NSInputStream *)inputStream toSFTPHandle:(LIBSSH2_SFTP_HANDLE *)handle {
    return [self writeStream:inputStream toSFTPHandle:handle progress:nil];
}

- (BOOL)writeStream:(NSInputStream *)inputStream toSFTPHandle:(LIBSSH2_SFTP_HANDLE *)handle progress:(BOOL (^)(NSUInteger))progress {
    uint8_t buffer[self.bufferSize];
    NSInteger bytesRead = -1;
    long rc = 0;
    NSUInteger total = 0;
    
    while (rc >= 0 && [inputStream hasBytesAvailable]) {
        bytesRead = [inputStream read:buffer maxLength:self.bufferSize];
        if (bytesRead > 0) {
            uint8_t *ptr = buffer;
            do {
                rc = libssh2_sftp_write(handle, (const char *)ptr, bytesRead);
                if(rc < 0){
                    NMSSHLogWarn(@"libssh2_sftp_write failed (Error %li)", rc);
                    break;
                }
                total += rc;
                ptr += rc;
                bytesRead -= rc;
                if (progress && !progress(total))
                {
                    return NO;
                }
            }while(bytesRead);
        }
    }

    if (bytesRead < 0 || rc < 0) {
        return NO;
    }

    return YES;
}

- (BOOL)copyContentsOfPath:(NSString *)fromPath toFileAtPath:(NSString *)toPath progress:(BOOL (^)(NSUInteger, NSUInteger))progress
{
    // Open handle for reading.
    LIBSSH2_SFTP_HANDLE *fromHandle = [self openFileAtPath:fromPath flags:LIBSSH2_FXF_READ mode:0];
    
    // Open handle for writing.
    LIBSSH2_SFTP_HANDLE *toHandle = [self openFileAtPath:toPath
                                                 flags:LIBSSH2_FXF_WRITE|LIBSSH2_FXF_CREAT|LIBSSH2_FXF_READ
                                                  mode:LIBSSH2_SFTP_S_IRUSR|LIBSSH2_SFTP_S_IWUSR|LIBSSH2_SFTP_S_IRGRP|LIBSSH2_SFTP_S_IROTH];
    
    // Get information about the file to copy.
    NMSFTPFile *file = [self infoForFileAtPath:fromPath];
    if (!file) {
        NMSSHLogWarn(@"contentsAtPath:progress: failed to get file attributes");
        return NO;
    }
    
    char buffer[self.bufferSize];
    ssize_t bytesRead;
    off_t copied = 0;
    long rc = 0;
    while ((bytesRead = libssh2_sftp_read(fromHandle, buffer, (ssize_t)sizeof(buffer))) > 0) {
        if (bytesRead > 0) {
            char *ptr = buffer;
            do {
                rc = libssh2_sftp_write(toHandle, (const char *)ptr, (NSInteger)bytesRead);
                if(rc < 0){
                    NMSSHLogWarn(@"libssh2_sftp_write failed (Error %li)", rc);
                    break;
                }
                copied += rc;
                ptr += rc;
                bytesRead -= rc;
                if (progress && !progress((NSUInteger)copied, (NSUInteger)[file.fileSize integerValue])) {
                    libssh2_sftp_close(fromHandle);
                    libssh2_sftp_close(toHandle);
                    return NO;
                }
            }while(bytesRead);
        }
    }
    
    libssh2_sftp_close(fromHandle);
    libssh2_sftp_close(toHandle);
    
    return YES;
}

@end
