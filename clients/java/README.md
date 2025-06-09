To get this running in java we need:

1. a PKCS12 keystore file with the client certificate & the private key
this is automatically generated in the certs/Makefile's `$(CLIENT_DIR)/client.p12` target.

2. a Trust store (JKS was tried but PKCS12 sohuld work as well) with a self-signed root CA used to validate the proxy's server cert.
To get this to work, we need to use the JVM's current `cacerts` as a starting point (use `find "${JAVA_HOME}" -name "cacerts"` to get it's location).
The Makefile has targets to also export the root CA in `der` format which is required in order to import it in a JKS.
- `cp /path/to/cacerts path/to/app/src/main/resources`
- `keytool -import -alias root -keystore path/to/app/src/main/resources -file ../../certs/client/ca.der`

3. A dynamic JWT  generation mechanism. Currently the token is hard-coded in a credential provider that is called everyt time it's needed. This should be replaced by a placeholder for client's custom code to obtain, cache and return a valid JWT with a properly designed interface.
