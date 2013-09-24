#!/usr/bin/ruby

# This is the WFS catalog gui
# It allows the operators to search a catalog for
# a WFS star near the telescope position or some ra/dec
# then select a star, move to it, and then back again.
# It manipulates the mount and hexapod in the process.

# Used by: f5wfs_gui f9wfs_gui swirc_gui

# This version uses MMTsocket.rb for all network activity
# (this avoids bouncing through telserver).
# (this may have bugs??).
# It also has the improved return to star logic.

# tjt - what I really HATE about debugging a glade application is
# that all error messages vanish (since all callbacks are invoked
# by glade), so when things go wrong, you get .... nothing!
# There may be a way to figure this out, but I haven't yet.

require 'libglade2'
require 'thread'
require 'timeout'
require 'socket'

# This is required for msg_get and msg_cmd
#  it provides the MSG module, which is included below.
#require "/mmt/shwfs/msg.rb"

$:.unshift "/mmt/scripts"
require 'MMTsocket'

### define the catalog GUI
class WFSCat
#  include MSG

  Star = Struct.new('Star', :name, :mag, :class, :ra, :dec, :dist)
  COLUMN_NAME, COLUMN_MAG, COLUMN_CLASS, COLUMN_RA, COLUMN_DEC, COLUMN_DIST, 
    NUM_COLUMNS = *(0..5).to_a
 
  def initialize(parent=nil)

    # set a global path to find scripts and stuff
    if ENV['WFSROOT']
      @wfsroot = ENV['WFSROOT']
    else
      @wfsroot = "/mmt/shwfs"
    end

    #@log_path = "./wfscat.log"
    @log_path = "/mmt/Logs/wfs/wfscat.log"
    log_entry( "Starting" )

    MMTsocket.set_mount "mount", 5241
    MMTsocket.set_hexapod "hexapod", 5341

    # "hexapod" is really a synonym for "hacksaw" now
    # port 5340 gives remote protocol access to hexapod-linux
    # port 5350 gives MSG protocol access to hexapod_linux

    @wfs_host = "localhost"
    @wfs_port = 6868

#    @mount_host = "mount"
#    @mount_port = 5241

#    @telserver_host = "hacksaw"
#    @telserver_port = 5403

    # New state variable introduced by tjt 3-6-2011
    # The idea is that this is usually false (when we are
    #    on a science object), and is set to true when this
    #    GUI has commanded a move to a wfs start.
    # Notice thought that the state is kept only in this GUI,
    #    so there are lots of scenarios when we can get out of
    #    synch.  It does allow us to fix the issue where the
    #    operator visits several wfs stars looking for one of
    #    a proper magnitude, then wants to go back to the science object.
    @on_wfs_star = false

    @parent = parent

    @prev = Hash.new

    @autohex = 0

    # Params obtained via msg in the old scheme.
#    @params = [
#      'cat_id',
#      'cat_ra2000',	# becomes "ra"
#      'cat_dec2000',	# becomes "dec"
#      'cat_rapm',
#      'cat_decpm',
#      'cat_epoch',	# never used
#      'rot',		# "rot" and "pa" yield "sky"
#      'pa',
#      'instazoff',
#      'insteloff',
#      'azoff',		# never used
#      'eloff',		# never used
#      'raoff',
#      'decoff'
#      ]

    @glade = GladeXML.new("#{@wfsroot}/glade/wfscat.glade") {|handler| method(handler)}
 
    @catwindow = @glade.get_widget("MainWindow")
    @status = @glade.get_widget("Status")
    @menubar = @glade.get_widget("menubar1")
 
    @ra_entry = @glade.get_widget("RA")
    @dec_entry = @glade.get_widget("Dec")

    @ra_entry.set_text("1:00:00")
    @dec_entry.set_text("32:00:00")

    @search_entry = @glade.get_widget("Radius")
    @mag_entry = @glade.get_widget("Mag")

    @findhere = @glade.get_widget("FindHere")
    @findtel = @glade.get_widget("FindTel")
    @goto = @glade.get_widget("GoTo")
    @return = @glade.get_widget("Return")
    @return.set_sensitive(false)
    
    @model = Gtk::ListStore.new(String, Float, String, String, String, Float)
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
    renderer.xalign = 0.5

    column = Gtk::TreeViewColumn.new("V Magnitude",
				     renderer,
				     {'text' =>COLUMN_MAG})
    column.set_sort_column_id(COLUMN_MAG)
    @tree.append_column(column)

    # column for spectral class
    renderer = Gtk::CellRendererText.new
    renderer.xalign = 0.5
    column = Gtk::TreeViewColumn.new("Type",
				     renderer,
				     {'text' =>COLUMN_CLASS})
    column.set_sort_column_id(COLUMN_CLASS)
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

    # column for distance
    renderer = Gtk::CellRendererText.new
    renderer.xalign = 1.0
    column = Gtk::TreeViewColumn.new("       Distance\n        (arcmin)",
				     renderer,
				     {'text' =>COLUMN_DIST})
    column.set_sort_column_id(COLUMN_DIST)
    @tree.append_column(column)

    @pma = Hash.new
    @pmd = Hash.new

  end

  def log_entry ( msg, info=nil )
    t = Time.now.localtime
    File.open( @log_path, "a" ) { |log|
    	log.print( t, " ", msg )
	if info
	  ra = sexagesimal(info['cat_ra2000'])
	  dec = sexagesimal(info['cat_dec2000'])
	  log.print( ": ", info['cat_id'], " ", ra, " ", dec )
	end
	log.print( "\n" )
    }
  end

  # routine to print to statusbar
  def report(text)
    @status.pop(0)
    @status.push(0, text)
  end

  def on_MainWindow_destroy
    log_entry( "Terminating" )
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

  def on_FindHere_clicked
    @pma = Hash.new
    @pmd = Hash.new
    ra_text = @ra_entry.text
    dec_text = @dec_entry.text
    fov = 2.0*@search_entry.value.to_f
    mag = @mag_entry.value
    if (ra_text =~ /:/ && dec_text =~ /:/)
      ra = hms2deg(ra_text)
      dec = hms2deg(dec_text)
      return if (ra == 'bad' || dec == 'bad')
      result = `#{@wfsroot}/wfscat/findstars #{ra} #{dec} #{fov} #{mag} | grep S | sort -n -k11`
      @model.clear
      result.each_line { |star|
	data = star.split(' ')
	iter = @model.append
	name = data[0]+" "+data[1]
	iter.set_value(0, name)
	iter.set_value(1, data[2].to_f)
	iter.set_value(2, data[4])
	iter.set_value(3, data[6])
	iter.set_value(4, data[7])
	@pma[name] = data[8].to_f
	@pmd[name] = data[9].to_f
	iter.set_value(5, data[10].to_f)
      }
      @tree.model = @model
    else
      return
    end
  end

  def on_FindTel_clicked
    # tjt - this used to be the only place we got
    # and saved the previous position.
    # At this moment, we just need RA and DEC to do the
    # search for candidate stars, but then we used to rely
    # on this position as the place to return to.
    #get_previous

    stuff = get_mount
    @ra_entry.text = sexagesimal(stuff['cat_ra2000'])
    @dec_entry.text = sexagesimal(stuff['cat_dec2000'])

    on_FindHere_clicked
    @return.set_sensitive(true)
  end

  # Button has been pressed to go to a selected star
  def on_GoTo_clicked

    log_entry( "Go to WFS star" )

    iter = @tree.selection.selected
    if (iter)

      # This is when we really should save our previous position.
      # note that we DO NOT save position again if we are moving from
      # one WFS star to another.
      unless @on_wfs_star
        @prev = get_mount
        log_entry( "Saving position", @prev )
      end
      @on_wfs_star = true

      name = iter.get_value(0).sub(/\s/, "-")
      ra = iter.get_value(3)
      dec = iter.get_value(4)
      msg = "Moving to: #{name} #{ra} #{dec}"
      report( msg )
      log_entry( msg )
      if @parent && !@parent.on_axis?
	@parent.on_OnAxis_clicked
      end
      Thread.new {
	@goto.set_sensitive(false)
	@return.set_sensitive(false)

	#@instoff = `echo "1 get off_instrument_z" | nc hexapod 5350`.split(' ')[2].to_i
        #@autohex = `echo "1 get auto_offsets" | nc hexapod 5350`.split(' ')[2].to_i

	@instoff = MMTsocket.hexapod_get "off_instrument_z"
	@autohex = MMTsocket.hexapod_get( "auto_offsets" ).to_i

	#system("echo \"offset instrument z 0.0\" | nc -w 5 hexapod 5340")
	#system("echo \"offset guider z 0.0\" | nc -w 5 hexapod 5340")

	MMTsocket.hexcmd "offset instrument z 0.0"
	MMTsocket.hexcmd "offset guider z 0.0"

        if @autohex > 0
          # system("echo \"auto_offsets 0\" | nc -w 5 hexapod 5340")
	  MMTsocket.hexcmd "auto_offsets 0"
        end

	#system("echo \"apply_offsets\" | nc -w 5 hexapod 5340")
	MMTsocket.hexcmd "apply_offsets"

	pm_ra = @pma[name]
	pm_ra = 0.0 unless pm_ra

	pm_dec = @pmd[name]
	pm_dec = 0.0 unless pm_dec

	set_offsets(0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
	#move_tel(name, ra, dec, @pma[name], @pmd[name], @prev['sky'], 2000.0)

	s = move_catalog( name, ra, dec, pm_ra, pm_dec )
	if s != "OK"
	  report( "Slew Failed" )
	  log_entry( "Slew Failed" )
	  @goto.set_sensitive(true)
	  @return.set_sensitive(true)
	  return
	end

	stop_rotator
	wait_for_mount

        #system("echo \"1 clearforces\" | nc -w 5 #{@wfs_host} #{@wfs_port}")

	# be sure the hexapod is also finished.
	wait_for_hexapod

	@goto.set_sensitive(true)
	@return.set_sensitive(true)

	report("Slew Completed.")
      }
    else
      log_entry( "No star was selected" )
      report("Please select a star.")
    end
  end

  def on_Return_clicked

    ra = sexagesimal(@prev['cat_ra2000'])
    dec = sexagesimal(@prev['cat_dec2000'])
    who = "#{@prev['cat_id']} #{ra} #{dec}"

    log_entry "-starting return to original object: #{who}"
    report("Returning to: #{who}")

    if @parent && @parent.on_axis?
      @parent.on_StowWFS_clicked
    end  

    Thread.new {
      @goto.set_sensitive(false)
      @return.set_sensitive(false)


######## Changed RJC - Sept 17, 2013
## Originally this code would check to see if auto_offsets was applied before finding a WFS
## Star and then set that setting again when finished WFSing.  To remove one potential thing that
## can be forgotten during a run, we are changing this to *always* apply auto-offsets.

      if @autohex > 0
        #system("echo \"auto_offsets #{@autohex}\" | nc -w 5 hexapod 5340")
        MMTsocket.hexcmd "auto_offsets #{@autohex}"
      end
      ##If autohex was exactly zero, turn on auto_offsets with 30s timer
      if @autohex == 0
        MMTsocket.hexcmd "auto_offsets 30"
      end
      log_entry "-done restoring auto_offsets: #{@autohex}"

      #MMTsocket.hexcmd "auto_offsets 1"
      #log_entry "-done auto_offsets 1 (enabled)"   


      system("echo \"offset instrument z #{@instoff}\" | nc -w 5 hexapod 5340")
      system("echo \"apply_offsets\" | nc -w 5 hexapod 5340")

      MMTsocket.hexcmd "offset instrument z #{@instoff}"
      log_entry "-done restoring instoff(z) #{@instoff}"

      MMTsocket.hexcmd "apply_offsets"
      log_entry "-done applying offsets"

      s = move_previous
      @on_wfs_star = false

      log_entry "Return to previous object", @prev

      if s != "OK"
      	log_entry "Return to previous failed"
      	report "Slew Failed"
        @goto.set_sensitive(true)
        @return.set_sensitive(true)
	return
      end

      set_offsets( @prev['instazoff'], @prev['insteloff'], 
		  0.0, 0.0,
		  @prev['raoff'], @prev['decoff'])
      log_entry "-done restoring mount offsets"

      # not any more - turned off by Tim back in the old days.
      # start_rotator

      wait_for_mount
      report("Slew Completed.")
      log_entry "--Slew Completed."

      @goto.set_sensitive(true)
      #@return.set_sensitive(true)
    }
  end

#  def get_previous_OLD
#    socket = sockopen(@telserver_host, @telserver_port)
#    if socket
#      @params.each { |param|
#	@prev[param] = msg_get(socket, param)
#      }
#      socket.close
#      socket = nil
#      @prev['sky'] = @prev['pa'].to_f - @prev['rot'].to_f
#      @prev['ra'] = sexagesimal(@prev['cat_ra2000'])
#      @prev['dec'] = sexagesimal(@prev['cat_dec2000'])
#    end
#  end

  def get_mount
    mount = MMTsocket.mount
    mount.ident( "wfscat" )
    stuff = mount.values
    mount.done
    stuff
  end

#  def start_rotator_OLD
#    socket = sockopen(@mount_host, @mount_port)
#    socket.send("startrot\n", 0)
#    socket.close
#    socket = nil
#  end
#
#  def stop_rotator_OLD
#    socket = sockopen(@mount_host, @mount_port)
#    socket.send("stoprot\n", 0)
#    socket.close
#    socket = nil
#  end

  def start_rotator
    MMTsocket.mountcmd "startrot"
  end

  def stop_rotator
    MMTsocket.mountcmd "stoprot"
  end

#  def move_tel_OLD( name, ra, dec, rapm, decpm, pa, epoch )
#    ra = hms2deg(ra)
#    dec = hms2deg(dec)
#
#    socket = sockopen(@mount_host, @mount_port)
#    socket.send("newstar\n", 0)
#    socket.send("#{name}\n", 0)
#    socket.send("#{ra}\n", 0)
#    socket.send("#{dec}\n", 0)
#    socket.send("#{rapm}\n", 0)
#    socket.send("#{decpm}\n", 0)
#    socket.send("#{epoch}\n", 0)
#    socket.send("J\n", 0)
#    socket.send("WFS: #{name}\n", 0)
#    answer = socket.gets
#    socket.close
#    socket = nil
#
#    if (answer =~ /OK/)
#      return true
#    else
#      return false
#    end
#  end

  # returns OK or ERR
  def move_catalog ( name, ra, dec, rapm, decpm )
      move_tel( name, ra, dec, rapm, decpm, 0.0, 2000.0, "go" )
  end

  # returns OK or ERR
  def move_previous
      # never used.
      pa = @prev['pa'].to_f - @prev['rot'].to_f

      ra = sexagesimal(@prev['cat_ra2000'])
      dec = sexagesimal(@prev['cat_dec2000'])

      move_tel(
	  @prev['cat_id'],
	  ra,
	  dec,
	  @prev['cat_rapm'],
	  @prev['cat_decpm'],
	  pa, 
	  2000.0,
	  "return" )
  end

  def cmd_debug ( cmd, stuff=nil )
  	puts cmd
	stuff.each { |a| puts a.to_s } if stuff
  end

  # notice that the pa argument is never used.
  # returns OK or ERR
  def move_tel ( name, ra, dec, rapm, decpm, pa, epoch, msg )
    ra = hms2deg(ra) # decimal hours
    dec = hms2deg(dec) # decimal degrees

    args = [ name, ra, dec, rapm, decpm, epoch, "J", "WFS-#{msg}: #{name}" ]
    cmd_debug( "newstar", args )

    mount = MMTsocket.mount
    rv = mount.command( "newstar", args )
    mount.done
    rv
  end

  def set_offsets ( instaz, instel, az, el, ra, dec )
    mount = MMTsocket.mount
    mount.command( "setoffaainst", [ instaz, instel ] )
    mount.command( "setaa", [ el, az ] )
    mount.command( "setrd", [ ra, dec ] )
    mount.done
  end

#  def set_offsets_OLD ( instaz, instel, az, el, ra, dec )
#    socket = sockopen(@telserver_host, @telserver_port)
#    inst = msg_cmd(socket, 'instoff', "#{instaz} #{instel}")
#    azel = msg_cmd(socket, 'azeloff', "#{az} #{el}")
#    radec = msg_cmd(socket, 'radecoff', "#{ra} #{dec}")
#    socket.close
#    socket = nil
#    if (inst && azel && radec)
#      return true
#    else
#      return false
#    end
#  end

#  def wait_for_slew_OLD
#    sleep(2)
#    socket = sockopen(@telserver_host, @telserver_port)
#    inpos = 0
#    loop do
#      inpos = msg_get(socket, 'inpos').to_i
#      break if inpos == 1
#      sleep(1)
#    end
#    socket.close
#    socket = nil
#    return true
#  end

  def wait_for_mount
    sleep(2)
    mount = MMTsocket.mount
    loop do
      break if mount.get( "inpos" ) == "1"
      sleep(1)
    end
    mount.done
  end

  def wait_for_hexapod
    sleep(2)
    hexapod = MMTsocket.hexapod
    loop do
      break if hexapod.get( "motionFlag" ) == "0"
      print hexapod.get( "motionFlag" )
      sleep(1)
    end
    hexapod.done
  end

#  def wait4hexapod
#    socket = sockopen("hexapod", 5350)
#    inmotion = 1
#    sleep(2)
#    loop do
#      inmotion = msg_get(socket, 'motionFlag').to_i
#      break if inmotion == 0
#      sleep(2)
#    end
#    socket.close
#    socket = nil
#  end

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

# This is a ruby idiom to test if this file is being run
# standalone, or included from some other file.
# $0 is the name of the command used to invoke this script.
# __FILE__ is the name of the script.

if $0 == __FILE__
  Gtk.init
  WFSCat.new
  Gtk.main
end

# THE END
