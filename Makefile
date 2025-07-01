DOCKER ?= docker
DOCKER_COMPOSE ?= docker-compose
CURL ?= curl
OS ?= ubuntu
VERSION := 0.0.1-alpha1


shell:
	$(DOCKER) exec -it fme-proxy-$(OS) bash

docker-build:
	$(DOCKER) build \
		-t fme-proxy-$(OS):$(VERSION) \
		--build-arg FME_PROXY_VERSION="$(VERSION)" \
		-f $(OS)/Dockerfile \
		.

docker-run:
	$(DOCKER) run \
		--rm \
		--name fme-proxy-$(OS) \
		-p "8080:80" -p "3128:3128" -p "3129:3129" -p "3130:3130" -p "3131:3131" -p "3132:3132" \
		-e TZ="UTC" \
		-e HFP_PROXIES=tls,mtls,basic,digest,bearer \
		-e HFP_DEBUG_CONF="true" \
		-e HFP_USER="root" \
		-e HFP_tls_PORT=3128 \
		-e HFP_tls_SSL="true" \
		-e HFP_tls_SSL_CERTIFICATE=/etc/ssl/proxy/proxy.crt \
		-e HFP_tls_SSL_PRIVATE_KEY=/etc/ssl/proxy/proxy.key \
		-e HFP_mtls_PORT=3129 \
		-e HFP_mtls_SSL="true" \
		-e HFP_mtls_SSL_CERTIFICATE=/etc/ssl/proxy/proxy.crt \
		-e HFP_mtls_SSL_PRIVATE_KEY=/etc/ssl/proxy/proxy.key \
		-e HFP_mtls_SSL_CLIENT_CERTIFICATE=/etc/ssl/proxy/ca.crt \
		-e HFP_basic_PORT=3130 \
		-e HFP_basic_SSL="true" \
		-e HFP_basic_SSL_CERTIFICATE=/etc/ssl/proxy/proxy.crt \
		-e HFP_basic_SSL_PRIVATE_KEY=/etc/ssl/proxy/proxy.key \
		-e HFP_basic_AUTH=basic \
		-e HFP_basic_AUTH_BASIC_PASSWD=/etc/nginx/passwd/basic.passwd \
		-e HFP_bearer_PORT=3131 \
		-e HFP_bearer_SSL="true" \
		-e HFP_bearer_SSL_CERTIFICATE=/etc/ssl/proxy/proxy.crt \
		-e HFP_bearer_SSL_PRIVATE_KEY=/etc/ssl/proxy/proxy.key \
		-e HFP_bearer_AUTH=bearer \
		-e HFP_bearer_AUTH_BEARER_JWKS=/etc/nginx/keys/keys.jwks \
		-e HFP_digest_PORT=3132 \
		-e HFP_digest_AUTH=digest \
		-e HFP_digest_AUTH_DIGEST_PASSWD=/etc/nginx/passwd/digest.passwd \
		--volume "${PWD}/certs/proxy/:/etc/ssl/proxy" \
		--volume "${PWD}/passwd:/etc/nginx/passwd" \
		--volume "${PWD}/keys:/etc/nginx/keys" \
		fme-proxy-$(OS):$(VERSION)


req_noauth_tls:
	$(CURL) \
		-v \
		--proxy https://harness-fproxy:3128 \
		--proxy-cacert certs/client/ca.crt \
		-XGET https://www.stallman.org 

req_noauth_mtls:
	$(CURL) \
		-v \
		--proxy https://harness-fproxy:3129 \
		--proxy-cacert certs/client/ca.crt \
		--proxy-cert certs/client/client.crt \
		--proxy-key certs/client/client.key \
		-XGET https://www.stallman.org

req_basic_tls:
	$(CURL) \
		-v \
		-XGET https://www.stallman.org \
		--proxy https://harness-fproxy:3130 \
		--proxy-basic \
		--proxy-user "doc:lleguevolando" \
		--proxy-cacert certs/client/ca.crt 

req_bearer_tls:
	$(CURL) \
		-v \
		--proxy https://harness-fproxy:3131 \
		--proxy-cacert certs/client/ca.crt \
		--proxy-header 'Proxy-Authorization: Bearer $(TOKEN)' \
		-XGET https://www.stallman.org

req_digest_plain:
	$(CURL) \
		-v \
		-XGET \
		--proxy http://harness-fproxy:3132 \
		--proxy-digest \
		--proxy-user "doc:lleguevolando" \
		https://www.stallman.org 
