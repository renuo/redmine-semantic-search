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

  def self.pca_like_reduction(vector, target_dimension)
    return vector.first(target_dimension) if vector.length <= target_dimension

    top_indices = _select_top_indices(vector, target_dimension)
    uniform_indices = _select_uniform_indices(vector, target_dimension, top_indices)
    combined_indices = top_indices + uniform_indices
    filled_indices = _fill_remaining_indices(vector, target_dimension, combined_indices)

    selected_indices = (top_indices + uniform_indices + filled_indices).sort.uniq

    selected_indices.first(target_dimension).map { |index| vector[index] }
  end

  def self._select_top_indices(vector, target_dimension)
    importance = vector.map(&:abs)
    top_dimensions_count = [target_dimension / 5, 1].max
    importance.each_with_index
              .sort_by { |val, _| -val }
              .first(top_dimensions_count)
              .map { |_, idx| idx }
  end

  def self._select_uniform_indices(vector, target_dimension, top_indices)
    remaining_count = target_dimension - top_indices.length
    return [] if remaining_count <= 0

    step_size = vector.length.to_f / remaining_count
    uniform_indices = (0...remaining_count).map { |i| (i * step_size).to_i }
    uniform_indices.reject { |idx| top_indices.include?(idx) }
  end

  def self._fill_remaining_indices(vector, target_dimension, existing_indices)
    filled_indices = []
    current_idx = 0
    needed_count = target_dimension - existing_indices.length

    while filled_indices.length < needed_count && current_idx < vector.length
      unless existing_indices.include?(current_idx) || filled_indices.include?(current_idx)
        filled_indices << current_idx
      end
      current_idx += 1
    end
    filled_indices
  end
end
