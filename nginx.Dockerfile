FROM alpine

ENV ALPINE_VERSION v3.20
ENV NGINX_VERSION 1.26.2
ENV NGINX_PREFIX /etc/nginx
ENV TMP_DIR /tmp/build_tmp

RUN apk add --no-cache curl mc htop krb5 pcre libgcc
RUN set -x \
 && apk add --no-cache --virtual .build-deps bash gcc libc-dev make g++ openssl-dev pcre-dev zlib-dev linux-headers curl gnupg libxslt-dev gd-dev geoip-dev git krb5-dev \
 && mkdir ${TMP_DIR} \
 && chown nobody:nobody ${TMP_DIR} \
 && cd ${TMP_DIR} \
 #Nginx
 && wget "http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" \
 && tar xzf ${TMP_DIR}/nginx-${NGINX_VERSION}.tar.gz \
 #SPNEGO
 && git clone https://github.com/stnoonan/spnego-http-auth-nginx-module.git ${TMP_DIR}/nginx-${NGINX_VERSION}/spnego-http-auth-nginx-module \
 #LUA 
 && git clone https://github.com/openresty/lua-nginx-module.git 	${TMP_DIR}/nginx-${NGINX_VERSION}/lua-nginx-module \
 && git clone https://github.com/vision5/ngx_devel_kit.git 			${TMP_DIR}/nginx-${NGINX_VERSION}/ngx_devel_kit \
 && git clone https://github.com/openresty/luajit2.git 				${TMP_DIR}/luajit2 \
 && git clone https://github.com/openresty/lua-resty-core.git 		${TMP_DIR}/lua-resty-core \
 && git clone https://github.com/openresty/lua-resty-lrucache.git 	${TMP_DIR}/lua-resty-lrucache \
 && cd ${TMP_DIR}/luajit2 \
 && make -j2 \
 && make install \
 && export LUAJIT_LIB=/usr/local/bin \
 && export LUAJIT_INC=/usr/local/include/luajit-2.1 \
 && cd ${TMP_DIR}/nginx-${NGINX_VERSION} \
 && ./configure \
 	--user=nginx \
	--group=nginx \ 
	--prefix=${NGINX_PREFIX} \
	--sbin-path=/usr/sbin/nginx \ 
	--modules-path=/usr/lib/nginx/modules \ 
	--conf-path=${NGINX_PREFIX}/nginx.conf \ 
	--error-log-path=/var/log/nginx/error.log \ 
	--http-log-path=/var/log/nginx/access.log \ 
	--pid-path=/var/run/nginx.pid \
	--lock-path=/var/run/nginx.lock \ 
	--http-client-body-temp-path=/var/cache/nginx/client_temp \ 
	--http-proxy-temp-path=/var/cache/nginx/proxy_temp \ 
	--http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \ 
	--http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \ 
	--http-scgi-temp-path=/var/cache/nginx/scgi_temp \ 
	--with-perl_modules_path=/usr/lib/perl5/vendor_perl \ 
	--with-compat \ 
	--with-file-aio \ 
	--with-threads \ 
	--with-http_addition_module \
	--with-http_auth_request_module \ 
	--with-http_dav_module \ 
	--with-http_flv_module \
	--with-http_gunzip_module \
	--with-http_gzip_static_module \
	--with-http_mp4_module \
	--with-http_random_index_module \
	--with-http_realip_module \
	--with-http_secure_link_module \
	--with-http_slice_module \
	--with-http_ssl_module \
	--with-http_stub_status_module \
	--with-http_sub_module \
	--with-http_v2_module \
	--with-http_v3_module \
	--with-mail \
	--with-mail_ssl_module \
	--with-stream \
	--with-stream_realip_module \
	--with-stream_ssl_module \
	--with-stream_ssl_preread_module \ 
	--with-cc-opt='-Os -fstack-clash-protection -Wformat -Werror=format-security -fno-plt -g' \ 
	--with-ld-opt='-Wl,--as-needed,-O1,--sort-common -Wl,-z,pack-relative-relocs -Wl,-rpath,/usr/local/bin' \	
	--add-module=spnego-http-auth-nginx-module \
	--add-module=ngx_devel_kit \
	--add-module=lua-nginx-module \
 && make -j2 \
 && make install \
 && cd ${TMP_DIR}/lua-resty-core \
 && make install PREFIX=${NGINX_PREFIX} \
 && cd ${TMP_DIR}/lua-resty-lrucache \
 && make install PREFIX=${NGINX_PREFIX} \
 && cd ${TMP_DIR}/nginx-${NGINX_VERSION} \
 && sed -i -e 's/#access_log  logs\/access.log  main;/access_log \/dev\/stdout;/' -e 's/#error_log  logs\/error.log  notice;/error_log stderr notice;/' ${NGINX_PREFIX}/nginx.conf \
 && sed -i -e "/\http {/a \\\t lua_package_path \"${NGINX_PREFIX}/lib/lua/?.lua;;\";" ${NGINX_PREFIX}/nginx.conf \
 && adduser -D nginx \
 && mkdir -p /var/cache/nginx \
 && cd / \
 && rm -rf ${TMP_DIR} \
 && apk del .build-deps \
 && rm -rf /var/cache/apk/*
 
EXPOSE 80

STOPSIGNAL SIGTERM

CMD ["nginx", "-g", "daemon off;"]