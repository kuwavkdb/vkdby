# frozen_string_literal: true

# Render free tier (512MB) ではヒープ断片化が OOM の一因になりうるため、
# 本番環境では世代別 GC のタイミングでヒープを自動コンパクションする。
GC.auto_compact = true if Rails.env.production?
