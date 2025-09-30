FROM ubuntu:24.04 AS builder

ENV OPENRESTY_VERSION="1.27.1.2"
ENV OPENRESTY_NGINX_CORE_VERSION="1.27.1"
ENV OPENRESTY_NGX_CONNECT_PATCH_VERSION="102101"
ENV OPENRESTY_DIST_SUFFIX="harness"

# setup build capabilities & enable source package retrieval
RUN apt update -y
RUN apt full-upgrade -y
RUN DEBIAN_FRONTEND=noninteractive apt install \
    build-essential \
    ca-certificates \
    tzdata \
    cmake \
    wget \
    git \
    libpcre3 \
    libpcre3-dev \
    zlib1g \
    zlib1g-dev \
    libjansson-dev \
    libssl-dev \
    gawk \
    -y 
RUN DEBIAN_FRONTEND=noninteractive apt remove --purge --auto-remove -y

RUN mkdir -p /tmp/openresty
WORKDIR /tmp/openresty

# TODO: REMOVE THIS ONCE proxy_thru repo is public
COPY .netrc /root

# prepare sources:
# ----------------
# 1.nginx
RUN wget https://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz
RUN tar xvzf openresty-${OPENRESTY_VERSION}.tar.gz

# 2.connect module
RUN git clone https://github.com/chobits/ngx_http_proxy_connect_module.git
RUN cd ngx_http_proxy_connect_module && git checkout v0.0.7

# 3.jwt module
RUN git clone https://github.com/kjdev/nginx-auth-jwt

# 4. digest auth module
RUN git clone https://github.com/mredolatti/nginx-http-auth-digest
RUN cd nginx-http-auth-digest && git checkout e6e0fe8

# 5. proxy-thru module
RUN git clone https://github.com/splitio/ngx_http_proxy_thru_module
RUN cd ngx_http_proxy_thru_module && git checkout 1.0.0

# build openresty with support for modules above
WORKDIR /tmp/openresty/openresty-${OPENRESTY_VERSION}
RUN ./configure \
    --with-http_stub_status_module \
    --add-module=../ngx_http_proxy_connect_module \
    --add-module=../ngx_http_proxy_thru_module \
    --add-module=../nginx-auth-jwt \
    --add-module=../nginx-http-auth-digest \
    --sbin-path=/opt/openresty/sbin/nginx \
    --pid-path=/var/run/nginx.pid \
    --error-log-path=/var/log/nginx/access.log \
    --http-log-path=/var/log/nginx/error.log
RUN patch \
    --directory build/nginx-${OPENRESTY_NGINX_CORE_VERSION}/ \
    --strip 1 \
    < ../ngx_http_proxy_connect_module/patch/proxy_connect_rewrite_${OPENRESTY_NGX_CONNECT_PATCH_VERSION}.patch
RUN patch \
    --directory build/nginx-${OPENRESTY_NGINX_CORE_VERSION}/ \
    --strip 1 \
    < ../ngx_http_proxy_thru_module/patches/nginx-${OPENRESTY_NGINX_CORE_VERSION}.patch
RUN patch \
    --directory ../ngx_http_proxy_connect_module/ \
    --strip 1 \
    < ../ngx_http_proxy_thru_module/patches/ngx_http_proxy_connect_module-0.0.7.patch

RUN make
RUN make install
RUN make DESTDIR=/tmp/openresty-bin install

# generate distributable package
WORKDIR /tmp/openresty-bin
RUN find . -type f -print > ../dist.lst
RUN tar zcvf /tmp/openresty-${OPENRESTY_VERSION}-${OPENRESTY_DIST_SUFFIX}.tar.gz $(cat ../dist.lst)


# ------------


FROM ubuntu:24.04 AS runner


ENV OPENRESTY_VERSION="1.27.1.2"
ENV OPENRESTY_DIST_SUFFIX="harness"

RUN apt update -y
RUN apt full-upgrade -y
RUN DEBIAN_FRONTEND=noninteractive apt install \
    ca-certificates \
    tzdata \
    libjansson-dev \
    libpcre3 \
    zlib1g \
    gawk \
    -y

COPY --from=builder /tmp/openresty-${OPENRESTY_VERSION}-${OPENRESTY_DIST_SUFFIX}.tar.gz /
RUN tar xvzf openresty-${OPENRESTY_VERSION}-${OPENRESTY_DIST_SUFFIX}.tar.gz

RUN ln -s /usr/local/openresty/luajit/lib/libluajit-5.1.so.2.1.ROLLING /usr/local/lib/libluajit-5.1.so.2

RUN bash -c 'mkdir -p /var/{run,log/nginx}'
RUN ln -s /dev/stdout /var/log/nginx/access.log
RUN ln -s /dev/stderr /var/log/nginx/error.log

RUN mkdir -p /var/run/nginx
RUN mkdir -p /etc/nginx/lua

RUN bash -c 'mkdir -p /etc/nginx/{conf,credentials}'
COPY conf /opt/openresty/conf
COPY lua /opt/openresty/lua
COPY scripts /opt/openresty/scripts

# setup version
COPY VERSION /.version

# setup empty document root
RUN mkdir -p /var/www
RUN touch /var/www/index.html
RUN touch /var/www/error.html

# setup running user
RUN groupadd --system --gid 101 nginx
RUN useradd --system --gid nginx --no-create-home --home /nonexistent --comment "nginx user" --shell /bin/false --uid 101 nginx
RUN chown -R :nginx /var/log/nginx
RUN chown -R :nginx /opt/openresty
RUN chown -R :nginx /etc/nginx
RUN chown -R :nginx /var/run/nginx
RUN chown -R :nginx /var/www
RUN chmod -R g+rwx /etc/nginx
RUN chmod g+x /opt/openresty/scripts/entrypoint.sh
RUN chmod g+x /opt/openresty/sbin/nginx
RUN chmod g+rw /var/run/nginx
RUN chmod -R 555 /var/www
USER nginx

ENTRYPOINT ["/opt/openresty/scripts/entrypoint.sh"]
