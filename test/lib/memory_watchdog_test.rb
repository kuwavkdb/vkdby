# frozen_string_literal: true

require 'test_helper'
require 'memory_watchdog'

class MemoryWatchdogTest < ActiveSupport::TestCase
  test '閾値を超えたら自プロセスへSIGTERMを送信する' do
    killed = []
    fake_mem = Object.new.tap { |o| o.define_singleton_method(:mb) { 500.0 } }

    stub_class_method(GetProcessMem, :new, ->(*_args) { fake_mem }) do
      stub_class_method(Process, :kill, ->(*args) { killed << args }) do
        thread = MemoryWatchdog.start(threshold_mb: 450, check_interval: 0, pid: 12_345)
        thread.join(1)
        assert_not thread.alive?
      end
    end

    assert_equal [['TERM', 12_345]], killed
  end

  test '閾値未満の場合は再起動しない' do
    killed = []
    fake_mem = Object.new.tap { |o| o.define_singleton_method(:mb) { 100.0 } }

    stub_class_method(GetProcessMem, :new, ->(*_args) { fake_mem }) do
      stub_class_method(Process, :kill, ->(*args) { killed << args }) do
        thread = MemoryWatchdog.start(threshold_mb: 450, check_interval: 0, pid: 12_345)
        sleep 0.05
        thread.kill
        thread.join
      end
    end

    assert_empty killed
  end

  test 'log_interval指定時は閾値未満でも一定間隔でRSSをWARNログに出す（issue #1521）' do
    # 本番のlog_levelはデフォルトwarn（#482）でinfoは握りつぶされるため、
    # このデバッグログはwarnで出す必要がある
    fake_mem = Object.new.tap { |o| o.define_singleton_method(:mb) { 100.0 } }
    warn_logs = []
    fake_logger = Object.new.tap do |o|
      o.define_singleton_method(:info) { |_msg| }
      o.define_singleton_method(:warn) { |msg| warn_logs << msg }
      o.define_singleton_method(:error) { |_msg| }
    end
    original_logger = Rails.logger
    Rails.logger = fake_logger

    stub_class_method(GetProcessMem, :new, ->(*_args) { fake_mem }) do
      thread = MemoryWatchdog.start(threshold_mb: 450, check_interval: 0.02, log_interval: 0.05, pid: 12_345)
      sleep 0.2
      thread.kill
      thread.join
    end

    assert_operator warn_logs.size, :>=, 2
    assert_match(/RSS 100\.0MB（閾値 450MB）/, warn_logs.first)
  ensure
    Rails.logger = original_logger
  end

  test 'log_interval未指定の場合は閾値未満でWARNログを出さない' do
    fake_mem = Object.new.tap { |o| o.define_singleton_method(:mb) { 100.0 } }
    warn_logs = []
    fake_logger = Object.new.tap do |o|
      o.define_singleton_method(:info) { |_msg| }
      o.define_singleton_method(:warn) { |msg| warn_logs << msg }
      o.define_singleton_method(:error) { |_msg| }
    end
    original_logger = Rails.logger
    Rails.logger = fake_logger

    stub_class_method(GetProcessMem, :new, ->(*_args) { fake_mem }) do
      thread = MemoryWatchdog.start(threshold_mb: 450, check_interval: 0.02, pid: 12_345)
      sleep 0.1
      thread.kill
      thread.join
    end

    assert_empty warn_logs
  ensure
    Rails.logger = original_logger
  end

  test 'メモリ取得でエラーが発生してもスレッドは監視を継続する' do
    killed = []
    call_count = 0
    fake_new = lambda do |*_args|
      call_count += 1
      raise 'boom' if call_count == 1

      Object.new.tap { |o| o.define_singleton_method(:mb) { 500.0 } }
    end

    stub_class_method(GetProcessMem, :new, fake_new) do
      stub_class_method(Process, :kill, ->(*args) { killed << args }) do
        thread = MemoryWatchdog.start(threshold_mb: 450, check_interval: 0, pid: 12_345)
        thread.join(1)
        assert_not thread.alive?
      end
    end

    assert_operator call_count, :>=, 2
    assert_equal [['TERM', 12_345]], killed
  end
end
