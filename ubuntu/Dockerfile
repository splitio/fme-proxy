FROM ubuntu:24.04 AS builder

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
    libluajit-5.1-2 \
    libluajit-5.1-common \
    libluajit-5.1-dev \
    luajit \
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
RUN git clone https://github.com/chobits/ngx_http_proxy_connect_module.git
# 3.jwt module
RUN git clone https://github.com/kjdev/nginx-auth-jwt
# 4. digest auth module
RUN git clone https://github.com/mredolatti/nginx-http-auth-digest
RUN cd nginx-http-auth-digest && git checkout ngx_proxy_connect_support

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

RUN bash -c mkdir -p /etc/nginx/{conf,credentials}
RUN bash -c mkdir -p /var/{run,log/nginx}
RUN ln -s /dev/stdout /var/log/nginx/access.log
RUN ln -s /dev/stderr /var/log/nginx/error.log

COPY conf /opt/openresty/conf
COPY lua /opt/openresty/lua
COPY scripts /opt/openresty/scripts

ENTRYPOINT ["/opt/openresty/scripts/entrypoint.sh"]
