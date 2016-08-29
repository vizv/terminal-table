require 'unicode/display_width'
require 'pp'

module Terminal
  class Table

    attr_reader :title
    attr_reader :headings

    ##
    # Generates a ASCII table with the given _options_.

    def initialize options = {}, &block
      @headings = []
      @rows = []
      @column_widths = []
      self.style = options.fetch :style, {}
      self.headings = options.fetch :headings, []
      self.rows = options.fetch :rows, []
      self.title = options.fetch :title, nil
      yield_or_eval(&block) if block
    end

    ##
    # Align column _n_ to the given _alignment_ of :center, :left, or :right.

    def align_column n, alignment
      r = rows
      column(n).each_with_index do |col, i|
        cell = r[i][n]
        cell.alignment = alignment unless cell.alignment?
      end
    end

    ##
    # Add a row.

    def add_row array
      row = array == :separator ? Separator.new(self) : Row.new(self, array)
      @rows << row
      STDERR.puts "\nDBG: add row - #{array.pretty_inspect}"
      recalc_column_widths row end
    alias :<< :add_row

    ##
    # Add a separator.

    def add_separator
      self << :separator
    end

    def cell_spacing
      cell_padding + style.border_y.length
    end

    def cell_padding
      style.padding_left + style.padding_right
    end

    ##
    # Return column _n_.

    def column n, method = :value, array = rows
      array.map { |row|
        # for each cells in a row, find the column with index
        # just greater than the required one, and go back one.
        index = col = 0
        row.cells.each do |cell|
          break if index > n
          index += cell.colspan
          col += 1
        end
        cell = row[col - 1]
        cell && method ? cell.__send__(method) : cell
      }.compact
    end

    ##
    # Return _n_ column including headings.

    def column_with_headings n, method = :value
      column n, method, headings_with_rows
    end

    ##
    # Return columns.

    def columns
      (0...number_of_columns).map { |n| column n }
    end

    ##
    # Return length of column _n_.

    def column_width n
      width = @column_widths[n] || 0
      width + additional_column_widths[n].to_i
    end
    alias length_of_column column_width # for legacy support

    ##
    # Return total number of columns available.

    def number_of_columns
      headings_with_rows.map { |r| r.number_of_columns }.max || 0
    end

    ##
    # Set the headings

    def headings= arrays
      arrays = [arrays] unless arrays.first.is_a?(Array)
      @headings = arrays.map do |array|
        row = Row.new(self, array)
        # STDERR.puts "\nDBG: set headings - #{array.pretty_inspect}"
        recalc_column_widths row
        row
      end
    end

    ##
    # Render the table.

    def render
      separator = Separator.new(self)
      buffer = [separator]
      unless @title.nil?
        buffer << Row.new(self, [title_cell_options])
        buffer << separator
      end
      @headings.each do |row|
        unless row.cells.empty?
          buffer << row
          buffer << separator
        end
      end
      if style.all_separators
        buffer += @rows.product([separator]).flatten
      else
        buffer += @rows
        buffer << separator
      end
      buffer.map { |r| style.margin_left + r.render.rstrip }.join("\n")
    end
    alias :to_s :render

    ##
    # Return rows without separator rows.

    def rows
      @rows.reject { |row| row.is_a? Separator }
    end

    def rows= array
      @rows = []
      array.each { |arr| self << arr }
    end

    def style=(options)
      style.apply options
    end

    def style
      @style ||= Style.new
    end

    def title=(title)
      @title = title
      # STDERR.puts "\nDBG: set title - #{title}"
      recalc_column_widths Row.new(self, [title_cell_options])
    end

    ##
    # Check if _other_ is equal to self. _other_ is considered equal
    # if it contains the same headings and rows.

    def == other
      if other.respond_to? :render and other.respond_to? :rows
        self.headings == other.headings and self.rows == other.rows
      end
    end

    private

    def columns_width
      @column_widths.inject(0) { |s, i| s + i + cell_spacing } + style.border_y.length
    end

    def additional_column_widths
      return [] if style.width.nil?
      spacing = style.width - columns_width
      if spacing < 0
        raise "Table width exceeds wanted width of #{style.width} characters."
      else
        per_col = spacing / number_of_columns
        arr = (1...number_of_columns).to_a.map { |i| per_col }
        other_cols = arr.inject(0) { |s, i| s + i }
        arr << spacing - other_cols
        arr
      end
    end

    def recalc_column_widths row
      return if row.is_a? Separator

      # prepare rows
      all_rows = headings_with_rows
      all_rows += Row.new(self, [title_cell_options]) unless @title.nil?

      # DP states, dp[colspan][index][split_offset] => column_width.
      dp = []

      # prepare initial value for DP.
      all_rows.each do |row|
        index = 0
        row.cells.each do |cell|
          cell_value = cell.value_for_column_width_recalc
          cell_width = Unicode::DisplayWidth.of(cell_value.to_s)
          colspan = cell.colspan

          # find column width from each single cell.
          dp[colspan] ||= []
          dp[colspan][index] ||= [0]        # add a fake cell with length 0.
          dp[colspan][index][colspan] ||= 0 # initialize column length to 0.

          # the last index `colspan` means width of the single column (split
          # at end of each column), not a width made up of multiple columns.
          single_column_length = [cell_width, dp[colspan][index][colspan]].max
          dp[colspan][index][colspan] = single_column_length

          index += colspan
        end
      end

      # run DP.
      n_cols = number_of_columns
      return if n_cols == 0
      STDERR.puts "DBG: n_cols = #{n_cols}"
      space_width = cell_spacing
      (1..n_cols).each do |colspan|
        dp[colspan] ||= []
        (0..n_cols-colspan).each do |index|
          dp[colspan][index] ||= [0]
          (1...colspan).each do |offset|
            # processed level became reverse map from width => [offset, ...].
            left_colspan = offset
            left_index = index
            left_width = dp[left_colspan][left_index].keys.first

            right_colspan = colspan - left_colspan
            right_index = index + offset
            right_width = dp[right_colspan][right_index].keys.first

            dp[colspan][index][offset] = left_width + right_width + space_width
          end

          # reverse map it for resolution (max width and short offset first).
          rmap = {}
          dp[colspan][index].each_with_index do |width, offset|
            rmap[width] ||= []
            rmap[width] << offset
          end

          # sort reversely and store it back.
          dp[colspan][index] = rmap.sort.reverse.to_h

          # FIXME: puts "colspan: #{colspan}, index: #{index}"
          # FIXME: puts dp[colspan][index]
        end
      end

      resolve = -> (colspan, index = 0, additional_width = 0) do
        # STDERR.puts "DBG resolve: #{colspan}, #{index}"
        current = dp[colspan][index]
        full_width = current.keys.first + additional_width

        # stop if reaches the bottom level.
        STDERR.puts "DBG result: #{index}: #{full_width}" if colspan == 1
        return @column_widths[index] = full_width if colspan == 1

        # choose best split offset for partition, or second best result
        # if first one is not dividable.
        candidate_offsets = current.collect(&:last).flatten
        offset = candidate_offsets[0]
        offset = candidate_offsets[1] if offset == colspan

        # prepare for next round.
        left_colspan = offset
        left_index = index
        left_width = dp[left_colspan][left_index].keys.first

        right_colspan = colspan - left_colspan
        right_index = index + offset
        right_width = dp[right_colspan][right_index].keys.first

        # distribute remainder.
        remainder = full_width - left_width - right_width - space_width
        left_additional_width = right_additional_width = remainder / 2
        remainder %= 2

        if left_width < right_width
          left_additional_width += remainder
        else
          right_additional_width += remainder
        end

        # run next round.
        resolve.call(left_colspan, left_index, left_additional_width)
        resolve.call(right_colspan, right_index, right_additional_width)
      end

      resolve.call(n_cols)
    end

    ##
    # Return headings combined with rows.

    def headings_with_rows
      @headings + rows
    end

    def yield_or_eval &block
      return unless block
      if block.arity > 0
        yield self
      else
        self.instance_eval(&block)
      end
    end

    def title_cell_options
      {:value => @title, :alignment => :center, :colspan => number_of_columns}
    end
  end
end
