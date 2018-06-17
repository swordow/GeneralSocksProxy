//
//  Created by Swordow on 2018/6/14.
//
#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <memory.h>
#include <string.h>
#include "ss_common.h"
#include "log.h"
#define LOG_LEN 65535
#define VBUF(buf,fmt) \
    va_list args;\
    va_start(args, (fmt));\
    vsprintf(&(buf)[strlen((buf))], (fmt), args);\
    va_end(args);

char* get_buffer()
{
    static int idx = -1;
    idx++;
    static char* buf[4] = {0};
    if (buf[idx%4] == 0)
    {
        buf[idx%4] = (char*)malloc(LOG_LEN);
    }
    memset(buf[idx%4], 0, LOG_LEN);
    return buf[idx%4];
}
void log_error(const char* fmt, ...)
{
    char* buf = get_buffer();
    strcpy(buf,"Error:");
    VBUF(buf, fmt)
    printf("%s",buf);
}

void log_info(const char* fmt, ...)
{
    char* buf = get_buffer();
    strcpy(buf,"Info:");
    VBUF(buf, fmt)
    printf("%s",buf);
}

void logln_error(const char* fmt, ...)
{
    char* buf = get_buffer();
    strcpy(buf,"Error:");
    VBUF(buf, fmt)
    printf("%s\n",buf);
}

void logln_info(const char* fmt, ...)
{
    char* buf = get_buffer();
    strcpy(buf,"Info:");
    VBUF(buf, fmt)
    printf("%s\n",buf);
}
