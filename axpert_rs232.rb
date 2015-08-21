##
# Used to simplify dealing with the Axpert Inverter protocol
#
# This allows the user to create a command using human readable ASCII
# and get an immutable object representing the command along with hex
#
# Additionally hex can be parsed to create the same type of immutable object
# with a parsed human readable command 
class AxpertRS232
  ##
  # Parse an input Axpert Inverter command from a human readable ASCII command
  def self.from_ascii(command)
    result = method(:new).call(command)
    test = result.hex.scan(/../).map { |x| x.hex }.pack('c*')[0..-3]
    raise "Internal check failed, the CRC calculation code has a bug!" unless (result.command == test)
    result
  end

  ##
  # Parse an input Axpert Inverter command from the hex command sent over the wire
  def self.from_hex(hex)
    hex = hex.to_s.upcase
    result = method(:new).call(hex.scan(/../).map { |x| x.hex }.pack('c*')[0..-3])
    raise unless (hex == result.hex)
    result
  rescue StandardError
    raise ArgumentError.new("The input hex #{hex} does not appear to be valid")
  end

  ##
  # The human readable command to be sent to the Inverter
  attr_reader :command

  ##
  # The actual hex that will be sent to the device
  attr_reader :hex

  def initialize(command) #:nodoc:
    command = command.to_s.strip.chomp.upcase
    test = command.encode(Encoding.find('ASCII'), {invalid: :replace, undef: :replace, replace: '_', universal_newline: true})
    raise ArgumentError.new("Invalid input in '#{command}'") unless (command == test.to_s)
    @command = command.dup.freeze
    bytes = test.bytes.to_a
    crc = calculate_crc(bytes)
    @hex = (bytes + [crc, CR]).map { |i| i.to_s(16).upcase }.join.freeze
    self.freeze
  end

  def to_s #:nodoc:
    "#{self.class.name.to_s.split('::').last}('#{command}', '#{hex}')"
  end

  def inspect #:nodoc:
    to_s
  end

  private

  # CRC calculation source: http://forums.aeva.asn.au/pip4048ms-inverter_topic4332_post53760.html#53760
  def calculate_crc(pin) #:nodoc:
    crc, da = 0, 0
    for index in 0..(pin.length-1)
      da = byte(byte(crc >> 8) >> 4)
      crc = short(short(crc << 4) ^ CRC_TABLE[byte(da ^ byte(pin[index] >> 4))])
      da = byte(byte(crc >> 8) >> 4)
      crc = short(short(crc << 4) ^ CRC_TABLE[byte(da ^ byte(pin[index] & 0x0f))])
    end

    crc_low, crc_high = byte(crc & 0x00FF), byte(crc >> 8)
    crc_low = short(crc_low + 1) if CRC_MOD.include?(crc_low)
    crc_high = short(crc_high + 1) if CRC_MOD.include?(crc_high)
    short(short(crc_high << 8) | crc_low)
  end

  def byte(input) #:nodoc:
    (input & 255)
  end

  def short(input) #:nodoc:
    (input & 65535)
  end

  CRC_TABLE = [0x0000, 0x1021, 0x2042, 0x3063, 0x4084, 0x50a5, 0x60c6, 0x70e7,
               0x8108, 0x9129, 0xa14a, 0xb16b, 0xc18c, 0xd1ad, 0xe1ce, 0xf1ef].freeze #:nodoc:
  CRC_MOD = [0x28, 0x0d, 0x0a].freeze #:nodoc:
  CR = 0x0D.freeze #:nodoc:

  private_class_method :new #:nodoc:
end
