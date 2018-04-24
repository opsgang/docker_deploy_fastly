# infrastructure/fastly/herokuapp\_backend

> Provides full vcl and main terraform to stick
> a Fastly service in front of a heroku app.

See .tf file for variables to set.

## VCL

* includes http\_security\_headers

* honours any cache headers set by app (_Expires_, _Surrogate-Control_, _Cache-Control_)

* 3 caching categories to assign if app does not send any cache headers - _short_, _long_, _other_
    - define different ttl and cache control for each.

* caches 404s and 3xx redirects to protect the origin from exploratory crawlers.

* Pass request header _X-custom-debug_, and receive any custom debug msgs as response
    header _X-custom-debug_ - see examples already in place in `vcl_fetch`.

> See the inline comments in the vcl for more information.

