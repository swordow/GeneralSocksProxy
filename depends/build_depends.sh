#!/bin/bash
sodium_src=./libsodium-1.0.16
openssl_src=./openssl-1.0.2o
zlib_src=./zlib-1.2.11
curl_src=./curl-7.60.0
microhttpd_src=./libmicrohttpd-0.9.59
cjson_src=./cJSON-1.7.7
ev_src=./libev-4.22
depends_dir=`pwd`/mac
rm -r -f ./mac
rm -r -f ${openssl_src}
rm -r -f ${zlib_src}
rm -r -f ${curl_src}
rm -r -f ${sodium_src}
rm -r -f ${microhttpd_src}
rm -r -f ${cjson_src}
rm -r -f ${ev_src}
unzip ${curl_src}.zip
unzip ${zlib_src}.zip
tar -xf ${openssl_src}.tar.gz
tar -xf ${sodium_src}.tar.gz
tar -xf ${microhttpd_src}.tar.gz
tar -xf ${cjson_src}.tar.gz
tar -xf ${ev_src}.tar.gz
cd ${zlib_src}
./configure --static --prefix=${depends_dir}
make
make install
cd ../${openssl_src}
./Configure --prefix=${depends_dir} zlib --with-zlib-include=${depends_dir}/include --with-zlib-lib=${depends_dir}/lib no-shared darwin64-x86_64-cc
make 
make install
cd ../${curl_src}
./configure --prefix=${depends_dir} --enable-shared=no --enable-static=yes --with-zlib=${depends_dir} --with-ssl=${depends_dir} --disable-ldap --disable-symbol-hiding
make
make install

cd ../${sodium_src}
./configure --prefix=${depends_dir} --enable-minimal --enable-shared=no --enable-static=yes
make 
make install

cd ../${microhttpd_src}
./configure --prefix=${depends_dir} --enable-shared=no --enable-static=yes --with-libcurl=${depends_dir} --enable-poll=auto --enable-epoll=auto --enable-https=no --disable-doc --disable-examples --enable-itc=auto
make
make install

cd ../${cjson_src}
make static
cp libcjson.a ../mac/lib
cp cJSON.h ../mac/include

cd ../${ev_src}
./configure --prefix=${depends_dir} --enable-shared=no --enable-static=yes
make
make install

cd ..
rm -r -f ${openssl_src}
rm -r -f ${zlib_src}
rm -r -f ${curl_src}
rm -r -f ${sodium_src}
rm -r -f ${microhttpd_src}
rm -r -f ${cjson_src}
rm -r -f ${ev_src}
