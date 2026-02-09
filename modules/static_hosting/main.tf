resource "aws_s3_bucket" "static" {
  for_each = var.static_client_configs
  bucket   = "${var.project_name}-${each.key}-static"
  
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "static" {
  for_each = var.static_client_configs
  bucket   = aws_s3_bucket.static[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_control" "default" {
  name                              = "${var.project_name}-oac"
  description                       = "Default OAC for S3 origins"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "s3_dist" {
  for_each = var.static_client_configs

  origin {
    domain_name              = aws_s3_bucket.static[each.key].bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.default.id
    origin_id                = "S3Origin"
  }

  enabled             = true
  is_ipv6_enabled    = true
  default_root_object = "index.html"

  aliases = [each.value.domain_name]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3Origin"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Name = "${var.project_name}-${each.key}-cf"
  }
}

# S3 Bucket Policy for CloudFront access
resource "aws_s3_bucket_policy" "cf_s3_policy" {
  for_each = var.static_client_configs
  bucket   = aws_s3_bucket.static[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "s3:GetObject"
        Effect   = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Resource = "${aws_s3_bucket.static[each.key].arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.s3_dist[each.key].arn
          }
        }
      }
    ]
  })
}
