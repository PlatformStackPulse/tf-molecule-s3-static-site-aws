# tf-molecule-s3-static-site-aws

[![CI](https://github.com/PlatformStackPulse/tf-molecule-s3-static-site-aws/actions/workflows/ci.yml/badge.svg)](https://github.com/PlatformStackPulse/tf-molecule-s3-static-site-aws/actions/workflows/ci.yml)
[![Release](https://github.com/PlatformStackPulse/tf-molecule-s3-static-site-aws/actions/workflows/auto-release.yml/badge.svg)](https://github.com/PlatformStackPulse/tf-molecule-s3-static-site-aws/actions/workflows/auto-release.yml)
[![CodeQL](https://github.com/PlatformStackPulse/tf-molecule-s3-static-site-aws/actions/workflows/codeql.yml/badge.svg)](https://github.com/PlatformStackPulse/tf-molecule-s3-static-site-aws/actions/workflows/codeql.yml)
[![Changelog](https://github.com/PlatformStackPulse/tf-molecule-s3-static-site-aws/actions/workflows/changelog.yml/badge.svg)](https://github.com/PlatformStackPulse/tf-molecule-s3-static-site-aws/actions/workflows/changelog.yml)
[![Latest Release](https://img.shields.io/github/v/release/PlatformStackPulse/tf-molecule-s3-static-site-aws?sort=semver)](https://github.com/PlatformStackPulse/tf-molecule-s3-static-site-aws/releases)
![Terraform](https://img.shields.io/badge/terraform-%3E%3D1.6.0-blueviolet?logo=terraform)
![License](https://img.shields.io/github/license/PlatformStackPulse/tf-molecule-s3-static-site-aws)

---

S3 static-website hosting bucket with a security baseline, CORS, website config, and a bucket policy — composed from tested atoms in a single module call.

## Purpose

An S3 static website hosting molecule that composes multiple atoms to deliver a fully-configured static site bucket. Provides website configuration, CORS rules, encryption, public access block, bucket policy (for CloudFront OAC or public read), and optional lifecycle/notification support — all in a single module call.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  tf-molecule-s3-static-site-aws                                             │
│                                                                             │
│  ┌──────────────────┐                                                       │
│  │ tf-atom-s3-      │──────────────────────────────────────────┐            │
│  │ bucket-aws       │                                          │            │
│  │ (core bucket)    │                                          │            │
│  └────────┬─────────┘                                          │            │
│           │ bucket_id                                          │            │
│           ├─────────────┬──────────────┬───────────────┬───────┤            │
│           ▼             ▼              ▼               ▼       │            │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌────────────────┐    │
│  │ public-      │ │ encryption   │ │ website-     │ │ cors-          │    │
│  │ access-block │ │ (AES256)     │ │ configuration│ │ configuration  │    │
│  │ (all blocked)│ │              │ │ (index.html) │ │ (web origins)  │    │
│  └──────────────┘ └──────────────┘ └──────────────┘ └────────────────┘    │
│           │                                                                 │
│           ├─────────────┬──────────────────────┐                            │
│           ▼             ▼                      ▼                            │
│  ┌──────────────┐ ┌──────────────────┐ ┌──────────────────┐               │
│  │ policy       │ │ lifecycle        │ │ notification     │               │
│  │ (CloudFront/ │ │ (optional)       │ │ (optional)       │               │
│  │  public)     │ │                  │ │                  │               │
│  └──────────────┘ └──────────────────┘ └──────────────────┘               │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Scope

| In Scope | Out of Scope |
|----------|--------------|
| Bucket creation with tf-label naming | CloudFront distribution (→ `tf-molecule-s3-web-hosting-aws`) |
| Public access block (all 4 controls) | SSL certificates / ACM |
| Server-side encryption (AES256 default) | Route53 DNS records |
| Website configuration (index/error docs) | Object versioning (→ `tf-molecule-s3-secure-bucket-aws`) |
| CORS rules for web origins | Access logging (→ `tf-molecule-s3-secure-bucket-aws`) |
| Bucket policy (CloudFront OAC / public read) | WAF integration |
| Lifecycle rules (optional deploy cleanup) | Replication |
| Event notifications (optional cache invalidation) | Object lock |

## Features

- **Static site ready** — website configuration with index/error document support
- **CORS configured** — browser-compatible cross-origin rules for web frontends
- **Composed from atoms** — each concern is a separate, tested module
- **Optional lifecycle** — clean up old deploy artifacts automatically
- **Optional notifications** — trigger Lambda for cache invalidation or deploy hooks
- **CloudFront compatible** — policy supports OAC-based access or public read
- **Encryption at rest** — AES256 default (sufficient for public static content)
- **Context propagation** — inherits namespace, environment, stage, name via tf-label

## Usage

### Minimal (static site with defaults)

```hcl
module "static_site" {
  source = "git::https://github.com/PlatformStackPulse/tf-molecule-s3-static-site-aws.git?ref=v1.0.0"

  namespace   = "myorg"
  environment = "production"
  name        = "website"

  bucket_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicRead"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "arn:aws:s3:::myorg-production-website/*"
    }]
  })
}
```

### Full configuration (CloudFront OAC + notifications)

```hcl
module "static_site" {
  source = "git::https://github.com/PlatformStackPulse/tf-molecule-s3-static-site-aws.git?ref=v1.0.0"

  namespace   = "myorg"
  environment = "production"
  name        = "website"

  # Website config
  index_document = "index.html"
  error_document = "404.html"

  # CORS
  cors_allowed_origins = ["https://myapp.example.com"]
  cors_allowed_methods = ["GET", "HEAD"]

  # CloudFront OAC policy
  bucket_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "CloudFrontOAC"
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "arn:aws:s3:::myorg-production-website/*"
      Condition = {
        StringEquals = { "AWS:SourceArn" = aws_cloudfront_distribution.this.arn }
      }
    }]
  })

  # Optional: deploy cleanup
  enable_lifecycle = true
  lifecycle_rules = [{
    id              = "cleanup-old-deploys"
    prefix          = "old/"
    expiration_days = 30
  }]

  # Optional: cache invalidation trigger
  lambda_notifications = [{
    lambda_function_arn = aws_lambda_function.invalidator.arn
    events             = ["s3:ObjectCreated:*"]
    filter_prefix      = "assets/"
  }]
}
```

## Composed Atoms

| Atom | Role in Molecule | Default |
|------|-----------------|---------|
| [`tf-atom-s3-bucket-aws`](https://github.com/PlatformStackPulse/tf-atom-s3-bucket-aws) | Core bucket | Always created |
| [`tf-atom-s3-bucket-public-access-block-aws`](https://github.com/PlatformStackPulse/tf-atom-s3-bucket-public-access-block-aws) | Block public access | All 4 controls = true |
| [`tf-atom-s3-bucket-encryption-aws`](https://github.com/PlatformStackPulse/tf-atom-s3-bucket-encryption-aws) | Encryption at rest | AES256 |
| [`tf-atom-s3-bucket-website-configuration-aws`](https://github.com/PlatformStackPulse/tf-atom-s3-bucket-website-configuration-aws) | Website hosting config | index.html / error.html |
| [`tf-atom-s3-bucket-cors-configuration-aws`](https://github.com/PlatformStackPulse/tf-atom-s3-bucket-cors-configuration-aws) | CORS rules | GET/HEAD from allowed origins |
| [`tf-atom-s3-bucket-policy-aws`](https://github.com/PlatformStackPulse/tf-atom-s3-bucket-policy-aws) | Bucket policy | User-provided (CloudFront/public) |
| [`tf-atom-s3-bucket-lifecycle-configuration-aws`](https://github.com/PlatformStackPulse/tf-atom-s3-bucket-lifecycle-configuration-aws) | Lifecycle rules | Disabled (set rules to enable) |
| [`tf-atom-s3-bucket-notification-aws`](https://github.com/PlatformStackPulse/tf-atom-s3-bucket-notification-aws) | Event notifications | Disabled (set triggers to enable) |

## CI/CD Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `ci.yml` | Push/PR to main, feature branches | Format, validate, lint, test, security |
| `auto-release.yml` | CI passes on main | Semantic version tag + GitHub Release + artifacts |
| `preview-release.yml` | CI passes on feature branch | Pre-release tag for testing |
| `codeql.yml` | Weekly + push main | SAST security analysis |
| `changelog.yml` | Push main | Auto-update CHANGELOG.md |
| `dependencies.yml` | Weekly | Check for provider updates |

## Module Documentation

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |

### Providers

No providers.

### Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_bucket"></a> [bucket](#module\_bucket) | git::https://github.com/PlatformStackPulse/tf-atom-s3-bucket-aws.git | ad2f7ac361eb89f873afe25769246898eb1e34ba |
| <a name="module_bucket_policy"></a> [bucket\_policy](#module\_bucket\_policy) | git::https://github.com/PlatformStackPulse/tf-atom-s3-bucket-policy-aws.git | c534c331a0cfec621b79d40de92710a97290966d |
| <a name="module_cors_configuration"></a> [cors\_configuration](#module\_cors\_configuration) | git::https://github.com/PlatformStackPulse/tf-atom-s3-bucket-cors-configuration-aws.git | 432576880a216f63c6791db2d0f79eae370ac373 |
| <a name="module_encryption"></a> [encryption](#module\_encryption) | git::https://github.com/PlatformStackPulse/tf-atom-s3-bucket-encryption-aws.git | a3f83c3ef6208f44428345c7bcbd9a8a05bd401d |
| <a name="module_lifecycle_configuration"></a> [lifecycle\_configuration](#module\_lifecycle\_configuration) | git::https://github.com/PlatformStackPulse/tf-atom-s3-bucket-lifecycle-configuration-aws.git | 715e6b5fbcb1e4d77056c28b422937c03cb166c1 |
| <a name="module_notification"></a> [notification](#module\_notification) | git::https://github.com/PlatformStackPulse/tf-atom-s3-bucket-notification-aws.git | 9eae1fa230a0e4d15c5c6a2065eb85d9e3473857 |
| <a name="module_public_access_block"></a> [public\_access\_block](#module\_public\_access\_block) | git::https://github.com/PlatformStackPulse/tf-atom-s3-bucket-public-access-block-aws.git | 141d21b8e5af97d018183e11d5e590758aab5d90 |
| <a name="module_this"></a> [this](#module\_this) | git::https://github.com/PlatformStackPulse/tf-label.git | v1.0.0 |
| <a name="module_website_configuration"></a> [website\_configuration](#module\_website\_configuration) | git::https://github.com/PlatformStackPulse/tf-atom-s3-bucket-website-configuration-aws.git | f36e52f762c65d7159b385f5ed0b8b4b636647f2 |

### Resources

No resources.

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bucket_policy"></a> [bucket\_policy](#input\_bucket\_policy) | JSON-encoded IAM policy document for bucket access (e.g. CloudFront OAC read) | `string` | n/a | yes |
| <a name="input_attributes"></a> [attributes](#input\_attributes) | ID element. Additional attributes (e.g. `workers` or `cluster`) to add to `id`,<br/>in the order they appear in the list. New attributes are appended to the<br/>end of the list. The elements of the list are joined by the `delimiter`<br/>and treated as a single ID element. | `list(string)` | `[]` | no |
| <a name="input_bucket_key_enabled"></a> [bucket\_key\_enabled](#input\_bucket\_key\_enabled) | Enable S3 Bucket Key to reduce KMS costs | `bool` | `true` | no |
| <a name="input_context"></a> [context](#input\_context) | Single object for setting entire context at once.<br/>See description of individual variables for details.<br/>Leave string and numeric variables as `null` to use default value.<br/>Individual variable settings (non-null) override settings in context object,<br/>except for attributes and tags, which are merged. | <pre>object({<br/>    enabled             = optional(bool, true)<br/>    namespace           = optional(string, null)<br/>    tenant              = optional(string, null)<br/>    environment         = optional(string, null)<br/>    stage               = optional(string, null)<br/>    name                = optional(string, null)<br/>    delimiter           = optional(string, null)<br/>    attributes          = optional(list(string), [])<br/>    tags                = optional(map(string), {})<br/>    label_order         = optional(list(string), null)<br/>    regex_replace_chars = optional(string, null)<br/>    id_length_limit     = optional(number, null)<br/>    label_key_case      = optional(string, null)<br/>    label_value_case    = optional(string, null)<br/>    labels_as_tags      = optional(set(string), null)<br/>    descriptor_formats = optional(map(object({<br/>      format = string<br/>      labels = list(string)<br/>    })), {})<br/>  })</pre> | `{}` | no |
| <a name="input_cors_rules"></a> [cors\_rules](#input\_cors\_rules) | CORS rules for the static site bucket | <pre>list(object({<br/>    allowed_headers = optional(list(string), ["*"])<br/>    allowed_methods = list(string)<br/>    allowed_origins = list(string)<br/>    expose_headers  = optional(list(string), [])<br/>    max_age_seconds = optional(number, 3600)<br/>  }))</pre> | <pre>[<br/>  {<br/>    "allowed_headers": [<br/>      "*"<br/>    ],<br/>    "allowed_methods": [<br/>      "GET",<br/>      "HEAD"<br/>    ],<br/>    "allowed_origins": [<br/>      "*"<br/>    ],<br/>    "expose_headers": [],<br/>    "max_age_seconds": 3600<br/>  }<br/>]</pre> | no |
| <a name="input_delimiter"></a> [delimiter](#input\_delimiter) | Delimiter to be used between ID elements.<br/>Defaults to `-` (hyphen). Set to `""` to use no delimiter at all. | `string` | `null` | no |
| <a name="input_descriptor_formats"></a> [descriptor\_formats](#input\_descriptor\_formats) | Describe additional descriptors to be output in the `descriptors` output map.<br/>Map of maps. Keys are names of descriptors. Values are maps of the form<br/>`{<br/>   format = string<br/>   labels = list(string)<br/>}`<br/>`format` is a Terraform format string to be passed to the `format()` function.<br/>`labels` is a list of labels, in order, to pass to `format()` function.<br/>Label values will be normalized before being passed to `format()` so they will be<br/>identical to how they appear in `id`.<br/>Default is `{}` (`descriptors` output will be empty). | <pre>map(object({<br/>    format = string<br/>    labels = list(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_enable_lifecycle"></a> [enable\_lifecycle](#input\_enable\_lifecycle) | Enable lifecycle rules for deploy artifact cleanup | `bool` | `false` | no |
| <a name="input_enable_notifications"></a> [enable\_notifications](#input\_enable\_notifications) | Enable S3 event notifications (deploy triggers, cache invalidation) | `bool` | `false` | no |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | Set to false to prevent the module from creating any resources. | `bool` | `null` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | ID element. Usually used for region e.g. 'uw2', 'us-west-2', OR role 'prod', 'staging', 'dev', 'UAT'. | `string` | `null` | no |
| <a name="input_error_document"></a> [error\_document](#input\_error\_document) | Name of the error document (null to disable) | `string` | `"error.html"` | no |
| <a name="input_force_destroy"></a> [force\_destroy](#input\_force\_destroy) | Allow destruction of non-empty bucket (use only in dev/test) | `bool` | `false` | no |
| <a name="input_id_length_limit"></a> [id\_length\_limit](#input\_id\_length\_limit) | Limit `id` to this many characters (minimum 6).<br/>Set to `0` for unlimited length.<br/>Set to `null` to keep the existing setting, which defaults to `0`.<br/>Does not affect `id_full`. | `number` | `null` | no |
| <a name="input_index_document"></a> [index\_document](#input\_index\_document) | Name of the index document | `string` | `"index.html"` | no |
| <a name="input_kms_key_id"></a> [kms\_key\_id](#input\_kms\_key\_id) | KMS key ARN for encryption (required when sse\_algorithm is aws:kms) | `string` | `null` | no |
| <a name="input_label_key_case"></a> [label\_key\_case](#input\_label\_key\_case) | Controls the letter case of the `tags` keys (label names) for tags generated by this module.<br/>Does not affect keys of tags passed in via the `tags` input.<br/>Possible values: `lower`, `title`, `upper`.<br/>Default value: `title`. | `string` | `null` | no |
| <a name="input_label_order"></a> [label\_order](#input\_label\_order) | The order in which the labels (ID elements) appear in the `id`.<br/>Defaults to ["namespace", "environment", "stage", "name", "attributes"].<br/>You can omit any of the 6 labels ("tenant" is the 6th), but at least one must be present. | `list(string)` | `null` | no |
| <a name="input_label_value_case"></a> [label\_value\_case](#input\_label\_value\_case) | Controls the letter case of ID elements (labels) as included in `id`,<br/>set as tag values, and output by this module individually.<br/>Does not affect values of tags passed in via the `tags` input.<br/>Possible values: `lower`, `title`, `upper` and `none` (no transformation).<br/>Set this to `title` and set `delimiter` to `""` to yield Pascal Case IDs.<br/>Default value: `lower`. | `string` | `null` | no |
| <a name="input_labels_as_tags"></a> [labels\_as\_tags](#input\_labels\_as\_tags) | Set of labels (ID elements) to include as tags in the `tags` output.<br/>Default is to include all labels.<br/>Tags with empty values will not be included in the `tags` output.<br/>Set to `[]` to suppress all generated tags.<br/>Note: The value of the `name` tag, if included, will be the `id`, not the `name`. | `set(string)` | `null` | no |
| <a name="input_lambda_notifications"></a> [lambda\_notifications](#input\_lambda\_notifications) | Lambda function notification configurations | <pre>list(object({<br/>    lambda_function_arn = string<br/>    events              = list(string)<br/>    filter_prefix       = optional(string, null)<br/>    filter_suffix       = optional(string, null)<br/>  }))</pre> | `[]` | no |
| <a name="input_lifecycle_rules"></a> [lifecycle\_rules](#input\_lifecycle\_rules) | Lifecycle rules for the bucket | <pre>list(object({<br/>    id                                 = string<br/>    status                             = optional(string, "Enabled")<br/>    prefix                             = optional(string, "")<br/>    expiration_days                    = optional(number, null)<br/>    noncurrent_version_expiration_days = optional(number, null)<br/>    transition = optional(list(object({<br/>      days          = number<br/>      storage_class = string<br/>    })), [])<br/>  }))</pre> | `[]` | no |
| <a name="input_name"></a> [name](#input\_name) | ID element. Usually the component or solution name, e.g. 'app' or 'jenkins'.<br/>This is the only ID element not also included as a `tag`.<br/>The "name" tag is set to the full `id` string. There is no tag with the value of the `name` input. | `string` | `null` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | ID element. Usually an abbreviation of your organization name, e.g. 'eg' or 'cp', to help ensure generated IDs are globally unique. | `string` | `null` | no |
| <a name="input_regex_replace_chars"></a> [regex\_replace\_chars](#input\_regex\_replace\_chars) | Terraform regular expression (regex) string.<br/>Characters matching the regex will be removed from the ID elements.<br/>If not set, `"/[^a-zA-Z0-9-]/"` is used to remove all characters other than hyphens, letters and digits. | `string` | `null` | no |
| <a name="input_sns_notifications"></a> [sns\_notifications](#input\_sns\_notifications) | SNS topic notification configurations | <pre>list(object({<br/>    topic_arn     = string<br/>    events        = list(string)<br/>    filter_prefix = optional(string, null)<br/>    filter_suffix = optional(string, null)<br/>  }))</pre> | `[]` | no |
| <a name="input_sqs_notifications"></a> [sqs\_notifications](#input\_sqs\_notifications) | SQS queue notification configurations | <pre>list(object({<br/>    queue_arn     = string<br/>    events        = list(string)<br/>    filter_prefix = optional(string, null)<br/>    filter_suffix = optional(string, null)<br/>  }))</pre> | `[]` | no |
| <a name="input_sse_algorithm"></a> [sse\_algorithm](#input\_sse\_algorithm) | Server-side encryption algorithm (AES256 or aws:kms) | `string` | `"AES256"` | no |
| <a name="input_stage"></a> [stage](#input\_stage) | ID element. Usually used to indicate role, e.g. 'prod', 'staging', 'source', 'build', 'test', 'deploy', 'release'. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags (e.g. `{'BusinessUnit': 'XYZ'}`).<br/>Neither the tag keys nor the tag values will be modified by this module. | `map(string)` | `{}` | no |
| <a name="input_tenant"></a> [tenant](#input\_tenant) | ID element. A customer identifier, indicating who this instance of a resource is for. | `string` | `null` | no |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_bucket_arn"></a> [bucket\_arn](#output\_bucket\_arn) | ARN of the S3 bucket |
| <a name="output_bucket_id"></a> [bucket\_id](#output\_bucket\_id) | ID of the S3 bucket |
| <a name="output_bucket_regional_domain_name"></a> [bucket\_regional\_domain\_name](#output\_bucket\_regional\_domain\_name) | Regional domain name of the bucket (for CloudFront origin) |
| <a name="output_website_domain"></a> [website\_domain](#output\_website\_domain) | S3 website domain (for Route53 alias) |
| <a name="output_website_endpoint"></a> [website\_endpoint](#output\_website\_endpoint) | S3 website endpoint URL |
<!-- END_TF_DOCS -->

## Tests

Unit tests run against a mock AWS provider (no credentials, no real resources) and
assert on plan-known values only — the tf-label `id`, the `enabled` flag, and the
optional-atom counts:

```bash
# Unit tests (mock provider — safe to run anywhere)
terraform init -backend=false
terraform test -test-directory=tests/unit
# or:
make test-unit
```

Coverage in `tests/unit/main_test.tftest.hcl`:

| Run block | What it asserts |
|-----------|-----------------|
| `creates_when_enabled` | tf-label `id` is `eg-test-thing`; module enabled; optional atoms off by default |
| `optional_atoms_toggle_on` | `lifecycle_configuration` + `notification` atoms are created when their flags are set |
| `disabled_creates_nothing` | `enabled = false` yields a null `bucket_id` and no resources |

Integration tests in `tests/integration/` require real AWS credentials:

```bash
make test-integration   # terraform test -test-directory=tests/integration
```

## Contributing

1. Create a feature branch from `main`
2. Run `make fmt && make lint && make docs && make test`
3. Submit a PR — CI must pass before merge
4. Squash merge to `main` triggers auto-release
