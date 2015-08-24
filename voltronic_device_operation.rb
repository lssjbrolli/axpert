##
# A convenient immutable object to encapsulate the logic
# of a Voltronic Device operation consisting of:
# Command, parameter validation and result parser
#
# @author: Johan van der Vyver
class VoltronicDeviceOperation
  require 'voltronic_rs232'
  require 'time'

  def initialize(input, &blk)
    input = {}.merge(input) rescue (raise ::ArgumentError.new("Expected an input hash")) 

    @command = begin
      as_lambda(input.fetch(:command))
    rescue ::StandardError => err
      err = "#{err.class.name.to_s} thrown; #{err.message.to_s}"
      raise ::ArgumentError.new("Expected :command to be a String with a device command or Proc (#{err})")
    end

    @error_on_nak = (true == input.fetch(:error_on_nak, true))

    @parser = begin
      as_lambda(input.fetch(:parser))
    rescue ::StandardError => err
      err = "#{err.class.name.to_s} thrown; #{err.message.to_s}"
      raise ::ArgumentError.new("Expected :parser to be a Proc or Lambda (#{err})")
    end

    @read_timeout = Integer(input.fetch(:serial_read_timeout_seconds, 2))
    @write_timeout = Integer(input.fetch(:serial_write_timeout_seconds, 2))

    @termination_character = begin
      parse = input.fetch(:serial_termination_character, "\r").to_s
      raise ::ArgumentError.new("Expected :serial_termination_character to be a single character") unless (parse.length == 1)
      parse.freeze
    end

    freeze
  end

  ##
  # Issue a command to the device and parse the output result
  def issue_command(serial, *args)
    serial.read_timeout = -1 # Prevent locking on serial
    serial.write_timeout = (@write_timeout * 1000) # Set timeout to specified seconds

    serial.write(command(*args).bytes)
    result = begin
      parse = ''
      read_timeout = ::Time.now.to_i + @read_timeout # 2 seconds
      while(true)
        ch = serial.getc # Retrieve a single character from Serial port
        if ch.nil?
          sleep 0.1 # 100ms pause before polling again
          next
        end
        parse += ch
        break if (@termination_character == ch)
        raise ::IOError.new("IO read timeout reached, giving up") if (Time.now.to_i > timeout)
      end
      parse
    end

    parse_result(serial)
  end

  ##
  # Create an VoltronicRS232 object containing a command
  # and optional parameter to execute on the device
  def command(*args)
    RS232_PROTO.new(@command.yield(*args))
  end

  ##
  # Parse the command output returned from the Voltronic device
  def parse_result(result)
    result = RS232_PROTO.new(result)
    raise NAKReceivedError.new("Received NAK from device") if (@error_on_nak && ('NAK' == result.data.upcase))
    @parser.yield(result)
  rescue ::StandardError, ::ScriptError => err
    err = "#{err.class.name.to_s} thrown; #{err.message.to_s}"
    raise "Could not parse the result (#{err})"
  end

  def to_s # :nodoc:
    "#{self.class.name.to_s.split('::').last}"
  end

  def inspect # :nodoc:
    self.to_s
  end

  private

  def as_lambda(input)
    input = lambda { input.to_s.chomp.freeze } unless input.is_a?(Proc)
    result = Object.new
    result.define_singleton_method(:_, &input)
    result.method(:_).to_proc.freeze
  end

  RS232_PROTO = ::VoltronicRS232 # :nodoc
  class NAKReceivedError < ::RuntimeError; end # :nodoc:
end
