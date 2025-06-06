defmodule HipcallSMS.AdapterTest do
  use ExUnit.Case
  doctest HipcallSMS.Adapter

  alias HipcallSMS.Adapter

  describe "validate_config/2" do
    test "passes validation with all required config present" do
      required_config = [:api_key, :secret]
      config = [api_key: "test_key", secret: "test_secret", extra: "value"]

      assert :ok = Adapter.validate_config(required_config, config)
    end

    test "raises error when required config is missing" do
      required_config = [:api_key, :secret]
      config = [api_key: "test_key"]

      assert_raise ArgumentError, ~r/Missing required configuration/, fn ->
        Adapter.validate_config(required_config, config)
      end
    end

    test "raises error when required config is nil" do
      required_config = [:api_key]
      config = [api_key: nil]

      assert_raise ArgumentError, ~r/Missing required configuration/, fn ->
        Adapter.validate_config(required_config, config)
      end
    end

    test "raises error when required config is empty string" do
      required_config = [:api_key]
      config = [api_key: ""]

      assert_raise ArgumentError, ~r/Missing required configuration/, fn ->
        Adapter.validate_config(required_config, config)
      end
    end

    test "passes validation with empty required config list" do
      required_config = []
      config = [api_key: "test_key"]

      assert :ok = Adapter.validate_config(required_config, config)
    end

    test "passes validation with empty config when no requirements" do
      required_config = []
      config = []

      assert :ok = Adapter.validate_config(required_config, config)
    end
  end

  describe "validate_dependency/1" do
    test "passes validation when all dependencies are available" do
      # These modules should be available in the test environment
      required_deps = [ExUnit, Kernel]

      assert :ok = Adapter.validate_dependency(required_deps)
    end

    test "returns error when dependencies are missing" do
      required_deps = [NonExistentModule]

      assert {:error, [NonExistentModule]} = Adapter.validate_dependency(required_deps)
    end

    test "returns error for library/module tuples when missing" do
      required_deps = [{:non_existent_lib, NonExistentModule}]

      assert {:error, [{:non_existent_lib, NonExistentModule}]} =
               Adapter.validate_dependency(required_deps)
    end

    test "passes validation with empty dependency list" do
      required_deps = []

      assert :ok = Adapter.validate_dependency(required_deps)
    end

    test "handles mixed available and missing dependencies" do
      required_deps = [ExUnit, NonExistentModule, Kernel]

      assert {:error, [NonExistentModule]} = Adapter.validate_dependency(required_deps)
    end
  end

  describe "get_config_value/2" do
    test "returns value from application environment" do
      Application.put_env(:hipcall_sms, :test_key, "test_value")

      assert "test_value" = Adapter.get_config_value(:test_key, "default")

      Application.delete_env(:hipcall_sms, :test_key)
    end

    test "returns default when key not found" do
      Application.delete_env(:hipcall_sms, :missing_key)

      assert "default_value" = Adapter.get_config_value(:missing_key, "default_value")
    end

    test "resolves system environment variables" do
      System.put_env("TEST_SMS_KEY", "env_value")
      Application.put_env(:hipcall_sms, :env_test_key, {:system, "TEST_SMS_KEY"})

      assert "env_value" = Adapter.get_config_value(:env_test_key, "default")

      System.delete_env("TEST_SMS_KEY")
      Application.delete_env(:hipcall_sms, :env_test_key)
    end

    test "returns default when system env var not found" do
      System.delete_env("MISSING_ENV_VAR")
      Application.put_env(:hipcall_sms, :missing_env_key, {:system, "MISSING_ENV_VAR"})

      assert "default_value" = Adapter.get_config_value(:missing_env_key, "default_value")

      Application.delete_env(:hipcall_sms, :missing_env_key)
    end

    test "handles nil values" do
      Application.put_env(:hipcall_sms, :nil_key, nil)

      assert "default_value" = Adapter.get_config_value(:nil_key, "default_value")

      Application.delete_env(:hipcall_sms, :nil_key)
    end
  end
end
