# vim: et sr sw=4 ts=4 smartindent syntax=dockerfile:
FROM opsgang/aws_terraform:0.10

LABEL \
      name="opsgang/terraform_deploy" \
      description="tools for deploying opsgang projects with terraform 0.10"

COPY assets/* /

RUN chmod a+x /opsgang/terraform_deploy/bin/*

ENTRYPOINT ["/bootstrap.sh"]

# build process adds this additional label info to image
#
# opsgang.terraform_deploy.build_git_uri
# opsgang.terraform_deploy.build_git_sha
# opsgang.terraform_deploy.build_git_branch
# opsgang.terraform_deploy.build_git_tag
# opsgang.terraform_deploy.built_by
#
