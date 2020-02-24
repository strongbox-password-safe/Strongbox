/* -*- mode:C; c-file-style: "bsd" -*- */
/* Copyright (c) 2008-2012 Yubico AB
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

#ifndef	__YKPBKDF2_H_INCLUDED__
#define	__YKPBKDF2_H_INCLUDED__

#include <stddef.h>
#include <stdint.h>

typedef struct yk_prf_context YK_PRF_CTX;
typedef struct yk_prf_method YK_PRF_METHOD;
struct yk_prf_method {
	size_t output_size;
	int (*prf_fn)(const char *key, size_t key_len,
		      const char *text, size_t text_len,
		      uint8_t *output, size_t output_size);
};

int yk_hmac_sha1(const char *key, size_t key_len,
		const char *text, size_t text_len,
		uint8_t *output, size_t output_size);

int yk_pbkdf2(const char *passphrase,
	      const unsigned char *salt, size_t salt_len,
	      unsigned int iterations,
	      unsigned char *dk, size_t dklen,
	      YK_PRF_METHOD *prf_method);

#endif
