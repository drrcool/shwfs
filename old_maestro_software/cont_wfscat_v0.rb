#!/usr/bin/ruby

require 'libglade2'
require 'thread'
require 'timeout'
require 'socket'
require "/mmt/shwfs/msg.rb"
require '/mmt/admin/srv/tcs_lookup.rb'

$mounthost, $mountport = srv_lookup('mount')
$wavehost, $waveport = srv_lookup('waveserv')
$hexhost, $hexport = srv_lookup('hexapod')
$hexmsghost, $hexmsgport = srv_lookup('hexapod-msg')
$wfshost, $wfsport = srv_lookup('wfs')

Thread.abort_on_exception = true

### define the catalog GUI
class WFSCat
  include MSG

  Star = Struct.new('Star', :name, :mag, :ra, :dec, :pa, :rot, :dist)
  COLUMN_NAME, COLUMN_MAG, COLUMN_RA, COLUMN_DEC, COLUMN_PA, COLUMN_ROT, COLUMN_DIST, 
    NUM_COLUMNS = *(0..6).to_a
 
  def initialize(parent)

    # set a global path to find scripts and stuff
    if ENV['WFSROOT']
      @wfsroot = ENV['WFSROOT']
    else
      @wfsroot = "/mmt/shwfs"
    end

    @parent = parent

    @prev = Hash.new

    @keeprefreshing = true 

    @flip = 180.0

    @autohex = 0
    @on_axis = false
    @deployed = false

    @params = ['cat_id', 'rot', 'cat_ra2000', 'cat_dec2000', 'cat_rapm', 
      'cat_decpm', 'pa', 'cat_epoch', 'instoff_az', 'instoff_alt',
      'off_az', 'off_alt', 'off_ra', 'off_dec']

    @glade = GladeXML.new("#{@wfsroot}/glade/maestro.glade") {|handler| method(handler)}
 
    @catwindow = @glade.get_widget("MainWindow")
    @status = @glade.get_widget("Status")
    @menubar = @glade.get_widget("menubar1")
 
    @ra_entry = @glade.get_widget("RA")
    @dec_entry = @glade.get_widget("Dec")

    @mag_entry = @glade.get_widget("mag")
    @inner_entry = @glade.get_widget("inner")
    @outer_entry = @glade.get_widget("outer")

    @flip_spin = @glade.get_widget("FlipVal")

    @ra_entry.set_text("12:51:26")
    @dec_entry.set_text("27:07:42")

    @findhere = @glade.get_widget("FindHere")
    @findtel = @glade.get_widget("FindTel")
    @go_onaxis = @glade.get_widget("GoOnAxis")
    @go_offaxis = @glade.get_widget("GoOffAxis")
    @return = @glade.get_widget("Return")
    @return.set_sensitive(false)
    
    @model = Gtk::ListStore.new(String, String, String, String, String, String, String)
    @tree = @glade.get_widget("OutputTree")
    @tree.model = @model

    # column for star name
    renderer = Gtk::CellRendererText.new
    column = Gtk::TreeViewColumn.new("Star Name",
				     renderer,
				     {'text' =>COLUMN_NAME})
    column.set_sort_column_id(COLUMN_NAME)
    @tree.append_column(column)

    # column for star mag
    renderer = Gtk::CellRendererText.new
    renderer.xalign = 1.0

    column = Gtk::TreeViewColumn.new("    V \n  Mag",
				     renderer,
				     {'text' =>COLUMN_MAG})
    column.set_sort_column_id(COLUMN_MAG)
    @tree.append_column(column)

    # column for RA
    renderer = Gtk::CellRendererText.new
    renderer.xalign = 0.5
    column = Gtk::TreeViewColumn.new("      RA\n   (J2000)",
				     renderer,
				     {'text' =>COLUMN_RA})
    column.set_sort_column_id(COLUMN_RA)
    @tree.append_column(column)

    # column for Dec
    renderer = Gtk::CellRendererText.new
    renderer.xalign = 0.5
    column = Gtk::TreeViewColumn.new("       Dec\n    (J2000)",
				     renderer,
				     {'text' =>COLUMN_DEC})
    column.set_sort_column_id(COLUMN_DEC)
    @tree.append_column(column)

    # column for PA
    renderer = Gtk::CellRendererText.new
    renderer.xalign = 1.0
    column = Gtk::TreeViewColumn.new("     PA",
				     renderer,
				     {'text' =>COLUMN_PA})
    column.set_sort_column_id(COLUMN_PA)
    @tree.append_column(column)

    # column for Rot
    renderer = Gtk::CellRendererText.new
    renderer.xalign = 1.0
    column = Gtk::TreeViewColumn.new("   Rot",
				     renderer,
				     {'text' =>COLUMN_ROT})
    column.set_sort_column_id(COLUMN_ROT)
    @tree.append_column(column)

    # column for distance
    renderer = Gtk::CellRendererText.new
    renderer.xalign = 0.5
    column = Gtk::TreeViewColumn.new("       Distance\n        (arcmin)",
				     renderer,
				     {'text' =>COLUMN_DIST})
    column.set_sort_column_id(COLUMN_DIST)
    @tree.append_column(column)

    @pma = Hash.new
    @pmd = Hash.new

  end

  # routine to print to statusbar
  def report(text)
    @status.pop(0)
    @status.push(0, text)
  end

  def on_Flip_clicked
    @flip = @flip_spin.value.to_f
    on_FindHere_clicked
  end

  def on_MainWindow_destroy
    @catwindow.destroy
    if @parent
      @parent.killcat
    else 
      Gtk.main_quit
    end
  end

  def on_quit1_activate
    on_MainWindow_destroy
  end

  def on_about1_activate
  end

  # DPorter - change handler for the stop auto-refresh checkbox. Feb 9 2012
  def on_cb_stoprefreshing_toggled
    @keeprefreshing = !@keeprefreshing
    report("Auto Refresh set to #{@keeprefreshing}")
  end

  def on_FindHere_clicked
    if @star_thread
      @star_thread.kill
    end
    @pma = Hash.new
    @pmd = Hash.new
    firstpass = true #DP
      
    #This is rcool's change that makes this button change slightly.  
    #When you click this button, it will refresh the RA/DEC of the telescope an
    #Then find the coordinates.
    
    ra_read = `echo "get ra" | nc -w 5 #{$mounthost} #{$mountport} | head -1`.split(' ')[1]
    dec_read = `echo "get dec" | nc -w 5 #{$mounthost} #{$mountport} | head -1`.split(' ')[1]
    @ra_entry.text = ra_read
    @dec_entry.text = dec_read
    


    ra_text = @ra_entry.text
    dec_text = @dec_entry.text
    if (ra_text =~ /:/ && dec_text =~ /:/)
      ra = hms2deg(ra_text)
      dec = hms2deg(dec_text)
      return if (ra == 'bad' || dec == 'bad')
#      puts "maestrostars #{ra} #{dec} #{@mag_entry.text} #{@inner_entry.text} #{@outer_entry.text}"
      result = `#{@wfsroot}/wfscat/maestrostars #{ra} #{dec} #{@mag_entry.text} #{@inner_entry.text} #{@outer_entry.text} | grep S | sort -n -k11`
      @star_thread = Thread.new {
	loop {
	  # first let's get the rotator limits
	  poslim = `echo "get rot_limp" | nc -w 5 #{$mounthost} #{$mountport} | head -1`.split(' ')[1].to_f
	  neglim = `echo "get rot_limn" | nc -w 5 #{$mounthost} #{$mountport} | head -1`.split(' ')[1].to_f
	  # now get the parallactic angle
	  parang = `echo "get pa" | nc -w 5 #{$mounthost} #{$mountport} | head -1`.split(' ')[1].to_f
	  
          if firstpass || @keeprefreshing	  
            if firstpass
              report("Setting firstpass to false")
              firstpass = false
            end
            @model.clear
            result.each_line { |star|
              data = star.split(' ')
              # need to offset pa by 180-38 to align WFS trans axis
              offset = @flip-38.0
              pa = `#{@wfsroot}/wfscat/bear.tcl #{ra} #{dec} #{data[6]} #{data[7]}`.to_f - offset
              rot = parang - pa
              if rot > 180.0
                rot = 360.0 - rot
              end
              # print "Parallactic Angle: " + parang.to_s + "\n"
              # print "Position Angle: " + pa.to_s + "\n"
              # print "Rotator Angle: " + rot.to_s + "\n"
              next if rot > poslim-10.0 || rot < neglim+10.0
              iter = @model.append
              name = data[0]+" "+data[1]
              iter.set_value(0, name)
              iter.set_value(1, data[2])
              iter.set_value(2, sexagesimal(data[6]))
              iter.set_value(3, sexagesimal(data[7]))
              iter.set_value(4, sprintf("%7.2f", pa))
              iter.set_value(5, sprintf("%7.2f", rot))
              @pma[name] = data[8].to_f
              @pmd[name] = data[9].to_f
              iter.set_value(6, data[10])
            }
     
            @tree.model = @model
            report("test")
          end
	  sleep(10)
	}
      }
    else
      return
    end
  end

  def on_FindTel_clicked
    get_previous
    @ra_entry.text = @prev['ra']
    @dec_entry.text = @prev['dec']
    on_FindHere_clicked
    @return.set_sensitive(true)
  end

  def on_GoOffAxis_clicked
    iter = @tree.selection.selected
    @return.child.set_text("Stow WFS")
    if (iter)
      name = iter.get_value(0).sub(/\s/, "-")
      pa = iter.get_value(4).to_f
      dist = iter.get_value(6).to_f*60.0*-1.0
      report("Moving WFS to: #{name} #{pa} #{dist}")
      Thread.new {
	@go_onaxis.set_sensitive(false)
	@go_offaxis.set_sensitive(false)
	@return.set_sensitive(false)
	begin
	  timeout(90) {
	    set_pa(pa)
	    system("echo \"1 spower 1\" | nc #{$wavehost} #{$waveport} > /dev/null")
	    system("echo \"1 fpower 1\" | nc #{$wavehost} #{$waveport} > /dev/null")
	    sleep(2)
	    # make sure we select WFS camera by default
	    system "#{@wfsroot}/f5wfs select wfs"
	    report("WFS Camera selected.")
	    system "#{@wfsroot}/f5wfs move #{dist}"
	    system "#{@wfsroot}/f5wfs sky"
	    report("WFS stage set to sky.")
	    # turn servo power off when done
	    sleep(1)
	    system("echo \"1 spower 0\" | nc #{$wavehost} #{$waveport} > /dev/null")
	    report("WFS Deployed.")
	    @on_axis = false
	  }
	rescue Timeout::Error
	  report("WFS Deploy Timed Out.")
	rescue => why
	  report("Error Deploying WFS: #{why}")
	end
	@go_onaxis.set_sensitive(true)
	@go_offaxis.set_sensitive(true)
	@return.set_sensitive(true)
	report("Motion Completed.")
	@deployed = true
	@on_axis = false
      }
    else
      report("Please select a star.")
    end
  end

  def on_GoOnAxis_clicked
    iter = @tree.selection.selected
    @return.child.set_text("Return to Stored Catalog Position")
    if (iter)
      name = iter.get_value(0).sub(/\s/, "-")
      ra = iter.get_value(2)
      dec = iter.get_value(3)
      report("Moving to: #{name} #{ra} #{dec}")
      if @parent && !@parent.on_axis?
	@parent.on_OnAxis_clicked
      end
      Thread.new {
	@go_onaxis.set_sensitive(false)
	@go_offaxis.set_sensitive(false)
	@return.set_sensitive(false)
	@instoff = `echo "1 get off_instrument_z" | nc -w 5 #{$hexmsghost} #{$hexmsgport}`.split(' ')[2].to_i
        @autohex = `echo "1 get auto_offsets" | nc -w 5 #{$hexmsghost} #{$hexmsgport}`.split(' ')[2].to_i
	system("echo \"offset instrument z 0.0\" | nc -w 5 #{$hexhost} #{$hexport}")
	system("echo \"offset guider z 0.0\" | nc -w 5 #{$hexhost} #{$hexport}")
        if @autohex > 0
          system("echo \"auto_offsets 0\" | nc -w 5 #{$hexhost} #{$hexport}")
        end
	system("echo \"apply_offsets\" | nc -w 5 #{$hexhost} #{$hexport}")

	set_offsets(0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
	move_tel(name, ra, dec, @pma[name], @pmd[name], @prev['sky'], 2000.0)
	begin
	  timeout(180) {
	    # turn stella and servo power on
	    system('echo "1 fpower 1" | nc -w 5 #{$wavehost} #{$waveport} > /dev/null')
	    system('echo "1 spower 1" | nc -w 5 #{$wavehost} #{$waveport} > /dev/null')
	    sleep(2)
	    # make sure we select WFS camera by default
	    system "#{@wfsroot}/f5wfs select wfs"
	    report("WFS Camera selected.")
	    system "#{@wfsroot}/f5wfs move 0"
	    report("WFS on-axis.")
	    @on_axis = true
	    system "#{@wfsroot}/f5wfs sky"
	    report("WFS stage set to sky.")
	    sleep(1)
	    system('echo "1 spower 0" | nc -w 5 #{$wavehost} #{$waveport} > /dev/null')
	  }
	rescue Timeout::Error
	  report("WFS Deploy Timed Out.")
	rescue => why
	  report("Error Deploying WFS: #{why}")
	end
	wait_for_slew
        #system("echo \"1 clearforces\" | nc -w 5 #{$wfshost} #{$wfsport}")
	wait4hexapod
	@go_onaxis.set_sensitive(true)
	@go_offaxis.set_sensitive(true)
	@return.set_sensitive(true)
	@on_axis = true
	@deployed = true
	report("Slew Completed.")
      }
    else
      report("Please select a star.")
    end
  end

  def on_Return_clicked
    if @on_axis
      report("Returning to: #{@prev['cat_id']} #{@prev['ra']} #{@prev['dec']}")
    else
      report("Moving WFS Stage to stow position...")
    end
    system("touch /tmp/wfs_stop")
    t = Thread.new {
      @go_onaxis.set_sensitive(false)
      @go_offaxis.set_sensitive(false)
      @return.set_sensitive(false)
      begin
        timeout(90) {
	  #if @autohex > 0
	  #  system("echo \"auto_offsets #{@autohex}\" | nc -w 5 #{$hexhost} #{$hexport}")
	  #end
	  system("echo \"offset instrument z #{@instoff}\" | nc -w 5 #{$hexhost} #{$hexport}")
	  system("echo \"apply_offsets\" | nc -w 5 #{$hexhost} #{$hexport}")
	  move_tel(@prev['cat_id'], @prev['ra'], @prev['dec'], 
		   @prev['cat_rapm'], @prev['cat_decpm'], @prev['sky'], 
		   2000.0)
	  set_offsets(@prev['instazoff'], @prev['insteloff'], 
		      0.0, 0.0,
		      @prev['raoff'], @prev['decoff'])
          system('echo "1 spower 1" | nc #{$wavehost} #{$waveport} > /dev/null')
          sleep(2)
          system "#{@wfsroot}/f5wfs stow"
          # turn stella and servo power off
          sleep(1)
          system('echo "1 fpower 0" | nc #{$wavehost} #{$waveport} > /dev/null')
          system('echo "1 spower 0" | nc #{$wavehost} #{$waveport} > /dev/null')
          report("WFS stowed.")
	  sleep(2)
	  wait_for_slew
	  report("Slew Completed.")
          @deployed = false
	  @on_axis = false
        }
      rescue Timeout::Error
        report("WFS Stow Timed Out.")
      rescue => why
        report("Error Stowing WFS: #{why}")
      end
      @go_onaxis.set_sensitive(true)
      @go_offaxis.set_sensitive(true)
      @return.set_sensitive(true)
      report("WFS Stowed.")
    }
  end

  def get_previous
   socket = sockopen("hacksaw", 5403)
   if socket
     @params.each { |param|
	@prev[param] = msg_get(socket, param)
     }
     socket.close
     socket = nil
     @prev['sky'] = @prev['pa'].to_f - @prev['rot'].to_f
     @prev['ra'] = sexagesimal(@prev['cat_ra2000'])
     @prev['dec'] = sexagesimal(@prev['cat_dec2000'])
   end
  end

  def set_pa(pa)
    socket = sockopen('mount', 5241)
    socket.send("setrotoffs\n", 0)
    socket.send("#{pa}\n", 0)
    socket.close
    socket = nil
  end

  def move_tel(name, ra, dec, rapm, decpm, pa, epoch)
    ra = hms2deg(ra)
    dec = hms2deg(dec)
    socket = sockopen('mount', 5240)
    socket.send("newstar\n", 0)
    socket.send("#{name}\n", 0)
    socket.send("#{ra}\n", 0)
    socket.send("#{dec}\n", 0)
    socket.send("#{rapm}\n", 0)
    socket.send("#{decpm}\n", 0)
    socket.send("#{epoch}\n", 0)
    socket.send("J\n", 0)
    socket.send("WFS: #{name}\n", 0)
    answer = socket.gets
    socket.close
    socket = nil

    if (answer =~ /OK/)
      return true
    else
      return false
    end
  end

  def set_offsets(instaz, instel, az, el, ra, dec)
    socket = sockopen('hacksaw', 5403)
    inst = msg_cmd(socket, 'instoff', "#{instaz} #{instel}")
    azel = msg_cmd(socket, 'azeloff', "#{az} #{el}")
    radec = msg_cmd(socket, 'radecoff', "#{ra} #{dec}")
    socket.close
    socket = nil
    if (inst && azel && radec)
      return true
    else
      return false
    end
  end

  def wait_for_slew
    socket = sockopen('hacksaw', 5403)
    inpos = 0
    loop do
      inpos = msg_get(socket, 'inpos').to_i
      break if inpos == 1
      sleep(1)
    end
    socket.close
    socket = nil
    return true
  end

  def wait4wfs
    socket = sockopen("wavefront", 3000)
    inmotion = 1
    sleep(2)
    loop do
      inmotion = msg_get(socket, 'motionFlag').to_i
      break if inmotion == 0
      sleep(2)
    end
    socket.close
    socket = nil
  end

  def wait4hexapod
    socket = sockopen("hexapod", 5350)
    inmotion = 1
    sleep(2)
    loop do
      inmotion = msg_get(socket, 'motionFlag').to_i
      break if inmotion == 0
      sleep(2)
    end
    socket.close
    socket = nil
  end

  def sexagesimal(angle)
    angle = angle.to_f
    if (angle < 0)
      angle = -angle
      sign = "-"
    else
      sign = "+"
    end

    d = angle.to_i
    x = (angle - d.to_f)*60.0
    m = x.to_i
    s = (x - m.to_f)*60.0

    return sprintf("%s%02d:%02d:%05.2f", sign, d, m, s)
  end

  def hms2deg(string)
    vals = string.split(':')
    return 'bad' if vals.size != 3
    hour = vals[0].to_f
    if hour < 0
      hour = hour * -1
    end
    min  = vals[1].to_f
    sec  = vals[2].to_f
    blah = hour + min/60.0 + sec/3600.0
    if (string =~ /-/ && blah > 0.0)
      blah = blah * -1
    end
    return blah
  end
end

if $0 == __FILE__
  Gtk.init
  WFSCat.new(nil)
  Gtk.main
end
