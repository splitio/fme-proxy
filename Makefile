DOCKER ?= docker
DOCKER_COMPOSE ?= docker-compose
CURL ?= curl

shell:
	$(DOCKER) exec -it obproxynginx-proxy-1 bash

dcu:
	$(DOCKER_COMPOSE) up

dcb:
	$(DOCKER_COMPOSE) build --no-cache --progress=plain

dcd:
	$(DOCKER_COMPOSE) down

req_noauth:
	https_proxy=localhost:3128 $(CURL) \
				-v \
				-XGET https://www.stallman.org 

req_bearer:
	https_proxy=localhost:3128 $(CURL) \
				-v \
				-XGET https://www.stallman.org \
				--proxy-header 'Proxy-Authorization: Bearer $(TOKEN)'

req_bearer_mtls:
	curl \
		-v \
		--proxy https://harness-fproxy:3128 \
		--proxy-cacert certs/client/ca.crt \
		--proxy-cert certs/client/client.crt \
		--proxy-key certs/client/client.key \
		--proxy-header 'Proxy-Authorization: Bearer $(TOKEN)' \
		-XGET https://www.stallman.org
