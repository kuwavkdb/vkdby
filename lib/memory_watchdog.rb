# frozen_string_literal: true

require 'get_process_mem'

# Render.com のメモリ制限下で、メモリスパイクによりOSのOOM killerに強制終了される
# 前に、プロアクティブにグレースフルな自己再起動を行う安全策（issue #743）。
#
# puma_worker_killer gem はPumaのクラスターモード（workers設定によるマスター/
# ワーカー構成）を前提にしており、本アプリのようなシングルプロセス（threads only）
# 構成では機能しないため（https://github.com/schneems/puma_worker_killer#what）、
# get_process_mem で自プロセスのRSSを直接監視するシンプルな実装を採用する。
#
# 閾値超過時は自プロセスへSIGTERMを送るのみで、実際の終了処理はPuma本体（受付中の
# リクエストを完了してから終了する）に、再起動はRenderのプロセス監視に委ねる。
# リクエスト処理中でも問答無用で強制終了するOS OOM killer（SIGKILL）より安全。
module MemoryWatchdog
  # 再起動をトリガーするRSSの閾値（MB）。Starterプラン（512MB/0.5CPU）向けの値。
  # インスタンスタイプを変更した場合はrender.yamlのplanと合わせて見直すこと
  # （#1344, #1388）。
  DEFAULT_THRESHOLD_MB = 450
  # 監視間隔（秒）
  DEFAULT_CHECK_INTERVAL_SECONDS = 20

  module_function

  def start(threshold_mb: ENV.fetch('MEMORY_WATCHDOG_THRESHOLD_MB', DEFAULT_THRESHOLD_MB).to_i,
            check_interval: ENV.fetch('MEMORY_WATCHDOG_CHECK_INTERVAL', DEFAULT_CHECK_INTERVAL_SECONDS).to_i,
            pid: Process.pid)
    Thread.new do
      loop do
        sleep check_interval

        begin
          rss_mb = GetProcessMem.new(pid).mb
          next if rss_mb < threshold_mb

          Rails.logger.warn(
            "MemoryWatchdog: RSS #{rss_mb.round(1)}MB が閾値 #{threshold_mb}MB を超過したため、" \
            'グレースフル再起動のためSIGTERMを送信します'
          )
          Process.kill('TERM', pid)
          break
        rescue StandardError => e
          Rails.logger.error("MemoryWatchdog: 監視中にエラーが発生しました: #{e.class}: #{e.message}")
        end
      end
    end
  end
end
