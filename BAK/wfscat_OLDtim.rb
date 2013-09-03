#!/usr/bin/ruby

require 'libglade2'
require 'timeout'
require 'socket'

### MSG routines
module MSG
  def sockopen(host, port)
    socket = nil
    status = nil
    timeout = 5.0
    begin
      timeout(5) {
        socket = TCPSocket.open(host, port)
      }
    rescue TimeoutError
      status = "Timeout"
      return nil
    rescue Errno::ECONNREFUSED
      status = "Refusing connection"
      return nil
    rescue => why
      status = "Error: #{why}"
      return nil
    end
    return socket
  end

  def msg_get(socket, par)
    return nil unless socket
    socket.send("1 get #{par}\n", 0)
    result = socket.gets
    if (result =~ /ack/)
      answer = result.split('ack')[1].chomp
    else 
      answer = nil
    end
    return answer
  end

  def msg_cmd(socket, command, value)
    return nil unless socket
    socket.send("1 #{command} #{value}\n", 0)
    answer = socket.gets
    if (answer =~ /ack/)
      return true
    else 
      return false
    end
  end

  def msg_set(socket, par, value)
    return nil unless socket
    socket.send("1 set #{par} #{value}\n", 0)
    answer = socket.gets
    if (answer =~ /ack/)
      return true
    else 
      return false
    end
  end
end

class MainWindow
  include MSG

  Star = Struct.new('Star', :name, :mag, :class, :ra, :dec, :dist)
  COLUMN_NAME, COLUMN_MAG, COLUMN_CLASS, COLUMN_RA, COLUMN_DEC, COLUMN_DIST, 
    NUM_COLUMNS = *(0..5).to_a
 
  def initialize
    if ENV['WFSROOT']
      @path = ENV['WFSROOT']
    else
      @path = "/mmt/shwfs"
    end
 
    @prev = Hash.new

    @params = ['cat_id', 'rot', 'cat_ra2000', 'cat_dec2000', 'cat_rapm', 
      'cat_decpm', 'pa', 'cat_epoch', 'instazoff', 'insteloff',
      'azoff', 'eloff', 'raoff', 'decoff']

    @glade = GladeXML.new("#{@path}/wfscat/wfscat.glade") {|handler| method(handler)}
 
    @mainwindow = @glade.get_widget("MainWindow")
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

  # routine to print to statusbar
  def report(text)
    @status.pop(0)
    @status.push(0, text)
  end

  def on_MainWindow_destroy
    @mainwindow.destroy
    Gtk.main_quit
  end

  def on_quit1_activate
    @mainwindow.destroy
    Gtk.main_quit
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
      return if (ra == -1 || dec == -1)
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
    get_previous
    @ra_entry.text = @prev['ra']
    @dec_entry.text = @prev['dec']
    on_FindHere_clicked
    @return.set_sensitive(true)
  end

  def on_GoTo_clicked
    iter = @tree.selection.selected
    if (iter)
      name = iter.get_value(0).sub(/\s/, "-")
      ra = iter.get_value(3)
      dec = iter.get_value(4)
      report("Moving to: #{name} #{ra} #{dec}")
      Thread.new {
	@goto.set_sensitive(false)
	@return.set_sensitive(false)
	set_offsets(0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
	move_tel(name, ra, dec, @pma[name], @pmd[name], @prev['sky'], 2000.0)
	stop_rotator
	@goto.set_sensitive(true)
	@return.set_sensitive(true)
      }
    else
      report("Please select a star.")
    end
  end

  def on_Return_clicked
    report("Returning to: #{@prev['cat_id']} #{@prev['ra']} #{@prev['dec']} #{@prev['sky']}")
    Thread.new {
      @goto.set_sensitive(false)
      @return.set_sensitive(false)
      move_tel(@prev['cat_id'], @prev['ra'], @prev['dec'], 
	       @prev['cat_rapm'], @prev['cat_decpm'], @prev['sky'],
	       @prev['cat_epoch'])
      set_offsets(@prev['instazoff'], @prev['insteloff'], 
		  @prev['azoff'], @prev['eloff'], 
		  @prev['raoff'], @prev['decoff'])
      set_m2_reference
      @goto.set_sensitive(true)
      @return.set_sensitive(true)
    }
  end

  def get_previous
    socket = sockopen("hacksaw", 5403)
    @params.each { |param|
      @prev[param] = msg_get(socket, param)
    }
    socket.close
    socket = nil
    @prev['sky'] = @prev['pa'].to_f - @prev['rot'].to_f
    @prev['ra'] = sexagesimal(@prev['cat_ra2000'])
    @prev['dec'] = sexagesimal(@prev['cat_dec2000'])
  end

  def start_rotator
    socket = sockopen('mount', 5241)
    socket.send("startrot\n", 0)
    socket.close
    socket = nil
  end

  def stop_rotator
    socket = sockopen('mount', 5241)
    socket.send("stoprot\n", 0)
    socket.close
    socket = nil
  end

  def move_tel(name, ra, dec, rapm, decpm, pa, epoch)
    ra = hms2deg(ra)
    dec = hms2deg(dec)
    socket = sockopen('mount', 5241)
    socket.send("pastar\n", 0)
    socket.send("#{name}\n", 0)
    socket.send("#{ra}\n", 0)
    socket.send("#{dec}\n", 0)
    socket.send("#{rapm}\n", 0)
    socket.send("#{decpm}\n", 0)
    socket.send("#{pa}\n", 0)
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
    return -1 if vals.size != 3
    hour = vals[0].to_f
    min  = vals[1].to_f
    sec  = vals[2].to_f
    return hour + min/60.0 + sec/3600.0
  end
    

end

Gnome::Program.new("GSCCS", "1.0.0")
MainWindow.new()
Gtk::main
