### define the PixelLink GUI
class PixelLink
  include MSG

  def initialize
    @glade = GladeXML.new("#{$path}/glade/f5wfs_pix.glade") {|handler| method(handler)}
    @pixmain  = @glade.get_widget("MainWindow")
    @status = @glade.get_widget("StatusBar")

    # camera configuration
    @configcam = @glade.get_widget("ConfigCamera")
    @binning = @glade.get_widget("Binning")
    @x1 = @glade.get_widget("X1")
    @y1 = @glade.get_widget("Y1")
    @nx = @glade.get_widget("NX")
    @ny = @glade.get_widget("NY")

    # exposure configuration
    @expose = @glade.get_widget("Expose")
    @loop = @glade.get_widget("LoopExpose")
    @nexp = @glade.get_widget("NExp")
    @exptime = @glade.get_widget("ExpTime")
    @direntry = @glade.get_widget("DirEntry")
    system("mkdir -p #{$path}/datadir/pix")
    @direntry.set_text("#{$path}/datadir/pix")
    @fileentry = @glade.get_widget("FileEntry")
    @fileentry.set_text("test")
    on_ConfigCamera_clicked
  end

  def on_MainWindow_destroy
    @pixmain.destroy
  end

  # routine to print to statusbar
  def report(text)
    @status.pop(0)
    @status.push(0, text)
  end

  # configure camera
  def on_ConfigCamera_clicked
    report("Configuring PixelLink camera...")
    t = Thread.new {
      begin
	timeout(6) {
	  system "#{$path}/f5wfs setbox pix #{@x1.value_as_int} #{@nx.value_as_int} #{@y1.value_as_int} #{@ny.value_as_int} #{@binning.value_as_int}"
	  sleep(1)
	  report("PixelLink Camera configured.")
	}
      rescue Timeout::Error
	report("Timed out configuring PixelLink camera.")
      rescue => why
	report("Error configuring PixelLink camera: #{why}")
      end
    }
  end

  def on_Expose_clicked
    t = Thread.new {
      pix_expose(@fileentry.text, @nexp.value_as_int, 1)
    }
  end

  def on_LoopExpose_toggled
    if (@loop.active?)
      @run = true
      @loop.child.set_text("STOP")
      loop_thread = Thread.new {
	n = 1
	while @run do
	  pix_expose("test", 1, n)
	  n = n + 1
	end
      }
    else
      @run = false
      @loop.child.set_text("Continuously Expose")
    end
  end

  # configure and take exposure
  def pix_expose(file, nexp, n)
    exptime = @exptime.value.to_f
    dir = @direntry.text

    system("mkdir -p #{dir}")
    @expose.set_sensitive(false)

    error = false
    nexp.times {

      # figure out the filename
      if file == "test"
	fullfilename = "#{dir}/#{file}.fits"
	filename = "#{file}.fits"
	system("rm -f #{fullfilename}")
      else
	@loop.set_sensitive(false)
	num = 0
	fullfilename = sprintf("%s/%s_%04d.fits", dir, file, num)
	filename = sprintf("%s_%04d.fits", file, num)
	while test(?e, fullfilename) 
	  num = num + 1
	  fullfilename = sprintf("%s/%s_%04d.fits", dir, file, num)
	  filename = sprintf("%s_%04d.fits", file, num)
	end
      end

      report("Exposing \##{n} (#{filename})....")

      # give the script 10 sec beyond the exposure time, else it's stuck
      begin
	time = 30
	get_stuff = Thread.new {
	  system("#{$path}/f5wfs expose pix #{exptime} #{fullfilename}")
	}

	timeout = 0
	while get_stuff.alive?
	  if (timeout >= time && get_stuff.alive?)
	    get_stuff.kill
	    report("Stupid script hung.  Killed it and continuing...")
	    error = true
	    break
	  end
	  sleep(1.0)
	  timeout = timeout+1
	end

      rescue Timeout::Error
	report("Timed out exposing #{filename}.")
	error = true
	break
      rescue => why
	report("Error exposing #{filename}: #{why}")
	error = true
	break
      end

      # should only get here if all is well.  should....
      begin
	timeout(10) {
	  if test(?s, fullfilename)
	    system("/usr/bin/xpaset -p WFS file #{fullfilename}")
	    system("/usr/bin/xpaset -p WFS zoom to 0.5")
#	    x = 649
#	    y = 678
#	    system("/usr/bin/xpaset -n -p WFS regions circle #{x} #{y} 50")
#	    system("/usr/bin/xpaset -n -p WFS regions circle #{x} #{y} 10 # color = red")
	  else
	    raise "Image Missing"
	  end
	}
      rescue Timeout::Error
	report("Timed out displaying image.")
	error = true
	break
      rescue => why
	report("Error displaying image: #{why}")
	error = true
	break
      end
      n = n + 1
    }

    # if all's well, report completion, else leave the last error intact
    if (!error)
      if (nexp == 1)
	report("Completed Exposure.")
      else 
	report("Completed Exposures.")
      end
    end

    @expose.set_sensitive(true)
    @loop.set_sensitive(true)
  end
end
