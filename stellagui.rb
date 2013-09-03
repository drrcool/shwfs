#!/usr/bin/ruby

require 'libglade2'

# As of Fedora 17 (8/2012) we need to install the "soap4r" ruby gem
# gem install soap4r-ruby1.9 

# As of Ruby 1.9 this package spits out:
# iconv will be deprecated in the future, use String#encode instead.
# so we suppress this warning while we wait for an upstream fix.
save_verbose=$VERBOSE; $VERBOSE=nil
require 'soap/rpc/driver'
$VERBOSE=save_verbose

# set a global path to find scripts and stuff
if ENV['WFSROOT']
  $path = ENV['WFSROOT']
else
  $path = "/mmt/shwfs"
end

class Stella_GUI

  def initialize
    @glade = GladeXML.new("#{$path}/glade/stellacam.glade") {|handler| method(handler)}
    @status = @glade.get_widget("Status")
    report("Can't connect to StellaCam.")

    @stella = SOAP::RPC::Driver.new('http://f9wfs:5555/', 'urn:Stella')
    @stella.add_method("get_version")
    @stella.add_method("status")
    @stella.add_method("state")
    @stella.add_method("gain", "g")
    @stella.add_method("frame", "f")
    @stella.add_method("gamma", "g")
    @stella.add_method("iris", "i")
    @stella.add_method("configure")
    @retry = false

    @videorate = @glade.get_widget("ExposureMenu")
    @videorate.active = 0
    @gain = @glade.get_widget("Gain")
    @config = @glade.get_widget("Config")
    @ping = @glade.get_widget("Ping")
    @grab = @glade.get_widget("Grab")

    state = @stella.state
    if (state['Status'] == "up")
      @gain.set_value(state['Gain'].to_i)
      @videorate.active = state['Frame'].to_i
      report("Ready.")
    else
      report("StellaCam is down!")
    end

  end

  def on_MainWindow_destroy
    Gtk.main_quit
  end

  def on_quit1_activate
    on_MainWindow_destroy
  end

  # routine to print to statusbar
  def report(text)
    @status.pop(0)
    @status.push(0, text)
  end

  # configure stellacam
  def on_Config_clicked
    begin
      @stella.gain(@gain.value_as_int)
      @stella.frame(@videorate.active_iter[0])
      @stella.gamma("Off")
      @stella.iris("Off")
      @stella.configure
      status = @stella.status
      if (status == "down")
	report("StellaCam is down!")
      else
	report("StellaCam configured.")
      end
      @retry = false
    rescue => why
      if !@retry
	retry
	@retry = true
      else
	report("Error: #{why}")
	@retry = false
      end
    end
  end

  def on_Grab_clicked
    system("#{$path}/get_stella_image.pl stellacam.fits")
    system("cat stellacam.fits | xpaset WFS fits")
  end

  # ping stellacam
  def on_Ping_clicked
    begin
      result = @stella.get_version
      if result
	result.chomp!
	report("StellaCam firmware version #{result}")
      else
	report("StellaCam is down!")
      end
      @retry = false
    rescue => why
      if !@retry
	retry
	@retry = true
      else
	report("Error: #{why}")
	@retry = false
      end
    end
  end

  def on_restart_stella_server_activate
  end

  def on_about1_activate
  end

end

Gnome::Program.new("StellaCam", "1.0.0")
begin
  stella = Stella_GUI.new
rescue => why
  puts "Error connecting to server: #{why}"
end
Gtk.main
