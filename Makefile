DOCKER ?= docker
DOCKER_COMPOSE ?= docker-compose
CURL ?= curl

rhshell:
	$(DOCKER) exec -it obproxynginx-redhat-proxy-1 bash

ushell:
	$(DOCKER) exec -it obproxynginx-ubuntu-proxy-1 bash

dcu:
	$(DOCKER_COMPOSE) up

dcb:
	$(DOCKER_COMPOSE) build --no-cache --progress=plain

dcd:
	$(DOCKER_COMPOSE) down

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
