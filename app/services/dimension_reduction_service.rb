class DimensionReductionService
  def self.reduce_dimensions(vector, source_dimension, target_dimension)
    padded_vector = pad_vector(vector, source_dimension)

    pca_like_reduction(padded_vector, target_dimension)
  end

  def self.pad_vector(vector, target_size)
    return vector if vector.nil? || vector.length >= target_size

    vector + Array.new(target_size - vector.length, 0.0)
  end

  def self.validate_vector_dimension(vector, target_dimension)
    return nil if vector.nil?

    if vector.length > target_dimension
      vector.first(target_dimension)
    elsif vector.length < target_dimension
      pad_vector(vector, target_dimension)
    else
      vector
    end
  end

  private

  def self.pca_like_reduction(vector, target_dimension)
    return vector.first(target_dimension) if vector.length <= target_dimension

    importance = vector.map(&:abs)

    top_dimensions_count = [target_dimension / 5, 1].max
    top_indices = importance.each_with_index
                            .sort_by { |val, _| -val }
                            .first(top_dimensions_count)
                            .map { |_, idx| idx }

    remaining_count = target_dimension - top_indices.length
    step_size = vector.length.to_f / remaining_count
    uniform_indices = (0...remaining_count).map { |i| (i * step_size).to_i }

    uniform_indices = uniform_indices.reject { |idx| top_indices.include?(idx) }

    while (top_indices.length + uniform_indices.length) < target_dimension
      idx = 0
      while top_indices.include?(idx) || uniform_indices.include?(idx)
        idx += 1
      end
      uniform_indices << idx
    end

    selected_indices = (top_indices + uniform_indices).sort

    selected_indices.first(target_dimension).map { |idx| vector[idx] }
  end
end
