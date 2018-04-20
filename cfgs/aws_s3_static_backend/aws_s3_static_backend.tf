# vim: et sr sw=2 ts=2 smartindent:
#
# FROM https://github.com/opsgang/fastly/ - cfgs/aws_s3_static_backend
#
# set $FASTLY_API_KEY in env instead of an explicit
# provider block for fastly.
#
# Also, you'll need a main.tf with a terraform block in which
# you can define min. terraform version, and backend settings.
#

variable "audit_comment" {
  description = "used this to put governance info in your vcl and fastly service e.g. git info"
  default     = "... should put in git_info or something useful for governance here."
}

variable "default_max_age" {
  default     = "1728000"
  description = "used in aws_s3_static_backend.vcl.tpl for Access-Control-Max-Age header"
}

variable "default_ttl" {
  default     = "3600s"
  description = "used in resource and aws_s3_static_backend.vcl.tpl for default ttl value"
}

variable "fastly_dns_name" {
  default     = "packages-static.eurostar.com"
  description = "dns name used by end-users to access site via fastly"
}

variable "static_s3_fqdn" {
  default     = "eil-packages-static-assets.s3-website-eu-west-1.amazonaws.com"
  description = "dns name to s3 bucket"
}

variable "service_name" {
  default     = "packages-static.eurostar.com"
  description = "name of service in fastly" 
}

variable "between_bytes_timeout" {
  default     = 10000
  description = "backend setting"
}

variable "connect_timeout" {
  default     = 2000
  description = "backend setting"
}

variable "first_byte_timeout" {
  default     = 10000
  description = "backend setting"
}

variable "max_conn" {
  default     = 400
  description = "backend setting"
}

provider "fastly" {
  version = "~> 0.1.4"
}

provider "template" {
  version = "~> 1.0.0"
}

resource "fastly_service_v1" "a" {
  name   = "${var.service_name}"

  domain {
    name    = "${var.fastly_dns_name}"
    comment = "${var.audit_comment}"
  }

  backend {
    name                  = "${var.static_s3_fqdn}"
    address               = "${var.static_s3_fqdn}"

    auto_loadbalance      = true
    between_bytes_timeout = "${var.between_bytes_timeout}"
    connect_timeout       = "${var.connect_timeout}"
    first_byte_timeout    = "${var.first_byte_timeout}"
    max_conn              = "${var.max_conn}"
    port                  = 80
    ssl_check_cert        = false
  }

  request_setting {
    name          = "${var.service_name}"
    default_host  = "${var.static_s3_fqdn}"
    force_ssl     = true
  }

  default_ttl = "${var.default_ttl}"

  gzip {
    name          = "gzip"
    extensions    = [
      "apng",
      "css",
      "eot",
      "html",
      "jpeg",
      "jpg",
      "js",
      "json",
      "ico",
      "otf",
      "png",
      "svg",
      "ttf"
    ]

    content_types = [
      "text/html",
      "application/x-javascript",
      "text/css",
      "application/javascript",
      "text/javascript",
      "application/json",
      "application/vnd.ms-fontobject",
      "application/x-font-opentype",
      "application/x-font-truetype",
      "application/x-font-ttf",
      "application/xml",
      "font/eot",
      "font/opentype",
      "font/otf",
      "image/apng",
      "image/gif",
      "image/jpg",
      "image/jpeg",
      "image/png",
      "image/svg+xml",
      "image/webp",
      "image/vnd.microsoft.icon",
      "text/plain",
      "text/xml"
    ]
  }

  healthcheck {
    name              = "health_check"
    host              = "${var.static_s3_fqdn}"
    path              = "/index.html"
    check_interval    = 20000
    expected_response = 200
    initial           = 2
    method            = "HEAD"
    threshold         = 2
    timeout           = 12000
    window            = 3
  }

  vcl {
    name    = "aws_s3_static_backend"
    content = "${data.template_file.aws_s3_static_backend.rendered}"
    main    = true
  }

  # if using opsgang/http_security_headers, uncomment the vcl{} block below
  #
  #vcl {
  #  name    = "aws_s3_static_backend"
  #  content = "${data.template_file.http_security_headers.rendered}"
  #  main    = false
  #}
}

data "template_file" "aws_s3_static_backend" {

  template = "${file("aws_s3_static_backend.vcl.tpl")}" # ... CHANGE PATH IF YOU'RE USING A SUBDIR

  vars {
    audit_comment     = "${var.audit_comment}"
    default_max_age   = "${var.default_max_age}"
    default_ttl       = "${var.default_ttl}"
  }
}

