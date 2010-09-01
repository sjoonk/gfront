module PageHelper

  # Layout

  def has_footer
    @footer ||= @page.footer
    !@footer.nil?
  end

  def footer_content
    @footer ||= @page.footer
    @footer.formatted_data
  end

  def footer_format
    @footer ||= @page.footer
    @footer.format.to_s
  end

  # Page

  def author
    @page.version.author.name
  end

  def date
    @page.version.authored_date.strftime("%Y-%m-%d %H:%M:%S")
  end
  
  def formats(selected = @page.format)
    Gollum::Page::FORMAT_NAMES.map do |key, val|
      { :name     => val,
        :id       => key.to_s,
        :selected => selected == key}
    end.sort do |a, b|
      a[:name].downcase <=> b[:name].downcase
    end
  end

  def page_name
    @name.gsub('-', ' ')
  end


  # Version History

  def versions
    i = @versions.size + 1
    @versions.map do |v|
      i -= 1
      { :id       => v.id,
        :id7      => v.id[0..6],
        :num      => i,
        :selected => @page.version.id == v.id,
        :author   => v.author.name,
        :message  => v.message,
        :date     => v.committed_date.strftime("%B %d, %Y"),
        :gravatar => (v.author.email ? Digest::MD5.hexdigest(v.author.email) : '') }
    end
  end

  def previous_link
    label = "&laquo; Previous"
    if @page_num == 1
      %(<span class="disabled">#{label}</span>)
    else
      %(<a href="/history/#{@page.name}?page=#{@page_num-1}" hotkey="h">#{label}</a>)
    end
  end

  def next_link
    label = "Next &raquo;"
    if @versions.size == Gollum::Page.per_page
      %(<a href="/history/#{@page.name}?page=#{@page_num+1}" hotkey="l">#{label}</a>)
    else
      %(<span class="disabled">#{label}</span>)
    end
  end

  def before
    @versions[0][0..6]
  end

  def after
    @versions[1][0..6]
  end

  def lines
    lines = []
    @diff.diff.split("\n")[2..-1].each_with_index do |line, line_index|
      lines << { :line => line,
                 :class => line_class(line),
                 :ldln => left_diff_line_number(0, line),
                 :rdln => right_diff_line_number(0, line) }
    end
    lines
  end

  # private

  def line_class(line)
    if line =~ /^@@/
      'gc'
    elsif line =~ /^\+/
      'gi'
    elsif line =~ /^\-/
      'gd'
    else
      ''
    end
  end

  @left_diff_line_number = nil
  def left_diff_line_number(id, line)
    if line =~ /^@@/
      m, li = *line.match(/\-(\d+)/)
      @left_diff_line_number = li.to_i
      @current_line_number = @left_diff_line_number
      ret = '...'
    elsif line[0] == ?-
      ret = @left_diff_line_number.to_s
      @left_diff_line_number += 1
      @current_line_number = @left_diff_line_number - 1
    elsif line[0] == ?+
      ret = ' '
    else
      ret = @left_diff_line_number.to_s
      @left_diff_line_number += 1
      @current_line_number = @left_diff_line_number - 1
    end
    ret
  end

  @right_diff_line_number = nil
  def right_diff_line_number(id, line)
    if line =~ /^@@/
      m, ri = *line.match(/\+(\d+)/)
      @right_diff_line_number = ri.to_i
      @current_line_number = @right_diff_line_number
      ret = '...'
    elsif line[0] == ?-
      ret = ' '
    elsif line[0] == ?+
      ret = @right_diff_line_number.to_s
      @right_diff_line_number += 1
      @current_line_number = @right_diff_line_number - 1
    else
      ret = @right_diff_line_number.to_s
      @right_diff_line_number += 1
      @current_line_number = @right_diff_line_number - 1
    end
    ret
  end

end