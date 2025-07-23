DOCKER ?= docker
CURL ?= curl
OS ?= ubuntu
PLATFORM ?= linux/arm64/v8,linux/amd64
LOCAL_PLAIN_PORT ?= 3127
LOCAL_TLS_PORT ?= 3128
LOCAL_MTLS_PORT ?= 3129
LOCAL_BASIC_PORT ?= 3130
LOCAL_BEARER_PORT ?= 3131
LOCAL_DIGEST_PORT ?= 3132
TARGET ?= "https://sdk.split.io/version"

VERSION := $(shell head -n1 VERSION)

default: help

## Build docker image (accepts OS=[ubuntu|redhat]
docker-build:
	$(DOCKER) build -t fme-proxy:$(OS)-$(VERSION) -f $(OS)/Dockerfile .

## Run previously built docker image (accepts LOCAL_<server>_PORT to change the local binding)
docker-run:
	$(DOCKER) run \
		--rm \
		--name fme-proxy-$(OS)-$(VERSION) \
		-p "8080:80" \
		-p "$(LOCAL_PLAIN_PORT):3127" \
		-p "$(LOCAL_TLS_PORT):3128" \
		-p "$(LOCAL_MTLS_PORT):3129" \
		-p "$(LOCAL_BASIC_PORT):3130" \
		-p "$(LOCAL_BEARER_PORT):3131" \
		-p "$(LOCAL_DIGEST_PORT):3132" \
		-e TZ="UTC" \
		-e HFP_PROXIES=plain,tls,mtls,basic,digest,bearer \
		-e HFP_DEBUG_CONF="true" \
		-e HFP_plain_PORT=3127 \
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
		fme-proxy:$(OS)-$(VERSION)

## Starts a shell in a local container (accepts OS=xxx)
shell:
	$(DOCKER) exec -it fme-proxy-$(OS)-$(VERSION) bash

## Make a proxied request using a TLS endpoint with no auth (accepts TARGET=xxx)
req_noauth_tls:
	$(CURL) \
		-v \
		--proxy https://harness-fproxy:$(LOCAL_TLS_PORT) \
		--proxy-cacert certs/client/ca.crt \
		-XGET $(TARGET)

## Make a proxied request using an mTLS endpoint with no auth (accepts TARGET=xxx)
req_noauth_mtls:
	$(CURL) \
		-v \
		--proxy https://harness-fproxy:$(LOCAL_MTLS_PORT) \
		--proxy-cacert certs/client/ca.crt \
		--proxy-cert certs/client/client.crt \
		--proxy-key certs/client/client.key \
		-XGET $(TARGET)

## Make a proxied request using a TLS endpoint with basic auth (accepts TARGET=xxx)
req_basic_tls:
	$(CURL) \
		-v \
		--proxy https://harness-fproxy:$(LOCAL_BASIC_PORT) \
		--proxy-basic \
		--proxy-user "doc:lleguevolando" \
		--proxy-cacert certs/client/ca.crt \
		-XGET $(TARGET)

## Make a proxied request using a TLS endpoint with bearer auth (accepts TARGET=xxx)
req_bearer_tls:
	$(CURL) \
		-v \
		--proxy https://harness-fproxy:$(LOCAL_BEARER_PORT) \
		--proxy-cacert certs/client/ca.crt \
		--proxy-header 'Proxy-Authorization: Bearer $(TOKEN)' \
		-XGET $(TARGET)

## Make a proxied request using a plain/text endpoint with digest auth (accepts TARGET=xxx)
req_digest_plain:
	$(CURL) \
		-v \
		--proxy http://harness-fproxy:$(LOCAL_DIGEST_PORT) \
		--proxy-digest \
		--proxy-user "doc:lleguevolando" \
		-XFGET $(TARGET)

## Build multi-platform images for release and push them to dockerhub
images_release:
	@docker buildx version &> /dev/null|| (echo "docker buildx plugin is required to build multi-platform images" && exit 1)
	@docker buildx ls | awk 'BEGIN { RET=1 } /^xbuilder/  { RET = !($$2 == "docker-container")} END { exit RET }' || \
		(echo "to build cross platforms a builder instance of type 'docker-container' named 'xbuilder' is required" && exit 1)
	$(DOCKER) buildx build  \
		--builder xbuilder \
		--platform $(PLATFORM) \
		-t splitsoftware/fme-proxy:latest \
		-t splitsoftware/fme-proxy:ubuntu-latest \
		-t splitsoftware/fme-proxy:$(VERSION) \
		-t splitsoftware/fme-proxy:ubuntu-$(VERSION) \
		--push \
		-f ubuntu/Dockerfile .
	$(DOCKER) buildx build  \
		--builder xbuilder \
		--platform $(PLATFORM) \
		-t splitsoftware/fme-proxy:redhat-latest \
		-t splitsoftware/fme-proxy:redhat-$(VERSION) \
		--push \
		-f redhat/Dockerfile .
	@echo "Images created. Make sure everything works ok, and then run the following commands to push them."
	@echo "$(DOCKER) push splitsoftware/fme-proxy:latest"
	@echo "$(DOCKER) push splitsoftware/fme-proxy:$(VERSION)"
	@echo "$(DOCKER) push splitsoftware/fme-proxy:ubuntu-$(VERSION)"
	@echo "$(DOCKER) push splitsoftware/fme-proxy:ubuntu-latest"
	@echo "$(DOCKER) push splitsoftware/fme-proxy:redhat-$(VERSION)"
	@echo "$(DOCKER) push splitsoftware/fme-proxy:redhat-latest"

# -----------------

# internal use macros
platform_str		= $(if $(PLATFORM),--platform $(PLATFORM),)

# Help target borrowed from: https://docs.cloudposse.com/reference/best-practices/make-best-practices/
## This help screen
help:
	@printf "Available targets:\n\n"
	@awk '/^[a-zA-Z\-\_0-9%:\\]+/ { \
	    helpMessage = match(lastLine, /^## (.*)/); \
		if (helpMessage) { \
		    helpCommand = $$1; \
		    helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
		    gsub("\\\\", "", helpCommand); \
		    gsub(":+$$", "", helpCommand); \
		    printf "  \x1b[32;01m%-35s\x1b[0m %s\n", helpCommand, helpMessage; \
		} \
	    } \
	    { lastLine = $$0 }' $(MAKEFILE_LIST) | sort -u
	@printf "\n"
