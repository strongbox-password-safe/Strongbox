/* -*- mode:C; c-file-style: "bsd" -*- */
/*
 * Copyright (c) 2012-2013 Yubico AB
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *
 *     * Redistributions in binary form must reproduce the above
 *       copyright notice, this list of conditions and the following
 *       disclaimer in the documentation and/or other materials provided
 *       with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef	__YKPERS_VERSION_H_INCLUDED__
#define	__YKPERS_VERSION_H_INCLUDED__

# ifdef __cplusplus
extern "C" {
# endif

/**
 * YKPERS_VERSION_STRING
 *
 * Pre-processor symbol with a string that describe the header file
 * version number.  Used together with ykpers_check_version() to verify
 * header file and run-time library consistency.
 */
#define YKPERS_VERSION_STRING "1.20.0"

/**
 * YKPERS_VERSION_NUMBER
 *
 * Pre-processor symbol with a hexadecimal value describing the header
 * file version number.  For example, when the header version is 1.2.3
 * this symbol will have the value 0x01020300.  The last two digits
 * are only used between public releases, and will otherwise be 00.
 */
#define YKPERS_VERSION_NUMBER 0x011400

/**
 * YKPERS_VERSION_MAJOR
 *
 * Pre-processor symbol with a decimal value that describe the major
 * level of the header file version number.  For example, when the
 * header version is 1.2.3 this symbol will be 1.
 */
#define YKPERS_VERSION_MAJOR 1

/**
 * YKPERS_VERSION_MINOR
 *
 * Pre-processor symbol with a decimal value that describe the minor
 * level of the header file version number.  For example, when the
 * header version is 1.2.3 this symbol will be 2.
 */
#define YKPERS_VERSION_MINOR 20

/**
 * YKPERS_VERSION_PATCH
 *
 * Pre-processor symbol with a decimal value that describe the patch
 * level of the header file version number.  For example, when the
 * header version is 1.2.3 this symbol will be 3.
 */
#define YKPERS_VERSION_PATCH 0

const char *ykpers_check_version (const char *req_version);

# ifdef __cplusplus
}
# endif

#endif	/* __YKPERS_VERSION_H_INCLUDED__ */
