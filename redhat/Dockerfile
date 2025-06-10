FROM redhat/ubi10:latest

RUN dnf install -y --setopt=tsflags=nodocs \
    yum-utils \
    nss_wrapper-libs \
    bind-utils \
    gettext \
    hostname \
    wget \
    bzip2 \
    patch \
    git \
    gcc \
    make \
    autoconf \
    automake \
    pcre2 \
    pcre2-devel \
    openssl \
    openssl-devel \
    zlib \
    zlib-devel
RUN yum -y clean all --enablerepo='*'

# prepare sources (& build when needed) :
# ---------------------------------------
RUN mkdir -p /tmp/openresty
WORKDIR /tmp/openresty

# 1. PCRE
RUN wget https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.45/pcre2-10.45.tar.bz2
RUN bzip2 -d pcre2-10.45.tar.bz2
RUN tar xvf pcre2-10.45.tar

# 2. JANSSON (from RH repos to ensure ABI compatibility)
RUN yumdownloader --source jansson
RUN rpm -Uvh jansson-2.14-3.el10.src.rpm && cp /root/rpmbuild/SOURCES/jansson-2.14.tar.bz2 .
RUN bzip2 -d jansson-2.14.tar.bz2 && tar xvf jansson-2.14.tar
RUN pushd jansson-2.14 && ./configure && make && make install && popd

# 3. connect module
RUN git clone https://github.com/chobits/ngx_http_proxy_connect_module.git

# 4. jwt module
RUN git clone https://github.com/kjdev/nginx-auth-jwt

# 5. openresty
RUN wget https://openresty.org/download/openresty-1.27.1.2.tar.gz
RUN tar xvzf openresty-1.27.1.2.tar.gz
WORKDIR /tmp/openresty/openresty-1.27.1.2
RUN ./configure \
    --with-pcre=/tmp/openresty/pcre2-10.45 \
    --add-module=../ngx_http_proxy_connect_module \
    --add-module=../nginx-auth-jwt
RUN patch -d build/nginx-1.27.1/ -p 1 < ../ngx_http_proxy_connect_module/patch/proxy_connect_rewrite_102101.patch
RUN gmake
RUN gmake install

COPY conf /usr/local/openresty/nginx/conf
COPY scripts /usr/local/openresty/nginx/scripts
RUN mkdir -p /var/jwt/keys
COPY keys/keys.jwks /var/jwt/keys/keys.jwks

EXPOSE 3128

ENTRYPOINT ["/usr/local/openresty/nginx/sbin/nginx", "-g", "daemon off;"]
