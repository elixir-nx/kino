defmodule Kino.AudioTest do
  use Kino.LivebookCase, async: true

  describe "new/2" do
    test "raises an error for a non-image MIME type" do
      assert_raise ArgumentError,
                   ~s{expected audio type to be either :wav, :mp3, :mpeg, :ogg, or an audio MIME type string, got: "application/json"},
                   fn ->
                     Kino.Audio.new(<<>>, "application/json")
                   end
    end

    test "raises an error for an invalid type shorthand" do
      assert_raise ArgumentError,
                   "expected audio type to be either :wav, :mp3, :mpeg, :ogg, or an audio MIME type string, got: :invalid",
                   fn ->
                     Kino.Audio.new(<<>>, :invalid)
                   end
    end

    test "mime type shorthand and default opts" do
      kino = Kino.Audio.new(<<>>, :wav)
      assert {:binary, %{type: "audio/wav", opts: "controls"}, <<>>} == connect(kino)
    end

    test "custom mime type and custom opts" do
      kino = Kino.Audio.new(<<>>, "audio/mp2", loop: true)
      assert {:binary, %{type: "audio/mp2", opts: "controls loop"}, <<>>} == connect(kino)
    end
  end
end
