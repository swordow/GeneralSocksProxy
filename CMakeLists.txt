cmake_minimum_required(VERSION 3.4)
set(PROJECT GeneralSocksProxy)
project(${PROJECT})
set(GeneralSocksProxy_SOURCE 
	gsp/encrypt.c	
	gsp/local.c
	gsp/log.c 
	gsp/pac.c 
	gsp/ss_worker.c 
	gsp/table.c
	gsp/webserver.c 
	gsp/webserver.h 
	gsp/table.h 
	gsp/log.h
	gsp/pac.h
	gsp/ss_common.h
	gsp/local.h
	gsp/encrypt.h
	gsp/socks5.h
	gsp/configuration.h 
	gsp/configuration.c
)
set(GeneralSocksProxy_OSX_SOURCE 
	gsp_osx/main.m 
	gsp_osx/proxy_conf.m
	gsp_osx/proxy_conf.h
	gsp_osx/SWBApplication.h 
	gsp_osx/SWBApplication.m 
	gsp_osx/SWBAppDelegate.h 
	gsp_osx/SWBAppDelegate.m 
	gsp_osx/SWBConfigWindowController.h 
	gsp_osx/SWBConfigWindowController.m 
	gsp_osx/SWBQRCodeWindowController.h 
	gsp_osx/SWBQRCodeWindowController.m
	gsp_osx/SWBPACUpdateWindowController.h 
	gsp_osx/SWBPACUpdateWindowController.m 
)
set(RESOURCES
  gsp_osx/Application.xib
  gsp_osx/menu_icon_disabled.png
  gsp_osx/menu_icon_disabled@2x.png
  gsp_osx/menu_icon.png
  gsp_osx/menu_icon@2x.png
  gsp_osx/QRCodeWindow.xib
  gsp_osx/Images.xcassets
  gsp_osx/jquery.min.js 
  gsp_osx/qrcode.htm 
  gsp_osx/qrcode.min.js 
  gsp_osx/GeneralSocksProxy-Info.plist
  gsp_osx/abp.js
  gsp_osx/ConfigWindow.xib
  gsp_osx/PACUpdateWindow.xib
  gsp_osx/proxy.pac
)
set(LIBS 
	${CMAKE_SOURCE_DIR}/depends/mac/lib/libz.a
	${CMAKE_SOURCE_DIR}/depends/mac/lib/libcJSON.a
	${CMAKE_SOURCE_DIR}/depends/mac/lib/libcrypto.a
	${CMAKE_SOURCE_DIR}/depends/mac/lib/libcurl.a
	${CMAKE_SOURCE_DIR}/depends/mac/lib/libev.a
	${CMAKE_SOURCE_DIR}/depends/mac/lib/libmicrohttpd.a
	${CMAKE_SOURCE_DIR}/depends/mac/lib/libsodium.a
	${CMAKE_SOURCE_DIR}/depends/mac/lib/libssl.a
)
set(TARGET GeneralSocksProxy)
include_directories(${CMAKE_SOURCE_DIR}/gsp ${CMAKE_SOURCE_DIR}/depends/mac/include)
#link_directories(${CMAKE_SOURCE_DIR}/depends/mac/lib)
add_executable(${TARGET} MACOSX_BUNDLE ${GeneralSocksProxy_SOURCE} ${GeneralSocksProxy_OSX_SOURCE} ${RESOURCES})
set_target_properties(${TARGET} PROPERTIES RESOURCE "${RESOURCES}")
set_target_properties(${TARGET} PROPERTIES 
	XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_APPICON_NAME "AppIcon"
	 XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC YES)
set_target_properties(${TARGET} PROPERTIES MACOSX_BUNDLE_INFO_PLIST ${CMAKE_SOURCE_DIR}/gsp_osx/GeneralSocksProxy-Info.plist)
target_link_libraries(${TARGET} 
	${LIBS}
	"-framework Foundation"
	"-framework QuartzCore"
	"-framework Cocoa"
	"-framework Security"
	"-framework WebKit"
	"-framework SystemConfiguration")
