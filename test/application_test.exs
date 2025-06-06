defmodule HipcallSMS.ApplicationTest do
  use ExUnit.Case
  doctest HipcallSMS.Application

  alias HipcallSMS.Application

  describe "start/2" do
    test "returns supervisor spec" do
      # Application might already be started, so we handle both cases
      case Application.start(:normal, []) do
        {:ok, _pid} -> :ok
        {:error, {:already_started, _pid}} -> :ok
      end
    end

    test "starts with different start types" do
      # Since the application might already be started, we just verify
      # that the start function can handle different start types without crashing
      case Application.start(:normal, []) do
        {:ok, _pid} -> :ok
        {:error, {:already_started, _pid}} -> :ok
      end

      case Application.start({:takeover, :node}, []) do
        {:ok, _pid} -> :ok
        {:error, {:already_started, _pid}} -> :ok
      end

      case Application.start({:failover, :node}, []) do
        {:ok, _pid} -> :ok
        {:error, {:already_started, _pid}} -> :ok
      end
    end
  end

  describe "children/0" do
    test "returns empty list of children" do
      # The application currently has no children to supervise
      # This test ensures the function exists and returns the expected format
      children = Application.children()
      assert is_list(children)
      assert children == []
    end
  end
end
