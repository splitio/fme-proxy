local M = {}

function M.fail_if_host_not_allowed(whitelist)
    local target = ngx.req.get_headers()["Host"]
    if string.find(target, ':') == nil then
        local raw_headers = ngx.req.raw_header()
        local request_line = string.sub(raw_headers, 0, string.find(raw_headers, "\\\\r\\\\n"))
        target = string.match(request_line, "CONNECT (.*:%d+) .*")
    end

    for _, v in ipairs(whitelist) do
        if target == v then
            return
        end
    end

    ngx.exit(ngx.HTTP_FORBIDDEN)
end

return M
