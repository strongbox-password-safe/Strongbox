/* -*- mode:C; c-file-style: "bsd" -*- */
/*
 * Copyright (c) 2008-2014 Yubico AB
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

#ifndef	__YKPERS_H_INCLUDED__
#define	__YKPERS_H_INCLUDED__

#include <stddef.h>
#include <stdbool.h>
#include <ykstatus.h>
#include <ykdef.h>

# ifdef __cplusplus
extern "C" {
# endif

typedef struct ykp_config_t YKP_CONFIG;

/* This only works with Yubikey 1 unless it's fed with a YK_STATUS using
   ykp_configure_for(). */
YKP_CONFIG *ykp_create_config(void);
int ykp_free_config(YKP_CONFIG *cfg);

/* allocate an empty YKP_CONFIG, use ykp_configure_version() to set
   version information. */
YKP_CONFIG *ykp_alloc(void);

/* Set the version information in st in cfg. */
void ykp_configure_version(YKP_CONFIG *cfg, YK_STATUS *st);

/* This is used to tell what YubiKey version we're working with and what
   command we want to send to it. If this isn't used YubiKey 1 only will
   be assumed. */
int ykp_configure_command(YKP_CONFIG *cfg, uint8_t command);
/* wrapper function for ykp_configure_command */
int ykp_configure_for(YKP_CONFIG *cfg, int confnum, YK_STATUS *st);

int ykp_AES_key_from_hex(YKP_CONFIG *cfg, const char *hexkey);
int ykp_AES_key_from_raw(YKP_CONFIG *cfg, const char *key);
int ykp_AES_key_from_passphrase(YKP_CONFIG *cfg, const char *passphrase,
				const char *salt);
int ykp_HMAC_key_from_hex(YKP_CONFIG *cfg, const char *hexkey);
int ykp_HMAC_key_from_raw(YKP_CONFIG *cfg, const char *key);

/* Functions for constructing the YK_NDEF struct before writing it to a neo */
YK_NDEF *ykp_alloc_ndef(void);
int ykp_free_ndef(YK_NDEF *ndef);
int ykp_construct_ndef_uri(YK_NDEF *ndef, const char *uri);
int ykp_construct_ndef_text(YK_NDEF *ndef, const char *text, const char *lang, bool isutf16);
int ykp_set_ndef_access_code(YK_NDEF *ndef, unsigned char *access_code);
int ykp_ndef_as_text(YK_NDEF *ndef, char *text, size_t len);

YK_DEVICE_CONFIG *ykp_alloc_device_config(void);
int ykp_free_device_config(YK_DEVICE_CONFIG *device_config);
int ykp_set_device_mode(YK_DEVICE_CONFIG *device_config, unsigned char mode);
int ykp_set_device_chalresp_timeout(YK_DEVICE_CONFIG *device_config, unsigned char timeout);
int ykp_set_device_autoeject_time(YK_DEVICE_CONFIG *device_config, unsigned short eject_time);

int ykp_set_access_code(YKP_CONFIG *cfg, unsigned char *access_code, size_t len);
int ykp_set_fixed(YKP_CONFIG *cfg, unsigned char *fixed, size_t len);
int ykp_set_uid(YKP_CONFIG *cfg, unsigned char *uid, size_t len);
int ykp_set_oath_imf(YKP_CONFIG *cfg, unsigned long imf);
unsigned long ykp_get_oath_imf(const YKP_CONFIG *cfg);

int ykp_set_tktflag_TAB_FIRST(YKP_CONFIG *cfg, bool state);
int ykp_set_tktflag_APPEND_TAB1(YKP_CONFIG *cfg, bool state);
int ykp_set_tktflag_APPEND_TAB2(YKP_CONFIG *cfg, bool state);
int ykp_set_tktflag_APPEND_DELAY1(YKP_CONFIG *cfg, bool state);
int ykp_set_tktflag_APPEND_DELAY2(YKP_CONFIG *cfg, bool state);
int ykp_set_tktflag_APPEND_CR(YKP_CONFIG *cfg, bool state);
int ykp_set_tktflag_PROTECT_CFG2(YKP_CONFIG *cfg, bool state);
int ykp_set_tktflag_OATH_HOTP(YKP_CONFIG *cfg, bool state);
int ykp_set_tktflag_CHAL_RESP(YKP_CONFIG *cfg, bool state);

int ykp_set_cfgflag_SEND_REF(YKP_CONFIG *cfg, bool state);
int ykp_set_cfgflag_TICKET_FIRST(YKP_CONFIG *cfg, bool state);
int ykp_set_cfgflag_PACING_10MS(YKP_CONFIG *cfg, bool state);
int ykp_set_cfgflag_PACING_20MS(YKP_CONFIG *cfg, bool state);
int ykp_set_cfgflag_ALLOW_HIDTRIG(YKP_CONFIG *cfg, bool state);
int ykp_set_cfgflag_STATIC_TICKET(YKP_CONFIG *cfg, bool state);
int ykp_set_cfgflag_SHORT_TICKET(YKP_CONFIG *cfg, bool state);
int ykp_set_cfgflag_STRONG_PW1(YKP_CONFIG *cfg, bool state);
int ykp_set_cfgflag_STRONG_PW2(YKP_CONFIG *cfg, bool state);
int ykp_set_cfgflag_MAN_UPDATE(YKP_CONFIG *cfg, bool state);
int ykp_set_cfgflag_OATH_HOTP8(YKP_CONFIG *cfg, bool state);
int ykp_set_cfgflag_OATH_FIXED_MODHEX1(YKP_CONFIG *cfg, bool state);
int ykp_set_cfgflag_OATH_FIXED_MODHEX2(YKP_CONFIG *cfg, bool state);
int ykp_set_cfgflag_OATH_FIXED_MODHEX(YKP_CONFIG *cfg, bool state);
int ykp_set_cfgflag_CHAL_YUBICO(YKP_CONFIG *cfg, bool state);
int ykp_set_cfgflag_CHAL_HMAC(YKP_CONFIG *cfg, bool state);
int ykp_set_cfgflag_HMAC_LT64(YKP_CONFIG *cfg, bool state);
int ykp_set_cfgflag_CHAL_BTN_TRIG(YKP_CONFIG *cfg, bool state);

int ykp_set_extflag_SERIAL_BTN_VISIBLE(YKP_CONFIG *cfg, bool state);
int ykp_set_extflag_SERIAL_USB_VISIBLE(YKP_CONFIG *cfg, bool state);
int ykp_set_extflag_SERIAL_API_VISIBLE (YKP_CONFIG *cfg, bool state);
int ykp_set_extflag_USE_NUMERIC_KEYPAD (YKP_CONFIG *cfg, bool state);
int ykp_set_extflag_FAST_TRIG (YKP_CONFIG *cfg, bool state);
int ykp_set_extflag_ALLOW_UPDATE (YKP_CONFIG *cfg, bool state);
int ykp_set_extflag_DORMANT (YKP_CONFIG *cfg, bool state);
int ykp_set_extflag_LED_INV (YKP_CONFIG *cfg, bool state);

bool ykp_get_tktflag_TAB_FIRST(const YKP_CONFIG *cfg);
bool ykp_get_tktflag_APPEND_TAB1(const YKP_CONFIG *cfg);
bool ykp_get_tktflag_APPEND_TAB2(const YKP_CONFIG *cfg);
bool ykp_get_tktflag_APPEND_DELAY1(const YKP_CONFIG *cfg);
bool ykp_get_tktflag_APPEND_DELAY2(const YKP_CONFIG *cfg);
bool ykp_get_tktflag_APPEND_CR(const YKP_CONFIG *cfg);
bool ykp_get_tktflag_PROTECT_CFG2(const YKP_CONFIG *cfg);
bool ykp_get_tktflag_OATH_HOTP(const YKP_CONFIG *cfg);
bool ykp_get_tktflag_CHAL_RESP(const YKP_CONFIG *cfg);

bool ykp_get_cfgflag_SEND_REF(const YKP_CONFIG *cfg);
bool ykp_get_cfgflag_TICKET_FIRST(const YKP_CONFIG *cfg);
bool ykp_get_cfgflag_PACING_10MS(const YKP_CONFIG *cfg);
bool ykp_get_cfgflag_PACING_20MS(const YKP_CONFIG *cfg);
bool ykp_get_cfgflag_ALLOW_HIDTRIG(const YKP_CONFIG *cfg);
bool ykp_get_cfgflag_STATIC_TICKET(const YKP_CONFIG *cfg);
bool ykp_get_cfgflag_SHORT_TICKET(const YKP_CONFIG *cfg);
bool ykp_get_cfgflag_STRONG_PW1(const YKP_CONFIG *cfg);
bool ykp_get_cfgflag_STRONG_PW2(const YKP_CONFIG *cfg);
bool ykp_get_cfgflag_MAN_UPDATE(const YKP_CONFIG *cfg);
bool ykp_get_cfgflag_OATH_HOTP8(const YKP_CONFIG *cfg);
bool ykp_get_cfgflag_OATH_FIXED_MODHEX1(const YKP_CONFIG *cfg);
bool ykp_get_cfgflag_OATH_FIXED_MODHEX2(const YKP_CONFIG *cfg);
bool ykp_get_cfgflag_OATH_FIXED_MODHEX(const YKP_CONFIG *cfg);
bool ykp_get_cfgflag_CHAL_YUBICO(const YKP_CONFIG *cfg);
bool ykp_get_cfgflag_CHAL_HMAC(const YKP_CONFIG *cfg);
bool ykp_get_cfgflag_HMAC_LT64(const YKP_CONFIG *cfg);
bool ykp_get_cfgflag_CHAL_BTN_TRIG(const YKP_CONFIG *cfg);

bool ykp_get_extflag_SERIAL_BTN_VISIBLE(const YKP_CONFIG *cfg);
bool ykp_get_extflag_SERIAL_USB_VISIBLE(const YKP_CONFIG *cfg);
bool ykp_get_extflag_SERIAL_API_VISIBLE (const YKP_CONFIG *cfg);
bool ykp_get_extflag_USE_NUMERIC_KEYPAD (const YKP_CONFIG *cfg);
bool ykp_get_extflag_FAST_TRIG (const YKP_CONFIG *cfg);
bool ykp_get_extflag_ALLOW_UPDATE (const YKP_CONFIG *cfg);
bool ykp_get_extflag_DORMANT (const YKP_CONFIG *cfg);
bool ykp_get_extflag_LED_INV (const YKP_CONFIG *cfg);

int ykp_clear_config(YKP_CONFIG *cfg);

int ykp_write_config(const YKP_CONFIG *cfg,
		     int (*writer)(const char *buf, size_t count,
				   void *userdata),
		     void *userdata);
int ykp_read_config(YKP_CONFIG *cfg,
		    int (*reader)(char *buf, size_t count,
				  void *userdata),
		    void *userdata);

YK_CONFIG *ykp_core_config(YKP_CONFIG *cfg);
int ykp_command(YKP_CONFIG *cfg);
int ykp_config_num(YKP_CONFIG *cfg);

int ykp_export_config(const YKP_CONFIG *cfg, char *buf, size_t len, int format);
int ykp_import_config(YKP_CONFIG *cfg, const char *buf, size_t len, int format);

#define YKP_FORMAT_LEGACY	0x01
#define YKP_FORMAT_YCFG		0x02

void ykp_set_acccode_type(YKP_CONFIG *cfg, unsigned int type);
unsigned int ykp_get_acccode_type(const YKP_CONFIG *cfg);

#define YKP_ACCCODE_NONE	0x01
#define YKP_ACCCODE_RANDOM	0x02
#define YKP_ACCCODE_SERIAL	0x03

int ykp_get_supported_key_length(const YKP_CONFIG *cfg);

extern int * _ykp_errno_location(void);
#define ykp_errno (*_ykp_errno_location())
const char *ykp_strerror(int errnum);

#define YKP_ENOTYETIMPL	0x01
#define YKP_ENOCFG	0x02
#define YKP_EYUBIKEYVER	0x03
#define YKP_EOLDYUBIKEY	0x04
#define YKP_EINVCONFNUM	0x05
#define YKP_EINVAL	0x06
#define YKP_ENORANDOM	0x07

# ifdef __cplusplus
}
# endif

#endif	/* __YKPERS_H_INCLUDED__ */
