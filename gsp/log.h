//
//  log.h
//
//  Created by Swordow on 2018/6/14.
//

#ifndef __LOG_H__
#define __LOG_H__

#include <stdio.h>

void log_error(const char* fmt, ...);
void log_info(const char* fmt, ...);
void logln_error(const char* fmt, ...);
void logln_info(const char* fmt, ...);
#endif // __LOG_H__
