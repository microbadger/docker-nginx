FROM alpine:3.4

MAINTAINER "Silas Rech" <silas@thynx.io>

ENV NGX_VERSION=1.10.1 \
    NGX_GPG_KEY=B0F4253373F8F6F510D42178520A9993A1C052F8 \
    NGX_CONFIG="\
  	--prefix=/etc/nginx \
  	--sbin-path=/usr/sbin/nginx \
  	--modules-path=/usr/lib/nginx/modules \
  	--conf-path=/etc/nginx/nginx.conf \
  	--error-log-path=/var/log/nginx/error.log \
  	--http-log-path=/var/log/nginx/access.log \
  	--pid-path=/var/run/nginx.pid \
  	--lock-path=/var/run/nginx.lock \
  	--http-client-body-temp-path=/var/cache/nginx/client_temp \
  	--http-proxy-temp-path=/var/cache/nginx/proxy_temp \
  	--http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
  	--http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
  	--http-scgi-temp-path=/var/cache/nginx/scgi_temp \
  	--user=nginx \
  	--group=nginx \
  	--with-http_ssl_module \
  	--with-http_realip_module \
  	--with-http_gunzip_module \
  	--with-http_gzip_static_module \
  	--with-http_secure_link_module \
  	--with-http_stub_status_module \
  	--with-threads \
  	--with-stream \
  	--with-stream_ssl_module \
  	--with-file-aio \
  	--with-http_v2_module \
  	--with-ipv6 \
  	--add-module=/usr/src/brotli \
  	--add-module=/usr/src/transparency \
  	--add-module=/usr/src/cors \
  	--without-http_ssi_module \
  	--without-http_uwsgi_module \
  	--without-http_scgi_module \
  	--without-http_empty_gif_module \
  	--without-http_autoindex_module \
  	"

COPY * /usr/src/bolt/

RUN \
  addgroup -S nginx \
	&& adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx \
	&& apk add --no-cache --virtual .build-deps \
		gcc \
		g++ \
		libc-dev \
		make \
		openssl-dev \
		pcre-dev \
		zlib-dev \
		linux-headers \
		curl \
		gnupg \
		sed \
	&& curl -fSL https://nginx.org/download/nginx-$NGX_VERSION.tar.gz -o nginx.tar.gz \
	&& curl -fSL https://nginx.org/download/nginx-$NGX_VERSION.tar.gz.asc  -o nginx.tar.gz.asc \
	&& curl -fSL https://github.com/cloudflare/ngx_brotli_module/archive/master.tar.gz -o brotli.tar.gz \
	&& curl -fSL https://github.com/grahamedgecombe/nginx-ct/archive/master.tar.gz -o transparency.tar.gz \
	&& curl -fSL https://github.com/nginx-lover/ngx_http_cors_filter/archive/master.tar.gz -o cors.tar.gz \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$NGX_GPG_KEY" \
	&& gpg --batch --verify nginx.tar.gz.asc nginx.tar.gz \
	&& rm -r "$GNUPGHOME" nginx.tar.gz.asc \
	&& mkdir -p /usr/src \
	&& tar -zxC /usr/src -f nginx.tar.gz \
	&& tar -zxC /usr/src -f brotli.tar.gz \
	&& tar -zxC /usr/src -f transparency.tar.gz \
	&& tar -zxC /usr/src -f cors.tar.gz \
	&& mv /usr/src/ngx_brotli_module-master /usr/src/brotli \
	&& mv /usr/src/nginx-ct-master /usr/src/transparency \
	&& mv /usr/src/ngx_http_cors_filter-master /usr/src/cors \
	&& rm nginx.tar.gz \
	&& rm brotli.tar.gz \
	&& rm transparency.tar.gz \
	&& rm cors.tar.gz \
	&& cd /usr/src/nginx-$NGX_VERSION \
	&& sed -i -e 's/"Server: nginx"/"Server: Bolt ϟ"/g' src/http/ngx_http_header_filter_module.c \
	&& sed -i -e 's/"Server: " NGINX_VER CRLF/"Server: Bolt ϟ \/ 1.10.1" CRLF/g' src/http/ngx_http_header_filter_module.c \
	&& ./configure $NGX_CONFIG \
	&& make \
	&& make install \
	&& rm -rf /etc/nginx/html/ \
	&& mkdir /etc/nginx/conf.d/ \
	&& mkdir -p /usr/share/nginx/html/ \
	&& cd / \
	&& install -m644 /usr/src/bolt/index.html /usr/share/nginx/html/ \
	&& install -m644 /usr/src/bolt/error.html /usr/share/nginx/html/ \
	&& install -m644 /usr/src/bolt/nginx.conf /etc/nginx/ \
	&& install -m644 /usr/src/bolt/host.conf  /etc/nginx/conf.d/ \
	&& strip /usr/sbin/nginx* \
	&& runDeps="$( \
		scanelf --needed --nobanner /usr/sbin/nginx \
			| awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
			| sort -u \
			| xargs -r apk info --installed \
			| sort -u \
	)" \
	&& apk add --virtual .nginx-rundeps $runDeps \
	&& apk del .build-deps \
	&& rm -rf /usr/src/nginx-$NGX_VERSION \
	&& rm -rf /usr/src/bolt \
	&& rm -rf /usr/src/brotli \
	&& rm -rf /usr/src/transparency \
	&& rm -rf /usr/src/cors \
	&& apk add --no-cache gettext \
	&& ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log

EXPOSE 80/tcp 443/tcp

CMD ["nginx", "-g", "daemon off;"]
