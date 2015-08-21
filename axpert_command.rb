class AxpertCommand
  require 'axpert_rs232'

  def initialize(command, valid_values = nil, &blk)
    raise ArgumentError.new("Expected in input block to deal with command result") unless block_given?
    @command = command.to_s.strip.chomp.upcase.freeze
    valid_values = [*valid_values].compact
    @valid_values = valid_values unless valid_values.empty?
    @result_parser = blk
  end

  def command(arg = nil)
    cmd = @command.to_s.dup
    if @valid_values.nil?
      raise ArgumentError.new("wrong number of arguments (1 for 0)") unless arg.nil?
    else
      raise ArgumentError.new("wrong number of arguments (0 for 1)") if arg.nil?
      raise ArgumentError.new("'#{arg}' is not accepted input (valid input: #{valid_values.inspect})") unless valid_values.include?(arg)
      cmd = cmd % {input: arg.to_s}
    end

    ::AxpertRS232.from_ascii(cmd)
  end

  def parse_result(result)
    @result_parser.yield(::AxpertRS232.from_hex(result))
  rescue StandardError, ScriptError => err
    err = "#{err.class.name.to_s} thrown; #{err.message.to_s}"
    raise "Could not parse the result (#{err})"
  end

  def to_s
    "#{self.class.name.to_s.split('::').last}('#{@command}')"
  end
end