#!/usr/bin/ruby

# For some reason that I forget, this is an OLD
# version of this software (in /mmt/shwfs, there
# is also wfscat_new.rb).  Something no doubt went
# wrong with the new version - which is hell on
# wheels to debug due to glade brain damage.
# Consider yourself warned ...  tjt  5-22-2012

# This is the WFS catalog gui
# It allows the operators to search a catalog for
# a WFS star near the telescope position or some ra/dec
# then select a star, move to it, and then back again.
# It manipulates the mount and hexapod in the process.
#
# Used by: f5wfs_gui f9wfs_gui swirc_gui

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
require "/mmt/shwfs/msg.rb"

$:.unshift "/mmt/scripts"
require 'MMTsocket'

### define the catalog GUI
class WFSCat
  include MSG

  Star = Struct.new('Star', :name, :mag, :class, :ra, :dec, :dist)
  COLUMN_NAME, COLUMN_MAG, COLUMN_CLASS, COLUMN_RA, COLUMN_DEC, COLUMN_DIST, 
    NUM_COLUMNS = *(0..5).to_a
 
  def initialize(parent)

    # set a global path to find scripts and stuff
    if ENV['WFSROOT']
      @path = ENV['WFSROOT']
    else
      @path = "/mmt/shwfs"
    end

    @log_path = "/mmt/Logs/wfs/wfscat.log"

    @mount_host = "mount"
    @mount_port = 5241

    @telserver_host = "hacksaw"
    @telserver_port = 5403

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

    @params = ['cat_id', 'rot', 'cat_ra2000', 'cat_dec2000', 'cat_rapm', 
      'cat_decpm', 'pa', 'cat_epoch', 'instazoff', 'insteloff',
      'azoff', 'eloff', 'raoff', 'decoff']

    @glade = GladeXML.new("#{@path}/wfscat/wfscat.glade") {|handler| method(handler)}
 
    @catwindow = @glade.get_widget("MainWindow")
    @status = @glade.get_widget("Status")
    @menubar = @glade.get_widget("menubar1")
 
    @ra_entry = @glade.get_widget("RA")
    @dec_entry = @glade.get_widget("Dec")

    @ra_entry.set_text("10:00:00")
    @dec_entry.set_text("10:00:00")

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
      result = `#{@path}/wfscat/findstars #{ra} #{dec} #{fov} #{mag} | grep S | sort -n -k11`
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
    ra, dec = get_cur_radec
    @ra_entry.text = ra
    @dec_entry.text = dec
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
        get_previous
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

	@instoff = `echo "1 get off_instrument_z" | nc hexapod 5350`.split(' ')[2].to_i
        @autohex = `echo "1 get auto_offsets" | nc hexapod 5350`.split(' ')[2].to_i

	# This will echo OK
	system("echo \"offset instrument z 0.0\" | nc -w 5 hexapod 5340")

	# This will echo OK
	system("echo \"offset guider z 0.0\" | nc -w 5 hexapod 5340")
        if @autohex > 0
          system("echo \"auto_offsets 0\" | nc -w 5 hexapod 5340")
        end

	# This will echo OK
	system("echo \"apply_offsets\" | nc -w 5 hexapod 5340")

	# This talks to telserver
	set_offsets(0.0, 0.0, 0.0, 0.0, 0.0, 0.0)

	puts "launch move"
	s = move_tel(name, ra, dec, @pma[name], @pmd[name], @prev['sky'], 2000.0)
	puts "move is launched"
	puts s

	if s != "OK"
          report( "Slew Failed" )
          log_entry( "Slew Failed" )
          @goto.set_sensitive(true)
          @return.set_sensitive(true)
          return
	end

	stop_rotator
	sleep(2)
	wait_for_slew

        #system("echo \"1 clearforces\" | nc -w 5 localhost 6868")
	#wait4hexapod
	#wait4hexapod
	wait4hexapod
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
    report("Returning to: #{@prev['cat_id']} #{@prev['ra']} #{@prev['dec']}")
    if @parent && @parent.on_axis?
      @parent.on_StowWFS_clicked
    end  
    Thread.new {
      @goto.set_sensitive(false)
      @return.set_sensitive(false)
      if @autohex > 0
        system("echo \"auto_offsets #{@autohex}\" | nc -w 5 hexapod 5340")
      end
      system("echo \"offset instrument z #{@instoff}\" | nc -w 5 hexapod 5340")
      system("echo \"apply_offsets\" | nc -w 5 hexapod 5340")

      s = move_tel(@prev['cat_id'], @prev['ra'], @prev['dec'], 
	       @prev['cat_rapm'], @prev['cat_decpm'], @prev['sky'], 
	       2000.0)
      @on_wfs_star = false

      log_entry( "Return to previous object", @prev )
      if s != "OK"
        log_entry( "Return to previous failed" )
        report "Slew Failed"
        @goto.set_sensitive(true)
        @return.set_sensitive(true)
        return
      end

      set_offsets(@prev['instazoff'], @prev['insteloff'], 
		  0.0, 0.0,
		  @prev['raoff'], @prev['decoff'])
      # start_rotator
      sleep(2)
      wait_for_slew
      report("Slew Completed.")
      @goto.set_sensitive(true)
      #@return.set_sensitive(true)
    }
  end

  def get_previous
    socket = sockopen(@telserver_host, @telserver_port)
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

  def get_cur_radec
    mount = MMTsocket.new( @mount_host, @mount_port )
    mount.ident( "wfscat" )
    stuff = mount.values
    mount.done
    ra = sexagesimal(stuff['cat_ra2000'])
    dec = sexagesimal(stuff['cat_dec2000'])
    return ra, dec
  end

  def start_rotator
    socket = sockopen(@mount_host, @mount_port)
    socket.send("startrot\n", 0)
    socket.close
    socket = nil
  end

  def stop_rotator
    socket = sockopen(@mount_host, @mount_port)
    socket.send("stoprot\n", 0)
    socket.close
    socket = nil
  end

  def move_tel(name, ra, dec, rapm, decpm, pa, epoch)
    ra = hms2deg(ra)
    dec = hms2deg(dec)
    socket = sockopen(@mount_host, @mount_port)
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
    answer
  end

  def set_offsets(instaz, instel, az, el, ra, dec)
    socket = sockopen(@telserver_host, @telserver_port)
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
    socket = sockopen(@telserver_host, @telserver_port)
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
  wfs = WFSCat.new(nil)
  wfs.log_entry( "Starting" )
  Gtk.main
end
