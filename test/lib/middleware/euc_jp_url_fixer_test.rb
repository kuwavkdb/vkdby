# frozen_string_literal: true

require 'test_helper'
require 'middleware/euc_jp_url_fixer'

class EucJpUrlFixerTest < ActiveSupport::TestCase
  test 'should fix path with invalid UTF-8 encoding' do
    # Create a string with invalid UTF-8 (valid EUC-JP)
    # "\xB7\xDF\xB9\xFC" is EUC-JP bytes
    raw_path = "/\xB7\xDF\xB9\xFC.html".dup.force_encoding('UTF-8')

    # Verify it is indeed invalid UTF-8
    assert_not raw_path.valid_encoding?

    # Mock app
    app = ->(env) { [200, {}, [env['PATH_INFO']]] }
    middleware = Middleware::EucJpUrlFixer.new(app)

    # Call middleware
    env = { 'PATH_INFO' => raw_path }
    middleware.call(env)

    # Expect it to clearly encode to %-notation with double encoding
    expected_path = '/%25B7%25DF%25B9%25FC.html'
    assert_equal expected_path, env['PATH_INFO']
  end

  test 'should leave valid UTF-8 path unchanged' do
    valid_path = '/valid_path.html'
    env = { 'PATH_INFO' => valid_path }

    app = ->(env) { [200, {}, [env['PATH_INFO']]] }
    middleware = Middleware::EucJpUrlFixer.new(app)

    middleware.call(env)
    assert_equal valid_path, env['PATH_INFO']
  end

  test 'should double-encode high-bit percent sequences' do
    # This simulates what curl sends: "%B7" as ASCII chars
    encoded_path = '/%B7%DF.html'

    app = ->(env) { [200, {}, [env['PATH_INFO']]] }
    middleware = Middleware::EucJpUrlFixer.new(app)

    env = { 'PATH_INFO' => encoded_path }
    middleware.call(env)

    # Expect % to be double encoded so Rails sees literal %B7
    expected_path = '/%25B7%25DF.html'
    assert_equal expected_path, env['PATH_INFO']
  end
end
