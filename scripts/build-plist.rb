require 'rubygems'
require 'bundler/setup'

require 'plist'
require 'pp'
require 'base64'

$LOAD_PATH << File.dirname(__FILE__)
require 'hidutil'

def fix_descriptor(broken_descriptor)
  parsed_descriptor = (HIDInfo.parse(StringIO.new broken_descriptor))
  if HIDInfo.encode(HIDInfo.items_to_tag_stream(parsed_descriptor)) != broken_descriptor
    raise "HIDInfo unable to encode descriptor without loss"
  end
  HIDInfo.encode(HIDInfo.items_to_tag_stream(HIDInfo.fix(parsed_descriptor)))
end

class PlistData
  def initialize(contents)
    @contents = contents
  end
  def to_plist_node
    "<data>#{Base64.encode64(@contents)}</data>"
  end
end

info = Plist::parse_xml('Info.plist.in')
Dir['descriptors/*.yaml'].each do |f|
  descriptors = YAML.load_file f
  descriptors.each_with_index do |descriptor, index|
    broken_descriptor = descriptor.delete 'hidReportDescriptor'
    descriptor.merge!({
      'IOClass' => 'IOUSBHIDDriverDescriptorOverride',
      'IOProviderClass' => 'IOUSBInterface',
      'CFBundleIdentifier' => 'ryangoulden.driver.${PRODUCT_NAME:rfc1034Identifier}',
      'ReportDescriptorOverride' => PlistData.new(fix_descriptor(broken_descriptor))
    })
    info['IOKitPersonalities']["#{File.basename(f)}-#{index}"] = descriptor
  end
end
Plist::Emit.save_plist(info, 'Info.plist')
