-- Digest module will set 401, but we need 407 for proxy auth
-- Clients rely on Proxy-Authorization, but digest auth module will use WWW-Authenticate,
-- header rewriting is done here as well
-- TODO(mredolatti): we should also check that the request method/verb is CONNECT
if ngx.status == 401 then
    ngx.status = 407
    ngx.header["Proxy-Authenticate"] = ngx.header["WWW-Authenticate"]
    ngx.header["WWW-Authenticate"] = nil
end
