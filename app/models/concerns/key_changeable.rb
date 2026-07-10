# frozen_string_literal: true

# Person/Unit の key を管理者操作専用に変更するための共通処理(issue #57)。
# 通常の update では key_immutable バリデーションが変更をブロックするため、
# change_key! はそのバリデーションを一時的に迂回する専用パスとして提供する。
module KeyChangeable
  extend ActiveSupport::Concern

  included do
    attr_accessor :key_change_in_progress
  end

  # key を new_key に変更し、旧キーからのリダイレクト用スタブレコードを作成、
  # 旧キーを参照している他テーブルのレコードを一括で追従させる。
  def change_key!(new_key)
    return update!(key: new_key) if key.blank?

    prev_key = key

    transaction do
      begin
        self.key_change_in_progress = true
        update!(key: new_key)
      ensure
        self.key_change_in_progress = false
      end

      create_key_change_stub!(prev_key, new_key)
      rewrite_item_artist_keys(prev_key, new_key)
      after_key_change(prev_key, new_key)
    end
  end

  # discard 済み・destination_key ありのリダイレクト元レコードかどうか(issue #891)。
  # 物理削除できる対象をこの条件に厳密に限定する。
  def redirect_source?
    discarded? && destination_key.present?
  end

  private

  # サブクラスで、key を参照している独自テーブルのカスケード更新に使う
  def after_key_change(prev_key, new_key); end

  def create_key_change_stub!(prev_key, new_key)
    stub = dup
    stub.key = prev_key
    stub.destination_key = new_key
    stub.old_key = nil
    stub.created_at = nil
    stub.updated_at = nil
    stub.save!
    stub.discard
  end

  def rewrite_item_artist_keys(prev_key, new_key)
    Item.by_artist_key(prev_key).find_each do |item|
      updated_artists = item.artists.map { |a| a['key'] == prev_key ? a.merge('key' => new_key) : a }
      item.update_column(:artists, updated_artists)
    end
  end
end
