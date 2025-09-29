FROM redhat/ubi10:latest AS builder

ENV OPENRESTY_VERSION="1.27.1.2"
ENV OPENRESTY_NGINX_CORE_VERSION="1.27.1"
ENV OPENRESTY_NGX_CONNECT_PATCH_VERSION="102101"
ENV OPENRESTY_DIST_SUFFIX="harness"
ENV PCRE2_VERSION="10.45"

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
    openssl \
    openssl-devel \
    zlib \
    zlib-devel
RUN yum -y clean all --enablerepo='*'

# prepare sources (& build when needed) :
# ---------------------------------------
RUN mkdir -p /tmp/openresty
WORKDIR /tmp/openresty

# TODO: REMOVE THIS ONCE proxy_thru repo is public
COPY .netrc /root

# 1. PCRE
RUN wget https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.45/pcre2-${PCRE2_VERSION}.tar.bz2
RUN bzip2 -d pcre2-${PCRE2_VERSION}.tar.bz2
RUN tar xvf pcre2-${PCRE2_VERSION}.tar

# 2. JANSSON (from RH repos to ensure ABI compatibility)
RUN yumdownloader --source jansson
RUN rpm -Uvh jansson-2.14-3.el10.src.rpm && cp /root/rpmbuild/SOURCES/jansson-2.14.tar.bz2 .
RUN bzip2 -d jansson-2.14.tar.bz2 && tar xvf jansson-2.14.tar
RUN pushd jansson-2.14 && ./configure && make && make install && popd

# 3. connect module
RUN git clone https://github.com/chobits/ngx_http_proxy_connect_module.git
RUN cd ngx_http_proxy_connect_module && git checkout v0.0.7

# 4. jwt auth module
RUN git clone https://github.com/kjdev/nginx-auth-jwt

# 5. digest auth module
RUN git clone https://github.com/mredolatti/nginx-http-auth-digest
RUN cd nginx-http-auth-digest && git checkout e6e0fe8

# 5. proxy-thru module
RUN git clone https://github.com/splitio/ngx_http_proxy_thru_module
RUN cd ngx_http_proxy_thru_module && git checkout 3151b03

# 6. openresty
RUN wget https://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz
RUN tar xvzf openresty-${OPENRESTY_VERSION}.tar.gz

WORKDIR /tmp/openresty/openresty-${OPENRESTY_VERSION}
RUN ./configure \
    --prefix=/usr \
    --with-http_stub_status_module \
    --with-pcre=/tmp/openresty/pcre2-${PCRE2_VERSION} \
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

RUN gmake
RUN gmake DESTDIR=/tmp/openresty-bin install

# generate distributable package
WORKDIR /tmp/openresty-bin
RUN find . -type f -print > ../dist.lst
RUN tar zcvf /tmp/openresty-${OPENRESTY_VERSION}-${OPENRESTY_DIST_SUFFIX}.tar.gz $(cat ../dist.lst)


# ------------


FROM redhat/ubi10:latest AS runner

USER root

ENV OPENRESTY_VERSION="1.27.1.2"
ENV OPENRESTY_DIST_SUFFIX="harness"

RUN dnf install -y --setopt=tsflags=nodocs \
    jansson gdb procps

COPY --from=builder /tmp/openresty-${OPENRESTY_VERSION}-${OPENRESTY_DIST_SUFFIX}.tar.gz /
RUN tar xvzf openresty-${OPENRESTY_VERSION}-${OPENRESTY_DIST_SUFFIX}.tar.gz

# setup shared libraries
RUN ln -s /usr/luajit/lib/libluajit-5.1.so.2.1.ROLLING /usr/local/lib/libluajit-5.1.so.2

# setup logging
RUN bash -c 'mkdir -p /var/{run,log/nginx}'
RUN ln -s /dev/stdout /var/log/nginx/access.log
RUN ln -s /dev/stderr /var/log/nginx/error.log

# copy custom configs & scripts
RUN bash -c 'mkdir -p /etc/nginx/{conf,credentials}'
COPY conf /opt/openresty/conf
COPY lua /opt/openresty/lua
COPY scripts /opt/openresty/scripts

RUN mkdir -p /var/run/nginx
RUN mkdir -p /etc/nginx/lua

# setup empty document root
RUN mkdir -p /var/www
RUN touch /var/www/index.html
RUN touch /var/www/error.html

# setup version
COPY VERSION /.version

# setup group permissions
RUN chown -R :root /var/log/nginx
RUN chown -R :root /opt/openresty
RUN chown -R :root /etc/nginx
RUN chown -R :root /var/run/nginx
RUN chmod -R g=u /etc/nginx
RUN chmod -R g=u /opt/openresty
RUN chmod -R g=u /var/log/nginx
RUN chmod -R g=u /var/run/nginx
RUN chmod -R 555 /var/www

ENTRYPOINT ["/opt/openresty/scripts/entrypoint.sh"]
