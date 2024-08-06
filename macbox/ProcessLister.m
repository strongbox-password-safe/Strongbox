//
//  ProcessLister.m
//  MacBox
//
//  Created by Strongbox on 25/05/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

#import "ProcessLister.h"
#include <sys/sysctl.h>
#include <pwd.h>
#import "SBLog.h"

typedef struct kinfo_proc kinfo_proc;

// https://stackoverflow.com/questions/18820199/unable-to-detect-application-running-with-another-user-via-switch-user/18821357#18821357








static int GetBSDProcessList(kinfo_proc **procList, size_t *procCount) {
    int                 err;
    kinfo_proc *        result;
    bool                done;
    static const int    name[] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
    
    
    
    
    size_t              length;
    
    
    
    
    
    *procCount = 0;
    
    
    
    
    
    
    
    
    
    
    
    result = NULL;
    done = false;
    do {
        assert(result == NULL);
        
        
        
        length = 0;
        err = sysctl( (int *) name, (sizeof(name) / sizeof(*name)) - 1,
                     NULL, &length,
                     NULL, 0);
        if (err == -1) {
            err = errno;
        }
        
        
        
        
        if (err == 0) {
            result = malloc(length);
            if (result == NULL) {
                err = ENOMEM;
            }
        }
        
        
        
        
        if (err == 0) {
            err = sysctl( (int *) name, (sizeof(name) / sizeof(*name)) - 1,
                         result, &length,
                         NULL, 0);
            if (err == -1) {
                err = errno;
            }
            if (err == 0) {
                done = true;
            } else if (err == ENOMEM) {
                assert(result != NULL);
                free(result);
                result = NULL;
                err = 0;
            }
        }
    } while (err == 0 && ! done);
    
    
    
    if (err != 0 && result != NULL) {
        free(result);
        result = NULL;
    }
    *procList = result;
    if (err == 0) {
        *procCount = length / sizeof(kinfo_proc);
    }
    
    assert( (err == 0) == (*procList != NULL) );
    
    return err;
}

@implementation ProcessSummary

@end

@implementation ProcessLister

+ (NSArray<ProcessSummary*>*)getBSDProcessList {
    kinfo_proc *mylist =NULL;
    size_t mycount = 0;
    GetBSDProcessList(&mylist, &mycount);
    
    NSMutableArray<ProcessSummary*> *processes = [NSMutableArray arrayWithCapacity:(int)mycount];
    
    for (int i = 0; i < mycount; i++) {
        struct kinfo_proc *currentProcess = &mylist[i];
        
        ProcessSummary* entry = [[ProcessSummary alloc] init];
        entry.processID = currentProcess->kp_proc.p_pid;
        
        NSString *processName = [NSString stringWithFormat:@"%s",currentProcess->kp_proc.p_comm];
        if (processName) {
            entry.processName = processName;
        }
        else {
            slog(@"⚠️ ProcessLister::getBSDProcessList - Couldn't get Process Name...");
        }









        
        [processes addObject:entry];
    }
    free(mylist);
    
    return [NSArray arrayWithArray:processes];
}

@end

