defmodule HipcallSMSTest do
  use ExUnit.Case
  doctest HipcallSMS

  test "greets the world" do
    assert HipcallSMS.hello() == :world
  end
end
