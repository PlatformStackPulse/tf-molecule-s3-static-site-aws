# Unit Tests for tf-molecule-s3-static-site-aws
#
# These tests use a mock AWS provider — no real AWS calls are made.
# They assert on plan-KNOWN values (the tf-label id, the enabled flag,
# and the child-module count under enabled=false). Computed values such as
# bucket ARN/id are unknown under a mock provider and are NOT asserted on.
#
# Run with:      terraform test -test-directory=tests/unit
# Run verbose:   terraform test -test-directory=tests/unit -verbose

mock_provider "aws" {}

variables {
  # tf-label identity
  namespace = "eg"
  stage     = "test"
  name      = "thing"

  # Module's own required input
  bucket_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicRead"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "arn:aws:s3:::eg-test-thing/*"
    }]
  })
}

# ---------------------------------------------------------------------------
# Test: module composes the static-site atoms when enabled (default)
# ---------------------------------------------------------------------------
run "creates_when_enabled" {
  command = plan

  # tf-label id is derived from namespace-stage-name and is known at plan time.
  assert {
    condition     = module.this.id == "eg-test-thing"
    error_message = "tf-label id should be 'eg-test-thing' from namespace=eg, stage=test, name=thing"
  }

  # enabled defaults to true, so the null-label context is active.
  assert {
    condition     = module.this.enabled == true
    error_message = "module.this.enabled should default to true"
  }

  # Optional atoms are disabled by default (count = 0).
  assert {
    condition     = length(module.lifecycle_configuration) == 0
    error_message = "lifecycle_configuration should not be created when enable_lifecycle is false"
  }

  assert {
    condition     = length(module.notification) == 0
    error_message = "notification should not be created when enable_notifications is false"
  }
}

# ---------------------------------------------------------------------------
# Test: optional atoms turn on when their flags are set
# ---------------------------------------------------------------------------
run "optional_atoms_toggle_on" {
  command = plan

  variables {
    enable_lifecycle     = true
    enable_notifications = true
  }

  assert {
    condition     = length(module.lifecycle_configuration) == 1
    error_message = "lifecycle_configuration should be created when enable_lifecycle is true"
  }

  assert {
    condition     = length(module.notification) == 1
    error_message = "notification should be created when enable_notifications is true"
  }
}

# ---------------------------------------------------------------------------
# Test: module creates nothing when disabled
# ---------------------------------------------------------------------------
run "disabled_creates_nothing" {
  command = plan

  variables {
    enabled = false
  }

  # With the null-label context disabled, the core bucket is not created,
  # so the bucket_id output resolves to null (known at plan).
  assert {
    condition     = output.bucket_id == null
    error_message = "bucket_id should be null when the module is disabled"
  }

  assert {
    condition     = module.this.enabled == false
    error_message = "module.this.enabled should be false when enabled = false"
  }
}
