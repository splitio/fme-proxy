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

# build openresty with support for modules above
WORKDIR /tmp/openresty/openresty-1.25.3.2
RUN ./configure \
    --add-module=../ngx_http_proxy_connect_module \
    --add-module=../nginx-auth-jwt
RUN patch -d build/nginx-1.25.3/ -p 1 < ../ngx_http_proxy_connect_module/patch/proxy_connect_rewrite_102101.patch
RUN make
RUN make install

COPY conf /usr/local/openresty/nginx/conf
COPY scripts /usr/local/openresty/nginx/scripts
RUN mkdir -p /var/jwt/keys

EXPOSE 3128

#ENTRYPOINT ["sleep", "10000"]
ENTRYPOINT ["/usr/local/openresty/nginx/sbin/nginx", "-g", "daemon off;"]
