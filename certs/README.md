# Example PKI generation scripts.

In order to run the demo server in the root `Makefile` certain files are expected. These can be created with the PKI generation scripts in this folder.

## Generated files

### To be used by the proxy
These files are needed by the proxy itself to enable HTTPS on incoming CONNECT requests & if mTLS is enabled, validate client certificates:
- proxy/proxy.crt
- proxy/proxy.key
- proxy/ca.crt

### To be used by the client when connecting to the proxy
These files are needed by the client when connecting to a proxy with TLS enabled. A client certificate is also present for mTLS testing purposes:
- client/client.crt
- client/client.key
- client/ca.crt

### Running the scripts

In order to generate the aforementioned files, you need to have GNU Makefile & Openssl properly installed on the system and run the  following command:

- `make all bundle`
