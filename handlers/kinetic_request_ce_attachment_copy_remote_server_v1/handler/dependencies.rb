# If the Kinetic Task version is under 4, NOT Supported
if KineticTask::VERSION.split(".").first.to_i < 4
  raise StandarError.new "This handler requires Task v4 or greater"
end


# Load the ruby Mime Types library unless it has already been loaded.  This prevents
# multiple handlers using the same library from causing problems.
if not defined?(MIME)
  # Calculate the location of this file
  handler_path = File.expand_path(File.dirname(__FILE__))
  # Calculate the location of our library and add it to the Ruby load path
  library_path = File.join(handler_path, 'vendor/mime-types-1.19/lib/')
  $:.unshift library_path
  # Require the library
  require 'mime/types'
end

# Validate the the loaded Mime Types library is the library that is expected for
# this handler to execute properly.
if not defined?(MIME::Types::VERSION)
  raise "The Mime class does not define the expected VERSION constant."
elsif MIME::Types::VERSION != '1.19'
  raise "Incompatible library version #{MIME::Types::VERSION} for Mime Types.  Expecting version 1.19."
end
