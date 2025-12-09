# FME Proxy

This tool is meant to be used by customers who want a single connection point from their SDKs to harness FME services.
It consists of a custom-built open-resty (augmented NGINX core) with a set of custom configs and LUA scripts in order to support HTTP & HTTPS proxy tunnels.
When deployed as a forward proxy, SDKs configured to use it will establish opaque tunnels to harness FME servers, on which the SDKs will execute their requests as usual.
The tool also allows several ways of authenticating clients to accept/deny creating such tunnels, hence rejecting connections to harness servers.

## Servers
The proxy can be configured with multiple servers on different points, each with different authentication & encryption requirements.

## TLS & mTLS
The proxy can be configured with an x509 certificate and its private key to allow for secure connections to be used when establishing the tunnel (this is useful for some authentication mechanisms which transfer credentials over the network). It also supports requesting & verifying client certificates, rejecting connections if not provided by the client or its validation is unsuccessful.

## Authorization
The proxy supports 3 different authorization algorithms. Only one of them can be enabled on each server, but multiple servers with otherwise identical configuration can be leveraged on different ports.

### Basic Auth
Credentials are sent in plain text on the `CONNECT` request in the `Proxy-Authorization` header. TLS is a must if using this scheme.

### Digest Auth
A short handshake is done between the client & the proxy when doing the `CONNECT` request. The credentials are hashed together with a set of parameters returned by the proxy during an initial connection attempt. This method is a viable alternative in environments where setting up a PKI / TLS environment is not trivial. Keep in mind that the connection to harness itself WILL ALWAYS BE PRIVATE, since the tunneled connection is always established via a secure channel over HTTPS.

### Bearer Auth
Allows the user to sign tokens with it's own private key, that the proxy can then parse and check with a JWKS provided by the user. Though being more secure than Basic Auth given it's expiration time, TLS is recommended for this scheme as well.

## Running the image using docker

### Quickstart

1. Get the image `docker pull splitsoftware/fme-proxy`
2. Run the image with the desired configuration (more on config later on): `docker run --rm --name some-fme-proxy -e HP_PROXIES=main -e HP_main_PORT=3128 -p 3128:3128 splitsoftware/fme-proxy:ubuntu`.
3. Test with curl: `curl -v --proxy http://127.0.0.1:3128 -XGET https://sdk.split.io/api/version`.
 
### In-depth configuration
As mentioned above, the applications supports listening on multiple ports, each with different SSL & authentication requirements. These instances are called `server`s and are listed in the `HP_PROXIES` variable in a comma-separated list (no spaces, just comma). All server-specific configurations follow the format `HP_&lt;server_name&gt;_<config_option>`

#### HP_PROXIES
- Context: global
- Comma separated list of identifiers denoting server instances.
- Example: `server_mtls,server_basic_auth`
- Default: none / required
#### HP_WORKER_PROCESSES
- Context: global
- Number of nginx worker processes. Ideally it should be set to the number of CPU threads/vthreads.
- Default: `4`
#### HP_WORKER_CONNECTIONS
- Context: global
- How many connections to handle per worker
- Default: `1024`
#### HP_LOG_LEVEL
- Context: global
- Maximum level of unfiltered logs
- Default: `info`
#### HP_&lt;server_name&gt;_TYPE
- Context: server-specific
- Whether the proxy is of type FORWARD (default) or REVERSE
#### HP_&lt;server_name&gt;_PORT (FORWARD & REVERSE)
- Context: server-specific
- Port on which this server will listen on
- Default: none / required
#### HP_&lt;server_name&gt;_SSL (FORWARD & REVERSE)
- Context: server-specific
- Whether to enable traffic encryption on this server
- Default: `false`
#### HP_&lt;server_name&gt;_SSL_CERTIFICATE (FORWARD & REVERSE)
- Context: server-specific
- Server certificate to use for traffic encryption
- Default: none / required if `HP_<server_name>_SSL` is enabled
- Example: `/my_volume/pki/server.crt`
#### HP_&lt;server_name&gt;_SSL_PRIVATE_KEY (FORWARD & REVERSE)
- Context: server-specific
- Private key from which the certificate's pubkey is derived.
- Default: none / required if `HP_<server_name>_SSL` is enabled
- Example: `/my_volume/pki/server.key`
#### HP_&lt;server_name&gt;_SSL_CLIENT_CERTIFICATE (FORWARD & REVERSE)
- Context: server-specific
- CA certificate used to verify certificates presented by clients (mTLS is enabled when this variable is not empty)
- Default: none
- Example: `/my_volume/pki/client_ca.crt`
#### HP_&lt;server_name&gt;_AUTH (FORWARD only)
- Context: server-specific
- Whether to enable authentication on this server, and what scheme to use
- Default: none
- Options: [`basic`|`digest`|`bearer`]
#### HP_&lt;server_name&gt;_AUTH_BASIC_PASSWD (FORWARD only)
- Context: server-specific
- Passwd file with user/hashes used for basic authentication
- Default: none / required if `HP_<server_name>_AUTH` is set to basic
- Example: `/my_volume/passwd/basic.passwd`
#### HP_&lt;server_name&gt;_AUTH_DIGEST_PASSWD (FORWARD only)
- Context: server-specific
- Passwd file with user/hashes used for digest authentication
- Default: none / required if `HP_<server_name>_AUTH` is set to digest
- Example: `/my_volume/passwd/digest.passwd`
#### HP_&lt;server_name&gt;_AUTH_BEARER_JWKS (FORWARD only)
- Context: server-specific
- JWKS store with public keys that can be used to parse a token inside a bearer auth CONNECT request
- Default: none / required if `HP_<server_name>_AUTH` is set to bearer
- Example: `/my_volume/keys/keys.jwks`
#### HP_&lt;server_name&gt;_PROXY_THRU
- Context: server-specific
- Upstream proxy to which this proxy must connect and forward requests (format: &lt;host&gt;:&lt;port&gt;)
- Default: none
- Example: `my-upstream-proxy:3128`
#### HP_&lt;server_name&gt;_PROXY_THRU_SSL (FORWARD & REVERSE)
- Context: server-specific
- Setup a TLS connection between this proxy and the upstream, prior to issuing the CONNECT request on the latter
- Default: disabled
- Example: `true`
#### HP_&lt;server_name&gt;_PROXY_THRU_CA_CERT (FORWARD & REVERSE)
- Context: server-specific
- CA certificate to use to verify upstream proxy's cert.
- Default: none / required if `HP_<server_name>_PROXY_CHAIN_SSL` is enabled.
- Example: `/my_volume/pki/ca.crt`
#### HP_&lt;server_name&gt;_RESOLVER (FORWARD & REVERSE)
- Context: server-specific
- Name server to use when resolving upstream. Useful if an internal DNS is required to reach hosts inside a VPC or kubernetes cluster.
- Default: 8.8.8.8
- Example: `127.0.0.53`
#### HP_&lt;server_name&gt;_ALLOWED_TARGETS (FORWARD only)
- Context: server-specific
- Comma separated list of host:port pairs to which tunnels can be established. Non matching hosts will get a 403 when attempting CONNECT request.
- Default: `sdk.split.io:443,auth.split.io:443,streaming.split.io:443,events.split.io:443,telemetry.split.io:443`
#### HP_&lt;server_name&gt;_ALLOWED_TARGET_PORTS (FORWARD only)
- Context: server-specific
- Comma separated list of ports to which tunnels can be established. It must include all ports specified in `HP_<server_name>_ALLOWED_TARGETS` if != "*"
- Default: `443`
#### HP_&lt;server_name&gt;_LOCATIONS (REVERSE only)
- Context: server-specific
- Comma-separated list of locations definitions for a reverse proxy. See section below for more detailed information on how to specify locations
- Default: <empty>
#### HP_&lt;server_name&gt;_LOCATIONS_SSL_VERIFICATION_CERT (REVERSE only)
- Context: server-specific
- CA certificate chain to validate SSL connection to target hosts (optional - tls won't ve verified if no cert is provided)
- Default: `443`

### Reverse proxy location definition
When using a reverse-proxy server, you can specify pre-defined locations supported by harness via presets or create custom ones and make them available via an external mount volume and reference them from the config generation scripts.

#### Presets
Preset location files reference URLs for services provided by Harness modules

##### FME
FME preset can be referenced by including `PRESET:fme` in the HP_&lt;server_name&gt;_LOCATIONS variable, and includes the following paths, which should be specified in the URL overrides of the FME SDK:
- "https://sdk.split.io"
- "https://events.split.io"
- "https://auth.split.io"
- "https://streaming.split.io"
- "https://telemetry.split.io"

#### Custom
If you need to provide custom locations for an external service, you should do so by creating a [JSONL file](https://jsonlines.org/examples/) consisting of one location definition per line. Each location should be an object containing at least `path` & `target` properties. Below is a list of all supported properties

##### Config options
###### path
- Description: local mount path (URL used by the clients to reference the proxied host)
- Default: <empty> (mandatory)
###### target
- Description: URL of the host where requests will be proxied to
- Default: <empty> (mandatory)
###### buffer
- Description: Whether responses sent to client should be buffered or not
- Default: true
###### read_timeout
- Description: Socket read timeout in seconds (useful for streaming endpoints which might keep connection alive for a while without sending data)
- Default: 30 seconds

##### Example config for FME
```
{ "path": "/fme/sdk", "target": "https://sdk.split.io" }
{ "path": "/fme/events", "target": "https://events.split.io" }
{ "path": "/fme/auth", "target": "https://auth.split.io" }
{ "path": "/fme/streaming", "target": "https://streaming.split.io", "read_timeout": 120, "buffer": false  }
{ "path": "/fme/telemetry", "target": "https://telemetry.split.io" }
```
