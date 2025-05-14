require File.expand_path('../../test_helper', __FILE__)

class DimensionReductionServiceTest < ActiveSupport::TestCase
  def test_reduce_dimensions
    vector = Array.new(3000) { rand }
    source_dimension = 5500
    target_dimension = 2000

    padded_vector = DimensionReductionService.pad_vector(vector, source_dimension)
    assert_equal source_dimension, padded_vector.length

    reduced_vector = DimensionReductionService.reduce_dimensions(padded_vector, source_dimension, target_dimension)
    assert_equal target_dimension, reduced_vector.length
  end

  def test_pca_like_reduction
    vector_size = 5500
    test_vector = Array.new(vector_size, 0.1)
    important_positions = [10, 100, 1000, 2000, 3000, 4000, 5000]
    important_positions.each do |pos|
      test_vector[pos] = 0.9
    end

    target_dimension = 20
    reduced_vector = DimensionReductionService.send(:pca_like_reduction, test_vector, target_dimension)

    assert_equal target_dimension, reduced_vector.length

    top_dimensions_count = [target_dimension / 5, 1].max

    preserved_important = reduced_vector.count { |val| val.abs > 0.8 }

    assert preserved_important > 0, "Should preserve at least one important dimension"
  end

  def test_pad_vector
    vector = Array.new(100) { 0.5 }
    target_size = 200

    padded_vector = DimensionReductionService.pad_vector(vector, target_size)
    assert_equal target_size, padded_vector.length

    vector.each_with_index do |val, i|
      assert_equal val, padded_vector[i]
    end

    (vector.length...target_size).each do |i|
      assert_equal 0.0, padded_vector[i]
    end
  end

  def test_pad_vector_no_padding_needed
    vector = Array.new(100) { 0.5 }

    padded_vector = DimensionReductionService.pad_vector(vector, 100)
    assert_equal vector, padded_vector

    padded_vector = DimensionReductionService.pad_vector(vector, 50)
    assert_equal vector, padded_vector
  end
end
