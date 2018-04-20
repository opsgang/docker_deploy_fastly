# docker_deploy_fastly
... provides generic fastly vcl, terraform, and dockerised deployment

```
.
└── cfgs    # ... common terraform and vcl examples
    │
    ├── aws_s3_static_backend # serve static assets from s3, does not create s3 bucket.
    │
    ├── heroku_backend        # serve from heroku using heroku dns name for origin
    │
    └── http_security_headers # csp, x-frame-options etc

```

## CFGS

Each sub dir contains vcl and / or terraform examples or snippets
that you can use to configure Fastly.

>
> These are directly useful if your Fastly account
> has been permitted to upload **custom VCL**.
>

If not you can generally configure the same using the Fastly API by augmenting the terraform.

In this case, use the VCL and terraform as reference for the behaviours you should set.
