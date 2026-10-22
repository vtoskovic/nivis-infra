#!/usr/bin/env bash
# One-time bootstrap: create the private, versioned Spaces bucket that holds Terraform state.
# It lives outside Terraform on purpose (chicken-and-egg), like karta's bootstrap-tfstate.sh.
#
# Requirements: aws CLI v2, a Spaces key with full access exported as
#   AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY
#
# Usage: ./bootstrap/create-state-bucket.sh [bucket] [region]
set -euo pipefail

BUCKET="${1:-nivis-tfstate}"
REGION="${2:-fra1}"
ENDPOINT="https://${REGION}.digitaloceanspaces.com"
S3=(aws s3api --endpoint-url "$ENDPOINT" --region us-east-1)

: "${AWS_ACCESS_KEY_ID:?export AWS_ACCESS_KEY_ID (Spaces access key)}"
: "${AWS_SECRET_ACCESS_KEY:?export AWS_SECRET_ACCESS_KEY (Spaces secret key)}"

if "${S3[@]}" head-bucket --bucket "$BUCKET" >/dev/null 2>&1; then
  echo "Bucket $BUCKET already exists – verifying settings only."
else
  echo "Creating private bucket $BUCKET in $REGION..."
  "${S3[@]}" create-bucket --bucket "$BUCKET" --acl private
fi

echo "Enabling versioning (recover from a corrupted or deleted state file)..."
"${S3[@]}" put-bucket-versioning --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled

echo "Keeping old state versions for 90 days, cleaning up stale uploads..."
"${S3[@]}" put-bucket-lifecycle-configuration --bucket "$BUCKET" \
  --lifecycle-configuration '{
    "Rules": [{
      "ID": "state-history",
      "Status": "Enabled",
      "Filter": {"Prefix": ""},
      "NoncurrentVersionExpiration": {"NoncurrentDays": 90},
      "AbortIncompleteMultipartUpload": {"DaysAfterInitiation": 7}
    }]
  }'

echo "Verifying the bucket is not public..."
ACL=$("${S3[@]}" get-bucket-acl --bucket "$BUCKET" --query 'Grants[?Grantee.URI==`http://acs.amazonaws.com/groups/global/AllUsers`]' --output text)
if [[ -n "$ACL" && "$ACL" != "None" ]]; then
  echo "ERROR: bucket $BUCKET grants public access. Fix before storing state." >&2
  exit 1
fi

echo "Done. State bucket: s3://$BUCKET ($ENDPOINT)"
