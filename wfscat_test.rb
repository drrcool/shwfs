#!/usr/bin/ruby

include Math

require "/data/mmti/tcl/sla.so"

# set a global path to find scripts and stuff
if ENV['WFSROOT']
  @path = ENV['WFSROOT']
else
  @path = "/mmt/shwfs"
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

def dms2deg(string)
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

ra_text = ARGV[0]
dec_text = ARGV[1]

ra = dms2deg(ra_text)
dec = dms2deg(dec_text)

result = `#{@path}/wfscat/findstars #{ra} #{dec} 1.0 15.0 | grep S | sort -rn -k11`

result.each_line { |star|
  data = star.split(' ')
  ra_star = dms2deg(data[6])
  dec_star = dms2deg(data[7])
  next if data[2].to_f < 7.0
  next if data[8].to_f.abs*cos(dec_star*PI/180.0) > 5.0
  next if data[9].to_f.abs > 5.0
  next if data[10].to_f < 5.0
  posang = `#{@path}/wfscat/bear.tcl #{ra} #{dec} #{ra_star} #{dec_star}`.chomp.to_f
  star = sprintf("%s %7.3f\n", star.chomp, posang)
  puts star
}

