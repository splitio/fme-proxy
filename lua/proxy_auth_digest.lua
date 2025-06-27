-- digest auth relies on a retry with proper credentials on a second request
-- over the same TCP connection.
-- Hence we cannot reject the first one for a lack of `proxy-authentication header`
-- Once we get that header we map it to `Authorization` so that the plugin can
-- properly handle it
if ngx.var.http_proxy_authorization then
    ngx.req.set_header("Authorization", ngx.var.http_proxy_authorization)
end
