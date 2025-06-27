ROOT_DIR := build/root
PROXY_DIR := build/proxy
CLIENT_DIR := build/client

SHARED_PROXY := proxy
SHARED_CLIENT := client

ROOT_CERTS := $(ROOT_DIR)/ca.key $(ROOT_DIR)/ca.crt $(ROOT_DIR)/ca.der
PROXY_CERTS := $(PROXY_DIR)/proxy.key $(PROXY_DIR)/proxy.crt
CLIENT_CERTS := $(CLIENT_DIR)/client.key $(CLIENT_DIR)/client.crt $(CLIENT_DIR)/client.p12


.PHONY: all clean build bundle

default: all
all: clean build bundle
bundle: $(PROXY_CERTS) $(CLIENT_CERTS)
	mkdir -p {$(SHARED_PROXY),$(SHARED_CLIENT)}
	cp $(ROOT_DIR)/ca.crt $(SHARED_PROXY)
	cp $(PROXY_DIR)/proxy.crt $(SHARED_PROXY)
	cp $(PROXY_DIR)/proxy.key $(SHARED_PROXY)
	cp $(ROOT_DIR)/ca.crt $(SHARED_CLIENT)
	cp $(CLIENT_DIR)/client.crt $(SHARED_CLIENT)
	cp $(CLIENT_DIR)/client.key $(SHARED_CLIENT)
	cp $(CLIENT_DIR)/client.p12 $(SHARED_CLIENT)

build: dirs $(ROOT_CERTS) $(PROXY_CERTS) $(CLIENT_CERTS)
dirs:
	mkdir -p $(ROOT_DIR) $(PROXY_DIR) $(CLIENT_DIR)


clean:
	rm -Rf *.crt *.pem *.csr *.key *.old *.attr *.index *.serial proxy/* client/* build/root/* build/proxy/* build/client/*

$(ROOT_DIR)/ca.db.index: 
	touch $@

# ROOT CA
$(ROOT_CERTS): $(ROOT_DIR)/ca.db.index
	openssl rand -hex 16 > ca.serial
	openssl genrsa \
		-aes256 \
		-passout pass:some_passphrase \
		-out $(ROOT_DIR)/ca.key 4096
	openssl req -config openssl.conf \
		-key $(ROOT_DIR)/ca.key \
		-new \
		-x509 \
		-days 5000 \
		-sha256 \
		-extensions v3_ca \
		-passin pass:some_passphrase \
		-subj '/C=AR/ST=Buenos Aires/L=Tandil/O=Split/OU=IT/CN=RootCA/emailAddress=martin.redolatti@harness.io' \
		-out $(ROOT_DIR)/ca.crt
	openssl x509 -outform der -in $(ROOT_DIR)/ca.crt -out $(ROOT_DIR)/ca.der

# PROXY
$(PROXY_DIR)/proxy.key $(PROXY_DIR)/proxy.crt:
	openssl genrsa \
		-out $(PROXY_DIR)/proxy.key 2048
	openssl req -config openssl.conf \
		-key $(PROXY_DIR)/proxy.key \
		-new \
		-sha256 \
		-addext 'subjectAltName = DNS:harness-fproxy,email:admin@harness.io' \
		-subj '/C=AR/ST=Buenos Aires/L=Tandil/O=Harness/OU=IT/CN=harness-fproxy/emailAddress=martin.redolatti@harness.io' \
		-out $(PROXY_DIR)/proxy.csr
	openssl ca -config openssl.conf \
		-batch \
		-extensions server_cert \
		-days 365 \
		-notext \
		-passin pass:some_passphrase \
		-in $(PROXY_DIR)/proxy.csr \
		-out $(PROXY_DIR)/proxy.crt

# Client
$(CLIENT_DIR)/client.key $(CLIENT_DIR)/client.crt:
	openssl genrsa \
		-out $(CLIENT_DIR)/client.key 2048
	openssl req \
		-key $(CLIENT_DIR)/client.key \
		-new \
		-sha256 \
		-addext 'subjectAltName=DNS:some-user,email:some-user@harness.io' \
		-subj '/C=AR/ST=Buenos Aires/L=Tandil/O=Harness/OU=IT/CN=some-user/emailAddress=some-user@harness.io' \
		-out $(CLIENT_DIR)/client.csr
	openssl ca -config openssl.conf \
		-batch \
		-days 365 \
		-notext \
		-passin pass:some_passphrase \
		-in $(CLIENT_DIR)/client.csr \
		-out $(CLIENT_DIR)/client.crt


# build p12 for hava crap
$(CLIENT_DIR)/client.p12:
	openssl pkcs12 \
		-export \
		-password pass:123456 \
		-in $(CLIENT_DIR)/client.crt \
		-inkey $(CLIENT_DIR)/client.key \
		-out $(CLIENT_DIR)/client.p12 \
		-name pindonga \
		-CAfile $(ROOT_DIR)/ca.crt \
		-caname root


