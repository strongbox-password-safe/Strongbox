#import "socket_helper.h"
#import <Foundation/Foundation.h>
#import <sys/time.h>

int waitsocket(int socket_fd, LIBSSH2_SESSION *session) {
    struct timeval timeout;

    fd_set fd;
    fd_set *writefd = NULL;
    fd_set *readfd = NULL;

    int rc;
    int dir;
    timeout.tv_sec = 0;
    timeout.tv_usec = 500000;

    FD_ZERO(&fd);
    FD_SET(socket_fd, &fd);

    // Now make sure we wait in the correct direction
    dir = libssh2_session_block_directions(session);

    if (dir & LIBSSH2_SESSION_BLOCK_INBOUND) {
        readfd = &fd;
    }

    if (dir & LIBSSH2_SESSION_BLOCK_OUTBOUND) {
        writefd = &fd;
    }

    rc = select(socket_fd + 1, readfd, writefd, NULL, &timeout);
    
    return rc;
}
