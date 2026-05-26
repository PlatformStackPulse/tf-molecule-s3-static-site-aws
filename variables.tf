variable "force_destroy" {
  type        = bool
  default     = false
  description = "Allow destruction of non-empty bucket (use only in dev/test)"
}

# --- Encryption ---
variable "sse_algorithm" {
  type        = string
  default     = "AES256"
  description = "Server-side encryption algorithm (AES256 or aws:kms)"
  validation {
    condition     = contains(["AES256", "aws:kms"], var.sse_algorithm)
    error_message = "sse_algorithm must be AES256 or aws:kms."
  }
}

variable "kms_key_id" {
  type        = string
  default     = null
  description = "KMS key ARN for encryption (required when sse_algorithm is aws:kms)"
}

variable "bucket_key_enabled" {
  type        = bool
  default     = true
  description = "Enable S3 Bucket Key to reduce KMS costs"
}

# --- Website Configuration ---
variable "index_document" {
  type        = string
  default     = "index.html"
  description = "Name of the index document"
}

variable "error_document" {
  type        = string
  default     = "error.html"
  description = "Name of the error document (null to disable)"
}

# --- CORS ---
variable "cors_rules" {
  type = list(object({
    allowed_headers = optional(list(string), ["*"])
    allowed_methods = list(string)
    allowed_origins = list(string)
    expose_headers  = optional(list(string), [])
    max_age_seconds = optional(number, 3600)
  }))
  default = [{
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = []
    max_age_seconds = 3600
  }]
  description = "CORS rules for the static site bucket"
}

# --- Bucket Policy ---
variable "bucket_policy" {
  type        = string
  description = "JSON-encoded IAM policy document for bucket access (e.g. CloudFront OAC read)"
  validation {
    condition     = can(jsondecode(var.bucket_policy))
    error_message = "bucket_policy must be valid JSON."
  }
}

# --- Lifecycle (optional) ---
variable "enable_lifecycle" {
  type        = bool
  default     = false
  description = "Enable lifecycle rules for deploy artifact cleanup"
}

variable "lifecycle_rules" {
  type = list(object({
    id                                 = string
    status                             = optional(string, "Enabled")
    prefix                             = optional(string, "")
    expiration_days                    = optional(number, null)
    noncurrent_version_expiration_days = optional(number, null)
    transition = optional(list(object({
      days          = number
      storage_class = string
    })), [])
  }))
  default     = []
  description = "Lifecycle rules for the bucket"
}

# --- Notifications (optional) ---
variable "enable_notifications" {
  type        = bool
  default     = false
  description = "Enable S3 event notifications (deploy triggers, cache invalidation)"
}

variable "lambda_notifications" {
  type = list(object({
    lambda_function_arn = string
    events              = list(string)
    filter_prefix       = optional(string, null)
    filter_suffix       = optional(string, null)
  }))
  default     = []
  description = "Lambda function notification configurations"
}

variable "sns_notifications" {
  type = list(object({
    topic_arn     = string
    events        = list(string)
    filter_prefix = optional(string, null)
    filter_suffix = optional(string, null)
  }))
  default     = []
  description = "SNS topic notification configurations"
}

variable "sqs_notifications" {
  type = list(object({
    queue_arn     = string
    events        = list(string)
    filter_prefix = optional(string, null)
    filter_suffix = optional(string, null)
  }))
  default     = []
  description = "SQS queue notification configurations"
}
