# vim: et sr sw=2 ts=2 smartindent syntax=vcl:
#
# FROM https://github.com/opsgang/fastly/ - cfgs/aws_s3_static_backend
#
# VCL that expects to cache all requests by default from an S3 backend
# * removes amazon specific headers in vcl_deliver.
#
# * adds robots.txt that stops indexing and caching but allows crawling
#   of common static asset types to enhance SEO.
#
sub vcl_recv {
#FASTLY recv

  # ... s3 isn't going to do much with a Cookie, and Fastly vcl_fetch() won't cache
  # if one is set.
  unset req.http.Cookie;

  if( req.url.path ~ "^/robots.txt" ) {
    error 900 "synthetic";
  }

  if (req.request != "HEAD" && req.request != "GET" && req.request != "FASTLYPURGE") {
    return(pass);
  }

  return(lookup);

}

sub vcl_fetch {

  if (req.restarts > 0) { set beresp.http.Fastly-Restarts = req.restarts; }

  # ... dont allow static files to set cookies.
  unset beresp.http.set-cookie;

  # ... remove AWS s3-specific headers
  unset beresp.http.server;
  unset beresp.http.x-amz-id-2;
  unset beresp.http.x-amz-request-id;
  unset beresp.http.x-amz-version-id;
  unset beresp.http.x-amz-meta-s3cmd-attrs;

#FASTLY fetch

  if (
    req.restarts < 1 &&
    (beresp.status >= 500 || beresp.status <= 600) &&
    (req.request == "GET" || req.request == "HEAD")
  ) {
    restart;
  }

  if (beresp.http.Cache-Control ~ "private") {
    set req.http.Fastly-Cachetype = "PRIVATE";
    return(pass);
  }

  if (beresp.status == 500 || beresp.status == 503) {
    set req.http.Fastly-Cachetype = "ERROR";
    set beresp.ttl = 1s;
    set beresp.grace = 5s;
    return(deliver);
  }

  if (
    beresp.http.Expires ||
    beresp.http.Surrogate-Control ~ "max-age" ||
    beresp.http.Cache-Control ~ "(s-maxage|max-age)"
  ) {
    # ... keep existing ttl
  } else {
    set beresp.ttl = ${default_ttl};
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

  # ... default cache-control
  if (! resp.http.Cache-Control) {
    set resp.http.Cache-Control = "public, max-age=3600";
  }

  # ... though we allow crawling of images (see robots.txt), we also 
  # ask that they not be included in search results here.
  set resp.http.X-Robots-Tag = "noindex, nofollow";

  # Access Control: allow headers
  declare local var.ah STRING;
  set var.ah = "Content-Type,Accept,Origin,User-Agent,Cache-Control,Keep-Alive";

  set resp.http.Access-Control-Allow-Origin = "*";
  if ( req.request == "OPTIONS" ) {
    set resp.http.Access-Control-Max-Age = "${default_max_age}";
    set resp.http.Access-Control-Allow-Methods = "GET, OPTIONS";
    set resp.http.Access-Control-Allow-Headers = var.ah;
    set resp.http.Content-Type = "text/plain; charset=UTF-8";
    set resp.status = 204;
  }

#FASTLY deliver

  # if you are using opsgang/http_security_headers uncomment the line below
  #
  #include "http_security_headers";

  return(deliver);

}

sub vcl_error {

  if (obj.status == 900 ) {
    unset obj.http.Expires;
    unset obj.http.Cache-Control;
    set obj.http.Content-Type = "text/plain; charset=utf-8";
    set obj.status = 200;
    set obj.response = "OK";

    # ... better for SEO to allow crawling of images.
    synthetic {"#
# robots.txt
User-agent: *
Disallow: /
Allow: *.gif
Allow: *.jpg
Allow: *.jpeg
Allow: *.JPG
Allow: *.JPEG
Allow: *.jpeg
Allow: *.apng
Allow: *.png
Allow: *.PNG
Allow: *.svg
"};
    return(deliver);
  }

#FASTLY error

  return(deliver);
}

sub vcl_pass {
#FASTLY pass
}

sub vcl_log {
#FASTLY log
}
