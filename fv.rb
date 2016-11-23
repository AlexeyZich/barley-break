module FV
  class << self
    attr_accessor :configuration
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration)
  end

  class Configuration
    attr_accessor :input, :output, :kg, :kh
  end

  class Calculation
    attr_reader :min_steps

    def initialize
      @configuration = FV.configuration
      @prev_step_way = nil
      @current_step_way = FV::Way.new(matrix: @configuration.input, selected: true)
      @output = @configuration.output
      @ways_stack = []
    end

    def call
      way_level = FV::WayLevel.new
      way_level.h = -1
      way_level.ways = [@current_step_way]
      way_level.setup_h_for_ways
      @ways_stack << way_level

      perform_branch(@current_step_way)
      puts @ways_stack.inspect
      @min_steps = 0 # <- result
    end

    def current_step
      result = 0
      @ways_stack.each do |way_level|
        way_level.ways.each do |way|
          result += 1 if way.selected
        end
      end
      result
    end

    def perform_branch(way)
      way_level = FV::WayLevel.new
      way_level.h = @ways_stack.last.h + 1
      way_level.ways = way.possible_ways
      way_level.setup_h_for_ways
      @ways_stack << way_level
      @prev_step_way = @current_step_way
      @current_step_way = nil
    end
  end

  class WayLevel
    attr_accessor :h, :ways
    
    def initialize
      @h = 0
      @ways = []
    end

    def setup_h_for_ways
      ways.each { |w| w.h = @h }
    end
  end

  class Way
    attr_reader :matrix
    attr_accessor :g, :h, :selected

    def initialize(matrix:, g: nil, h: nil, selected: false)
      @matrix = matrix
      @g = g
      @h = h
      @selected = selected
    end

    def cursor
      matrix = @matrix
      row_with_value_index = matrix.index { |i| i.detect { |j| j == 0 } }
      raise FV::Error, "No row with zero value in matrix=#{matrix.inspect}" if row_with_value_index.nil?
      col_with_value_index = matrix.detect { |i| i.detect { |j| j == 0 } }.index { |el| el == 0 }
      [row_with_value_index, col_with_value_index]
    end

    def possible_ways
      i, j = cursor
      # max_i = matrix.count - 1
      # max_j = matrix[0].count - 1

      swap_with_cursor = []

      next_row = i + 1
      prev_row = i - 1

      next_col = j + 1
      prev_col = j - 1
      if matrix[next_row]
        swap_with_cursor << [next_row, j]
      end
      if matrix[prev_row]
        swap_with_cursor << [prev_row, j]
      end
      if matrix[i][next_col]
        swap_with_cursor << [i, next_col]
      end
      if matrix[i][prev_col]
        swap_with_cursor << [i, prev_col]
      end

      result = []
      swap_with_cursor.each do |ii, jj|
        new_matrix = Marshal.load(Marshal.dump(matrix))
        new_matrix[i][j] = matrix[ii][jj]
        new_matrix[ii][jj] = 0
        result << FV::Way.new(matrix: new_matrix)
      end
      result
    end
  end

  class Error < StandardError
  end
end
