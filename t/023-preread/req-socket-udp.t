use Test::Nginx::Socket::Lua::Stream;

repeat_each(2);

plan tests => repeat_each() * (blocks() * 3 - 2);

no_long_string();
#no_diff();
#log_level 'warn';

run_tests();

__DATA__

=== TEST 1: udp peek preserves datagram
--- stream_server_config
    set $peek "";
    preread_by_lua_block {
        local sock = assert(ngx.req.socket())
        local data = assert(sock:peek(8))
        ngx.var.peek = ngx.encode_base64(data)
        ngx.say(ngx.var.peek)
    }
    proxy_pass 127.0.0.1:$TEST_NGINX_RAND_PORT_1 udp;
--- stream_config
server {
    listen 127.0.0.1:$TEST_NGINX_RAND_PORT_1 udp;

    content_by_lua_block {
        local sock = assert(ngx.req.socket())
        local data = assert(sock:receive())
        ngx.log(ngx.DEBUG, "upstream received: ", data)
        ngx.say("done")
    }
}
--- stream_request chop
hello world
--- stream_response
aGVsbG8gd28=
done
--- error_log
upstream received: hello world
--- no_error_log
[error]

=== TEST 2: double peek
--- stream_server_config
    preread_by_lua_block {
        local sock = assert(ngx.req.socket())
        local data = assert(sock:peek(4))
        ngx.say(ngx.encode_base64(data))
        data = assert(sock:peek(4))
        ngx.say(ngx.encode_base64(data))
    }
    return done;
--- stream_request chop
hello world
--- stream_response
aGVsbA==
aGVsbA==
--- no_error_log
[error]

=== TEST 3: peek after receive
--- stream_server_config
    preread_by_lua_block {
        local sock = assert(ngx.req.socket())
        local data = assert(sock:receive())
        ngx.say("received: ", data)
        ngx.flush(true)
        sock:peek(1)
    }
    return done;
--- stream_request chop
hello world
--- stream_response
received: hello world
--- error_log
attempt to peek on a consumed socket
--- no_error_log
[warn]

=== TEST 4: peek timed out
--- stream_server_config
    preread_timeout 100ms;
    preread_by_lua_block {
        local sock = assert(ngx.req.socket())
        local data = assert(sock:peek(5))
        ngx.say("received: ", data)
        ngx.flush(true)
        sock:peek(12)
    }
    return done;
--- stream_request chop
hello world
--- stream_response
received: hello
--- error_log
finalize stream session: 200
--- no_error_log
[warn]

=== TEST 5: preread buffer full
--- stream_server_config
    preread_buffer_size 10;
    preread_by_lua_block {
        local sock = assert(ngx.req.socket())
        local data = assert(sock:peek(5))
        ngx.say("received: ", data)
        sock:peek(11)
    }
    return done;
--- stream_request chop
hello world
--- error_log
preread buffer full while prereading client data
finalize stream session: 400
--- no_error_log
[warn]
