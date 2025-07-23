FROM ubuntu:24.04 AS builder

ENV OPENRESTY_VERSION 1.27.1.2
ENV OPENRESTY_DIST_SUFFIX harness

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

# prepare sources:
# ----------------
# 1.nginx
RUN mkdir -p /tmp/openresty
WORKDIR /tmp/openresty
RUN wget https://openresty.org/download/openresty-1.25.3.2.tar.gz
RUN tar xvzf openresty-1.25.3.2.tar.gz
# 2.connect module
RUN git clone https://github.com/mredolatti/ngx_http_proxy_connect_module.git
RUN cd ngx_http_proxy_connect_module && git checkout 45a91e6 
# 3.jwt module
RUN git clone https://github.com/kjdev/nginx-auth-jwt
# 4. digest auth module
RUN git clone https://github.com/mredolatti/nginx-http-auth-digest
RUN cd nginx-http-auth-digest && git checkout e6e0fe8

# build openresty with support for modules above
WORKDIR /tmp/openresty/openresty-1.25.3.2
RUN ./configure \
    --add-module=../ngx_http_proxy_connect_module \
    --add-module=../nginx-auth-jwt \
    --add-module=../nginx-http-auth-digest \
    --sbin-path=/opt/openresty/sbin/nginx \
    --conf-path=/opt/openresty/conf/nginx.conf \
    --pid-path=/var/run/nginx.pid \
    --error-log-path=/var/log/nginx/access.log \
    --http-log-path=/var/log/nginx/error.log
RUN patch -d build/nginx-1.25.3/ -p 1 < ../ngx_http_proxy_connect_module/patch/proxy_connect_rewrite_102101.patch
RUN make
RUN make install
RUN make DESTDIR=/tmp/openresty-bin install

# generate distributable package
WORKDIR /tmp/openresty-bin
RUN find . -type f -print > ../dist.lst
RUN tar zcvf /tmp/openresty-${OPENRESTY_VERSION}-${OPENRESTY_DIST_SUFFIX}.tar.gz $(cat ../dist.lst)


# ------------


FROM ubuntu:24.04 AS runner


ENV OPENRESTY_VERSION 1.27.1.2
ENV OPENRESTY_DIST_SUFFIX harness

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

# setup running user
RUN groupadd --system --gid 101 nginx
RUN useradd --system --gid nginx --no-create-home --home /nonexistent --comment "nginx user" --shell /bin/false --uid 101 nginx
RUN chown -R :nginx /var/log/nginx
RUN chown -R :nginx /opt/openresty
RUN chown -R :nginx /etc/nginx
RUN chown -R :nginx /var/run/nginx
RUN chmod -R g+rwx /etc/nginx
RUN chmod g+x /opt/openresty/scripts/entrypoint.sh
RUN chmod g+x /opt/openresty/sbin/nginx
RUN chmod g+rw /var/run/nginx
USER nginx

ENTRYPOINT ["/opt/openresty/scripts/entrypoint.sh"]
