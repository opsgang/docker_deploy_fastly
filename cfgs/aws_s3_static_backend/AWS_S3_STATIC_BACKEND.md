# aws\_s3\_static\_backend

Terraform and full vcl to front an S3 webserving bucket with a
Fastly service.

>
> Optionally uncomment the vcl block in the `fastly_service_v1` resource
> if you're also including opsgang/http\_security\_headers.
>

## USAGE

>
> Only relevant if your Fastly service is allowed to upload custom vcl.
>
> Speak to support@fastly.com if not.
>

This assumes you have created an s3 bucket configured as a webserver.

**It must contain an index.html file available to use as a health check.**

### 1. Grab files in this subdir

Drop them in your project dir.

That's the dir in which you will run terraform cmds, where main.tf would reside.

### 2. main.tf terraform {}

Create a .tf file (conventially, main.tf) if you don't have one already
with a terraform block in it.

e.g.

```hcl
# main.tf

# I store my tfstate in an s3 bucket ...
terraform {
  required_version = "~> 0.11.7"

  backend "s3" {
    bucket   = "example_bucket"
    # region set by $AWS_DEFAULT_REGION at run-time
    # key set via terraform init -backend-config="key=/this/state/file"
  }
}

```

### 3. audit\_comment

Although the majority of tf variables have sensible defaults, you are expected
to set `audit_comment` yourself, as indicated by its description in the .tf file.

You might just set it to the current aws iam name for example, or current date and time.

e.g.

```bash
export TF_VAR_audit_comment="deployed by $(aws sts get-caller-identity) at $(date '+%Y%m%d%H%M%S')"
```

### 4. Optional: including other opsgang vcl snippets

Grab other vcl (and accompanying terraform files) under subdirs of ./cfgs
in https://github.com/opsgang/fastly.

e.g. the files under http\_security\_headers can be dropped in alongside your main.tf
as well.

Add an `include` line in aws\_s3\_static\_backend.vcl.tpl for the new vcl snippet.

Then add a vcl {} block in your terraform `fastly_service_v1` resource for this new file.

You can find examples of this commented out in the .tf and .vcl.tpl files in this dir,
for http\_security\_headers.
