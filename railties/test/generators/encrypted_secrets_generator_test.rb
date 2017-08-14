require "generators/generators_test_helper"
require "rails/generators/rails/encrypted_secrets/encrypted_secrets_generator"

class EncryptedSecretsGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper

  def setup
    super
    cd destination_root
  end

  def test_generates_key_file_and_encrypted_secrets_file
    run_generator ["config/secrets.yml.enc"]

    assert_file "config/secrets.yml.key", /\w+/

    assert File.exist?("config/secrets.yml.enc")
    assert_no_match(/production:\n#  external_api_key: \w+/, IO.binread("config/secrets.yml.enc"))
    assert_match(/production:\n#  external_api_key: \w+/, Rails::Secrets.new("config/secrets.yml.enc").read)
  end

  def test_appends_to_gitignore
    FileUtils.touch(".gitignore")

    run_generator ["config/secrets.yml.enc"]

    assert_file ".gitignore", /config\/secrets.yml.key/, /(?!config\/secrets.yml.enc)/
  end

  def test_warns_when_ignore_is_missing
    assert_match(/Add this to your ignore file/i, run_generator(["config/secrets.yml.enc"]))
  end

  def test_doesnt_generate_a_new_key_file_if_already_opted_in_to_encrypted_secrets
    FileUtils.mkdir("config")
    File.open("config/secrets.yml.enc", "w") { |f| f.puts "already secrety" }

    run_generator ["config/secrets.yml.enc"]

    assert_no_file "config/secrets.yml.key"
  end

  def test_generates_key_file_and_encrypted_secrets_file_into_non_default_path
    run_generator ["config/secrets-staging.yml.enc"]

    assert_file "config/secrets-staging.yml.key", /\w+/

    assert File.exist?("config/secrets-staging.yml.enc")
    assert_no_match(/production:\n#  external_api_key: \w+/, IO.binread("config/secrets-staging.yml.enc"))
    assert_match(/production:\n#  external_api_key: \w+/, Rails::Secrets.new("config/secrets-staging.yml.enc").read)
  end
end
