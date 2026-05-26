# tf-molecule-s3-static-site-aws
# Composes: S3 Bucket + Public Access Block + Encryption + Website Config + CORS + Policy + Notification (opt) + Lifecycle (opt)
# Purpose: S3 static website hosting with security baseline, CORS, and optional event notifications

# --- Core: S3 Bucket ---
module "bucket" {
  source  = "git::https://github.com/PlatformStackPulse/tf-atom-s3-bucket-aws.git?ref=ad2f7ac361eb89f873afe25769246898eb1e34ba"
  context = module.this.context

  force_destroy = var.force_destroy
}

# --- Security: Public Access Block (always — CloudFront/policy grants access, not ACLs) ---
module "public_access_block" {
  source  = "git::https://github.com/PlatformStackPulse/tf-atom-s3-bucket-public-access-block-aws.git?ref=141d21b8e5af97d018183e11d5e590758aab5d90"
  context = module.this.context

  bucket_id               = module.bucket.bucket_id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  depends_on = [module.bucket]
}

# --- Security: Encryption (AES256 default for static assets) ---
module "encryption" {
  source  = "git::https://github.com/PlatformStackPulse/tf-atom-s3-bucket-encryption-aws.git?ref=a3f83c3ef6208f44428345c7bcbd9a8a05bd401d"
  context = module.this.context

  bucket_id          = module.bucket.bucket_id
  sse_algorithm      = var.sse_algorithm
  kms_master_key_id  = var.kms_key_id
  bucket_key_enabled = var.bucket_key_enabled

  depends_on = [module.bucket]
}

# --- Website Configuration (always — defines index + error docs) ---
module "website_configuration" {
  source  = "git::https://github.com/PlatformStackPulse/tf-atom-s3-bucket-website-configuration-aws.git?ref=f36e52f762c65d7159b385f5ed0b8b4b636647f2"
  context = module.this.context

  bucket_id      = module.bucket.bucket_id
  index_document = var.index_document
  error_document = var.error_document

  depends_on = [module.bucket]
}

# --- CORS Configuration (always — web apps need cross-origin headers) ---
module "cors_configuration" {
  source  = "git::https://github.com/PlatformStackPulse/tf-atom-s3-bucket-cors-configuration-aws.git?ref=432576880a216f63c6791db2d0f79eae370ac373"
  context = module.this.context

  bucket_id  = module.bucket.bucket_id
  cors_rules = var.cors_rules

  depends_on = [module.bucket]
}

# --- Bucket Policy (always — grant read access to CloudFront or public) ---
module "bucket_policy" {
  source  = "git::https://github.com/PlatformStackPulse/tf-atom-s3-bucket-policy-aws.git?ref=c534c331a0cfec621b79d40de92710a97290966d"
  context = module.this.context

  bucket_id = module.bucket.bucket_id
  policy    = var.bucket_policy

  depends_on = [module.bucket]
}

# --- Lifecycle Configuration (optional — cleanup old deploy artifacts) ---
module "lifecycle_configuration" {
  source = "git::https://github.com/PlatformStackPulse/tf-atom-s3-bucket-lifecycle-configuration-aws.git?ref=715e6b5fbcb1e4d77056c28b422937c03cb166c1"
  count  = var.enable_lifecycle ? 1 : 0

  context         = module.this.context
  bucket_id       = module.bucket.bucket_id
  lifecycle_rules = var.lifecycle_rules

  depends_on = [module.bucket]
}

# --- Notifications (optional — deploy triggers / cache invalidation) ---
module "notification" {
  source = "git::https://github.com/PlatformStackPulse/tf-atom-s3-bucket-notification-aws.git?ref=9eae1fa230a0e4d15c5c6a2065eb85d9e3473857"
  count  = var.enable_notifications ? 1 : 0

  context   = module.this.context
  bucket_id = module.bucket.bucket_id

  lambda_notifications = var.lambda_notifications
  sns_notifications    = var.sns_notifications
  sqs_notifications    = var.sqs_notifications

  depends_on = [module.bucket]
}
