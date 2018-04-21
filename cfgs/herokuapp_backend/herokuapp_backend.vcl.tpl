# vim: et sr sw=2 ts=2 smartindent syntax=vcl:
#
# ${audit_comment}
#
# FROM https://github.com/opsgang/fastly/ - cfgs/herokuapp_backend
#
# VCL to front a heroku app.
#
# * honours any Cache-Control and Surrogate-Control response headers from origin.
#
# In the absence of these, default Cache-Control and Surrogate-Control headers 
# are added in vcl_fetch based on which of 3 caching categories the request
# falls in to:
#   1. "short" used for .js and .css files
#   2. "long"  used for static assets such as images, fonts, and pdfs.
#   3. other   used for any other response for a cookieless GET or HEAD request
#
# * caches 404s and redirects for user-configurable period.
#
sub vcl_recv {

  # ... force the expected DNS name that points to fastly so that requests
  # to http://my.fastly.service will be automatically redirected to
  # https://my.fastly.service during the code provided in the expanded FASTLY recv macro.
  set req.http.Host = "${dns_to_fastly}";

#FASTLY recv

  # ... now we need to set the host header to what the origin will expect.
  # (Unless you use a custom domain name in Heroku, it uses the host header
  # to determine which of the hundreds of apps it hosts should take this request.
  set req.http.Host = "${dns_to_origin}"; # probably ends in herokuapp.com

  if (req.request != "HEAD" && req.request != "GET" && req.request != "FASTLYPURGE") {
    return(pass);
  }

  # ... we probably want to cache static assets, so unset any cookie.
  # However we allow that we might cache js and css for shorter periods
  # than images and fonts to account for apps with a fast release cycle.
  if (
    req.url.ext == "apng" ||
    req.url.ext == "css"  ||
    req.url.ext == "gif"  ||
    req.url.ext == "ico"  ||
    req.url.ext == "jpg"  ||
    req.url.ext == "jpeg" ||
    req.url.ext == "js"   ||
    req.url.ext == "pdf"  ||
    req.url.ext == "png"  ||
    req.url.ext == "svg"  ||
    req.url.ext == "ttf"  ||
    req.url.ext == "woff" ||
    req.url.ext == "woff2"
  ) {
    unset req.http.Cookie;
    if (req.url.ext == "js" || req.url.ext == "css") {
      set req.http.X-force-cache = "short";
    }
    else {
      set req.http.X-force-cache = "long";
    }
  }

  return(lookup);

}

sub vcl_fetch {
  if (req.restarts > 0) { set beresp.http.Fastly-Restarts = req.restarts; }

#FASTLY fetch

  if (
    req.restarts < 3 &&
    (beresp.status >= 500 && beresp.status <= 600) &&
    (req.request == "GET" || req.request == "HEAD")
  ) {
    restart;
  }

  if (beresp.status == 500 || beresp.status == 503) {
    set req.http.Fastly-Cachetype = "ERROR";
    set beresp.ttl = 1s;
    set beresp.grace = 5s;
    return(deliver);
  }

  # ... cache 404 / 301
  if (
    beresp.status == 404 ||
    beresp.status == 301 ||
    beresp.status == 302 ||
    beresp.status == 307
  ) {
    set beresp.ttl = ${ttl_404_and_3xx};
  }

  if (
    beresp.http.Expires ||
    beresp.http.Surrogate-Control ~ "max-age" ||
    beresp.http.Cache-Control ~ "(s-maxage|max-age)"
  ) { # ... keep the ttl here
  }
  elsif (req.http.X-force-cache && req.http.X-force-cache != "") {
    declare local var.secs_str STRING; 
    declare local var.secs_t RTIME; 
    if (req.http.X-force-cache == "short") {
      set var.secs_str = "${short_ttl_secs}";
      set var.secs_t = ${short_ttl_secs}s;
    }
    elsif (req.http.X-force-cache == "long") {
      set var.secs_str = "${long_ttl_secs}";
      set var.secs_t = ${long_ttl_secs}s;
    }
    else {
      set var.secs_str = "${default_ttl_secs}";
      set var.secs_t = ${default_ttl_secs}s;
    }

    set beresp.http.Surrogate-Control = "public, max-age=" + var.secs_str;
    set beresp.http.Cache-Control = "public, max-age=" + var.secs_str;
    set beresp.ttl = var.secs_t;
    set beresp.grace = var.secs_t;
    if (req.http.X-custom-debug) {
      set req.http.X-custom-debug = " forced-cache:"+ var.secs_str;
    }
  }
  else {
    # apply the default ttl
    set beresp.ttl = ${default_ttl_secs}s;
  }

  # ... for non-static assets, pass-thru
  if (beresp.http.Set-Cookie) {
    set req.http.Fastly-Cachetype = "SETCOOKIE";
    return (pass);
  }

  if (beresp.http.Cache-Control ~ "private") {
    set req.http.Fastly-Cachetype = "PRIVATE";
    return(pass);
  }

  return(deliver);

}

sub vcl_hit {

#FASTLY hit

    if (!obj.cacheable) {
        return(pass);
    }
    return(deliver);

}

sub vcl_miss {
#FASTLY miss
  return(fetch);
}

sub vcl_deliver {

#FASTLY deliver

  # if you are using opsgang/http_security_headers uncomment the line below
  #
  #include "http_security_headers";

  return(deliver);

}

sub vcl_error {

#FASTLY error

  return(deliver);
}

sub vcl_pass {
#FASTLY pass
}
