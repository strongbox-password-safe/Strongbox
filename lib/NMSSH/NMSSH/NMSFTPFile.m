#import "NMSFTPFile.h"
#import "NMSSH+Protected.h"

@interface NMSFTPFile ()
@property (nonatomic, strong) NSString *filename;
@property (nonatomic, readwrite) BOOL isDirectory;
@property (nonatomic, strong) NSDate *modificationDate;
@property (nonatomic, strong) NSDate *lastAccess;
@property (nonatomic, strong) NSNumber *fileSize;
@property (nonatomic, readwrite) unsigned long ownerUserID;
@property (nonatomic, readwrite) unsigned long ownerGroupID;
@property (nonatomic, strong) NSString *permissions;
@property (nonatomic, readwrite) u_long flags;
@end

@implementation NMSFTPFile

- (instancetype)initWithFilename:(NSString *)filename {
    if ((self = [super init])) {
        [self setFilename:filename];
    }

    return self;
}

+ (instancetype)fileWithName:(NSString *)filename {
    return [[self alloc] initWithFilename:filename];
}

- (void)populateValuesFromSFTPAttributes:(LIBSSH2_SFTP_ATTRIBUTES)fileAttributes {
    [self setModificationDate:[NSDate dateWithTimeIntervalSince1970:fileAttributes.mtime]];
    [self setLastAccess:[NSDate dateWithTimeIntervalSinceNow:fileAttributes.atime]];
    [self setFileSize:@(fileAttributes.filesize)];
    [self setOwnerUserID:fileAttributes.uid];
    [self setOwnerGroupID:fileAttributes.gid];
    [self setPermissions:[self convertPermissionToSymbolicNotation:fileAttributes.permissions]];
    [self setIsDirectory:LIBSSH2_SFTP_S_ISDIR(fileAttributes.permissions)];
    [self setFlags:fileAttributes.flags];
}


#pragma mark - Comparison and Equality

/**
 Ensures that the sorting of the files is according to their filenames.
 
 @param file The other file that it should be compared to.
 @return The comparison result that determins the order of the two files.
 */
- (NSComparisonResult)compare:(NMSFTPFile *)file {
    return [self.filename localizedCaseInsensitiveCompare:file.filename];
}

/**
 Defines that two NMSFTPFile objects are equal, if their filenames are equal.
 @param object The other file that it should be compared with
 @return YES in case the two objects are considered equal, NO otherwise.
 */
- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[NMSFTPFile class]]) {
        return NO;
    }

    return [self.filename isEqualToString:((NMSFTPFile *)object).filename];
}


#pragma mark - Permissions conversion methods

/**
 Convert a mode field into "ls -l" type perms field. By courtesy of Jonathan Leffler
 http://stackoverflow.com/questions/10323060/printing-file-permissions-like-ls-l-using-stat2-in-c
 
 @param mode The numeric mode that is returned by the 'stat' function
 @return A string containing the symbolic representation of the file permissions.
 */
- (NSString *)convertPermissionToSymbolicNotation:(unsigned long)mode {
    static char *rwx[] = {"---", "--x", "-w-", "-wx", "r--", "r-x", "rw-", "rwx"};
    char bits[11];
    
    bits[0] = [self filetypeletter:mode];
    strcpy(&bits[1], rwx[(mode >> 6)& 7]);
    strcpy(&bits[4], rwx[(mode >> 3)& 7]);
    strcpy(&bits[7], rwx[(mode & 7)]);

    if (mode & S_ISUID) {
        bits[3] = (mode & 0100) ? 's' : 'S';
    }

    if (mode & S_ISGID) {
        bits[6] = (mode & 0010) ? 's' : 'l';
    }

    if (mode & S_ISVTX) {
        bits[9] = (mode & 0100) ? 't' : 'T';
    }

    bits[10] = '\0';

    return [NSString stringWithCString:bits encoding:NSUTF8StringEncoding];
}

/**
 Extracts the unix letter for the file type of the given permission value.
 
 @param mode The numeric mode that is returned by the 'stat' function
 @return A character that represents the given file type.
 */
- (char)filetypeletter:(unsigned long)mode {
    char c;
    
    if (S_ISREG(mode)) {
        c = '-';
    }
    else if (S_ISDIR(mode)) {
        c = 'd';
    }
    else if (S_ISBLK(mode)) {
        c = 'b';
    }
    else if (S_ISCHR(mode)) {
        c = 'c';
    }
#ifdef S_ISFIFO
    else if (S_ISFIFO(mode)) {
        c = 'p';
    }
#endif
#ifdef S_ISLNK
    else if (S_ISLNK(mode)) {
        c = 'l';
    }
#endif
#ifdef S_ISSOCK
    else if (S_ISSOCK(mode)) {
        c = 's';
    }
#endif
#ifdef S_ISDOOR
    // Solaris 2.6, etc.
    else if (S_ISDOOR(mode)) {
        c = 'D';
    }
#endif
    else {
        // Unknown type -- possibly a regular file?
        c = '?';
    }

    return c;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p> Filename: %@", NSStringFromClass([self class]), self, self.filename];
}

- (id)copyWithZone:(NSZone *)zone {
    NMSFTPFile *object = [[[self class] allocWithZone:zone] init];

    if (object) {
        object.filename = [self.filename copyWithZone:zone];
        object.modificationDate = [self.modificationDate copyWithZone:zone];
        object.lastAccess = [self.lastAccess copyWithZone:zone];
        object.fileSize = [self.fileSize copyWithZone:zone];
        object.permissions = [self.permissions copyWithZone:zone];
        object.isDirectory = self.isDirectory;
        object.ownerUserID = self.ownerUserID;
        object.ownerGroupID = self.ownerGroupID;
        object.flags = self.flags;
    }

    return object;
}

@end
