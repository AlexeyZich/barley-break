require 'pry-byebug'

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
    attr_reader :min_steps, :ways_levels, :current_step, :output, :current_step_way

    def initialize
      @configuration = FV.configuration
      # @prev_step_way = nil
      @current_step_way = FV::Way.new(matrix: @configuration.input, selected: 1)
      @output = @configuration.output
      @ways_levels = []
      # @selected_ways_fs = []
      @current_step = 0
      @current_level_index = 0
    end

    def process_the_first_way_level
      way_level = FV::WayLevel.new
      way_level.h = -1
      way_level.ways = [@current_step_way]
      way_level.setup_h_for_ways
      way_level.setup_g_for_ways
      @ways_levels << way_level
    end

    def step
      @current_step += 1
      
      # available_ws = @ways_levels.map {|wl| wl.ways }.flatten.reject { |w| w.closed == true }
      # available_ws2 = available_ws.find_all { |w| w.h == available_ws.map { |w| w.h }.max } + [@ways_levels.first.ways.first]
      # way = available_ws2.max_by { |w| w.f }
      way = @ways_levels[@current_level_index].find_next_selected_way
      # puts "GET: #{way.matrix.inspect}"

      previous_selected_way = @ways_levels[@current_level_index-1].selected_way
      # binding.pry if previous_selected_way.nil?
      if previous_selected_way && previous_selected_way.f < way.f
        puts "RETURN FROM: #{way.matrix.inspect}"

        selected_ways = @ways_levels.map { |l| l.ways.map { |w| (w.selected ? w.f : nil) }.reject(&:nil?) } 
        all_fs = @ways_levels.map { |l| l.ways.map { |w| w.f } }
        available_fs = all_fs.flatten.uniq - selected_ways.flatten.uniq

        available_ways = @ways_levels.map {|wl| wl.ways }.flatten.find_all { |w| w.f == available_fs.min }

        @ways_levels.map {|wl| wl.ways }.flatten.find_all { |w| w.f == available_fs.min }

        @ways_levels.map {|wl| wl.ways }.flatten.each do |w|
          if (w.f != available_fs.min)
            w.closed = true
            # puts "w.h: #{w.h}; #{w.matrix.inspect}"
          else
            w.closed = false
          end
        end

        way = available_ways.max_by { |w| w.h }

        puts "SELECTED WAY: #{way.matrix.inspect}"
        way.selected = @current_step
        way_level, way_level_index = perform_branch(way)
        @current_level_index = way_level_index
      else
        way.selected = @current_step
        way_level, way_level_index = perform_branch(way)
        @current_level_index = way_level_index
      end
    end

    def call
      process_the_first_way_level

      perform_branch(@current_step_way)


      while (@ways_levels[@current_level_index].find_next_selected_way.matrix != @output)
        puts "step: #{@current_step}"
        step
      end
      binding.pry
      @min_steps = @current_step # <- result
    end

    def perform_branch(way)
      wl_existing = @ways_levels.find { |wl| wl.h == way.h + 1 }
      if wl_existing
        way_level = wl_existing
        way_level.ways = way_level.ways + way.possible_ways(calculation: self)
        way_level.setup_h_for_ways
        way_level.setup_g_for_ways
      else
        way_level = FV::WayLevel.new
        way_level.h = way.h + 1
        way_level.ways = way.possible_ways(calculation: self)
        way_level.setup_h_for_ways
        way_level.setup_g_for_ways
        @ways_levels << way_level
      end
      [way_level, @ways_levels.index(way_level)]
      # @prev_step_way = @current_step_way
      # @current_step_way = nil
    end

    # def mark_level_as_closed(level_index)
    #   @ways_levels[level_index]
    # end
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

    def setup_g_for_ways
      ways.each { |w| w.setup_g }
    end

    def selected_way
      ways.find_all { |w| !w.selected.nil? }.max_by { |w| w.selected }
    end

    def find_next_selected_way
      ways.reject { |w| w.closed == true }.min_by { |w| w.f }
    end
  end

  class Way
    attr_reader :matrix
    attr_accessor :g, :h, :selected, :closed

    def initialize(matrix:, g: nil, h: nil, selected: nil)
      @matrix = matrix
      @g = g
      @h = h
      @selected = selected
      @closed = false
    end

    def cursor
      matrix = @matrix
      row_with_value_index = matrix.index { |i| i.detect { |j| j == 0 } }
      raise FV::Error, "No row with zero value in matrix=#{matrix.inspect}" if row_with_value_index.nil?
      col_with_value_index = matrix.detect { |i| i.detect { |j| j == 0 } }.index { |el| el == 0 }
      [row_with_value_index, col_with_value_index]
    end

    def setup_g
      output_matrix = FV.configuration.output
      self.g = 0
      matrix.each_with_index do |row, i|
        row.each_with_index do |el, j|
          self.g += 1 if el != output_matrix[i][j] && el != 0
        end
      end
    end

    def f
      configuration = FV.configuration
      (g * configuration.kg) + (h * configuration.kh)
    end

    def possible_ways(calculation:)
      i, j = cursor
      # max_i = matrix.count - 1
      # max_j = matrix[0].count - 1

      swap_with_cursor = []

      next_row = i + 1
      prev_row = i - 1

      next_col = j + 1
      prev_col = j - 1

      prev_prev_way = calculation.ways_levels.last(2).first.selected_way
      check_i, check_j = prev_prev_way.cursor

      if matrix[next_row]
        check = true
        check = false if (check_i == next_row) && (check_j == j)
        swap_with_cursor << [next_row, j] if check
      end
      if matrix[prev_row]
        check = true
        check = false if (check_i == prev_row) && (check_j == j)
        swap_with_cursor << [prev_row, j] if check
      end
      if matrix[i][next_col]
        check = true
        check = false if (check_i == i) && (check_j == next_col)
        swap_with_cursor << [i, next_col] if check
      end
      if matrix[i][prev_col]
        check = true
        check = false if (check_i == i) && (check_j == prev_col)
        swap_with_cursor << [i, prev_col] if check
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
