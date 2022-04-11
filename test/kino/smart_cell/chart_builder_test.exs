defmodule Kino.SmartCell.ChartBuilderTest do
  use Kino.LivebookCase, async: true

  import KinoTest.SmartCell

  alias Kino.SmartCell.ChartBuilder

  @defaults %{
    "chart_type" => "bar",
    "data_variable" => "data",
    "width" => nil,
    "height" => nil,
    "x_field" => "a",
    "y_field" => "b",
    "color_field" => nil,
    "x_field_type" => nil,
    "y_field_type" => nil,
    "color_field_type" => nil,
    "x_field_aggregate" => nil,
    "y_field_aggregate" => nil,
    "color_field_aggregate" => nil,
    "chart_title" => nil,
    "vl_alias" => VegaLite
  }

  test "returns no source when starting fresh with no data" do
    {_widget, source} = start_smart_cell!(ChartBuilder, %{})

    assert source == ""
  end

  describe "code generation" do
    test "source for a basic bar plot with no optionals" do
      attrs = ChartBuilder.add_layer(@defaults)

      assert ChartBuilder.to_source(attrs) == """
             VegaLite.new()
             |> VegaLite.data_from_series(data)
             |> VegaLite.mark(:bar)
             |> VegaLite.encode_field(:x, "a")
             |> VegaLite.encode_field(:y, "b")\
             """
    end

    test "source for a basic line plot with alias" do
      attrs =
        Map.merge(@defaults, %{"chart_type" => "line", "vl_alias" => Vl})
        |> ChartBuilder.add_layer()

      assert ChartBuilder.to_source(attrs) == """
             Vl.new()
             |> Vl.data_from_series(data)
             |> Vl.mark(:line)
             |> Vl.encode_field(:x, "a")
             |> Vl.encode_field(:y, "b")\
             """
    end

    test "bar plot with color and color type" do
      attrs =
        Map.merge(@defaults, %{"color_field" => "c", "color_field_type" => "nominal"})
        |> ChartBuilder.add_layer()

      assert ChartBuilder.to_source(attrs) == """
             VegaLite.new()
             |> VegaLite.data_from_series(data)
             |> VegaLite.mark(:bar)
             |> VegaLite.encode_field(:x, "a")
             |> VegaLite.encode_field(:y, "b")
             |> VegaLite.encode_field(:color, "c", type: :nominal)\
             """
    end

    test "point plot with width x and y field types and color without type" do
      attrs =
        Map.merge(@defaults, %{
          "chart_type" => "point",
          "width" => 300,
          "x_field_type" => "nominal",
          "y_field_type" => "quantitative",
          "color_field" => "c"
        })
        |> ChartBuilder.add_layer()

      assert ChartBuilder.to_source(attrs) == """
             VegaLite.new(width: 300)
             |> VegaLite.data_from_series(data)
             |> VegaLite.mark(:point)
             |> VegaLite.encode_field(:x, "a", type: :nominal)
             |> VegaLite.encode_field(:y, "b", type: :quantitative)
             |> VegaLite.encode_field(:color, "c")\
             """
    end

    test "area plot with types and alias" do
      attrs =
        Map.merge(@defaults, %{
          "chart_type" => "point",
          "width" => 600,
          "height" => 300,
          "x_field_type" => "ordinal",
          "y_field_type" => "quantitative",
          "color_field" => "c",
          "color_field_type" => "nominal",
          "vl_alias" => Vl
        })
        |> ChartBuilder.add_layer()

      assert ChartBuilder.to_source(attrs) == """
             Vl.new(width: 600, height: 300)
             |> Vl.data_from_series(data)
             |> Vl.mark(:point)
             |> Vl.encode_field(:x, "a", type: :ordinal)
             |> Vl.encode_field(:y, "b", type: :quantitative)
             |> Vl.encode_field(:color, "c", type: :nominal)\
             """
    end

    test "area plot with aggregate and alias" do
      attrs =
        Map.merge(@defaults, %{
          "chart_type" => "point",
          "width" => 600,
          "height" => 300,
          "x_field_type" => "ordinal",
          "y_field_aggregate" => "mean",
          "color_field" => "c",
          "color_field_type" => "nominal",
          "vl_alias" => Vl
        })
        |> ChartBuilder.add_layer()

      assert ChartBuilder.to_source(attrs) == """
             Vl.new(width: 600, height: 300)
             |> Vl.data_from_series(data)
             |> Vl.mark(:point)
             |> Vl.encode_field(:x, "a", type: :ordinal)
             |> Vl.encode_field(:y, "b", aggregate: :mean)
             |> Vl.encode_field(:color, "c", type: :nominal)\
             """
    end

    test "simple plot with title" do
      attrs =
        Map.merge(@defaults, %{"chart_type" => "point", "chart_title" => "Chart Title"})
        |> ChartBuilder.add_layer()

      assert ChartBuilder.to_source(attrs) == """
             VegaLite.new(title: "Chart Title")
             |> VegaLite.data_from_series(data)
             |> VegaLite.mark(:point)
             |> VegaLite.encode_field(:x, "a")
             |> VegaLite.encode_field(:y, "b")\
             """
    end

    test "simple plot with aggregate count" do
      attrs = Map.merge(@defaults, %{"y_field" => "__count__"}) |> ChartBuilder.add_layer()

      assert ChartBuilder.to_source(attrs) == """
             VegaLite.new()
             |> VegaLite.data_from_series(data)
             |> VegaLite.mark(:bar)
             |> VegaLite.encode_field(:x, "a")
             |> VegaLite.encode(:y, aggregate: :count)\
             """
    end
  end
end