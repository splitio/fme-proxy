1. generaete a JWKS here `https://jwkset.com/generate` and place it's contents in `./keys/keys.jwks`
2. start the proxy with `make dcd dcb dcu`

-- in another tab:

1. try a non-authorized request: `make req_noauth` (should return 407 status code)
2. create a JWT using the previously generated JWK for singing here: `https://www.scottbrady.io/tools/jwt` 
    - kid inside the header should match
    - exp must be a time in the future
3. make the token available in the environment `export PROXY_TOKEN=<raw_token>`
4. try a valid request `make req_bearer TOKEN="${PROXY_TOKEN}"`
