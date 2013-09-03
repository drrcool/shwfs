#!/usr/bin/ruby

require 'rexml/document'

front_r = Hash.new
mid_r = Hash.new
back_r = Hash.new

front_x = Hash.new
mid_x = Hash.new
back_x = Hash.new

front_y = Hash.new
mid_y = Hash.new
back_y = Hash.new

front_theta = Hash.new
mid_theta = Hash.new
back_theta = Hash.new

tcpos = File.new("/mmt/shwfs/cell/cell_TC_positions.dat")
tcpos.each_line { |line|
  next if line =~ /#/
  line.chomp!
  data = line.split(' ')
  front_r[data[0].to_i] = data[3]
  mid_r[data[1].to_i] = data[3]
  back_r[data[2].to_i] = data[3]
  front_theta[data[0].to_i] = data[4]
  mid_theta[data[1].to_i] = data[4]
  back_theta[data[2].to_i] = data[4]
  front_x[data[0].to_i] = data[5]
  mid_x[data[1].to_i] = data[5]
  back_x[data[2].to_i] = data[5]
  front_y[data[0].to_i] = data[6]
  mid_y[data[1].to_i] = data[6]
  back_y[data[2].to_i] = data[6]
}
tcpos.close
tcpos = nil

gmt = `date -u +"%H:%M:%S"`.chomp!
data = `echo "all" | nc hacksaw 7692 | grep cell_e_tc`

temps = Hash.new

data.each_line { |line|
  (tag, temp) = line.split(' ')
  temp = temp.to_f

  temps[tag] = temp
}

out = File.new("temp.dat", "w")
front_r.keys.each { |key|
  ftag = "cell_e_tc#{key}_C"
  mtag = "cell_e_tc#{key+1}_C"
  btag = "cell_e_tc#{key+2}_C"
  r = front_r[key]
  theta = front_theta[key]
  x = front_x[key]
  y = front_y[key]
  ftemp = temps[ftag]
  mtemp = temps[mtag]
  btemp = temps[btag]
  ave = (ftemp.to_f + mtemp.to_f + btemp.to_f)/3.0
  out.printf("%7s  %7s  %7s  %7s  %7s  %7s  %7s  %7.3f \n", x, y, r, theta, ftemp, mtemp, btemp, ave)
}
out.close
out = nil

# a = zeropoint temp
# b = E-W gradient
# c = N-S gradient
# d = focus
# e = astig @  0 + focus
# f = astig @ 45 + focus
# g = coma + E-W gradient
# h = coma + N-S gradient
# i = spherical + focus

fit = File.new("fit.gnu", "w")
fit.print("#!/usr/bin/gnuplot\n")
fit.print("set fit logfile \"/dev/null\" errorvariables\n")
fit.print("f(x,y) = a + b*x + c*y + d*(2*x*x + 2*y*y - 1) + e*(x*x - y*y) + f*2*x*y + g*(3*x*x*x + 3*x*y*y - 2*x) + h*(3*x*x*y + 3*y*y*y - 2*y) + i*(6*x*x*x*x + 12*x*x*y*y + 6*y*y*y*y - 6*x*x - 6*y*y + 1)\n")
fit.print("b(x,y) = a1 + b1*x + c1*y + d1*(2*x*x + 2*y*y - 1) + e1*(x*x - y*y) + f1*2*x*y + g1*(3*x*x*x + 3*x*y*y - 2*x) + h1*(3*x*x*y + 3*y*y*y - 2*y) + i1*(6*x*x*x*x + 12*x*x*y*y + 6*y*y*y*y - 6*x*x - 6*y*y + 1)\n")
fit.print("m(x,y) = a2 + b2*x + c2*y + d2*(2*x*x + 2*y*y - 1) + e2*(x*x - y*y) + f2*2*x*y + g2*(3*x*x*x + 3*x*y*y - 2*x) + h2*(3*x*x*y + 3*y*y*y - 2*y) + i2*(6*x*x*x*x + 12*x*x*y*y + 6*y*y*y*y - 6*x*x - 6*y*y + 1)\n")
fit.print("a(x,y) = a3 + b3*x + c3*y + d3*(3*x*x + 3*y*y - 1) + e3*(x*x - y*y) + f3*3*x*y + g3*(3*x*x*x + 3*x*y*y - 3*x) + h3*(3*x*x*y + 3*y*y*y - 3*y) + i3*(6*x*x*x*x + 13*x*x*y*y + 6*y*y*y*y - 6*x*x - 6*y*y + 1)\n")

fit.print("fit f(x,y) \"temp.dat\" using 1:2:5:(1) via a,b,c,d,e,f,g,h,i\n")
fit.print("set print \"cell_front.out\" append\n")
fit.print("print \"#{gmt} \",a,b,c,d,e,f,g,h,i\n")

fit.print("fit m(x,y) \"temp.dat\" using 1:2:6:(1) via a2,b2,c2,d2,e2,f2,g2,h2,i2\n")
fit.print("set print \"cell_mid.out\" append\n")
fit.print("print \"#{gmt} \",a2,b2,c2,d2,e2,f2,g2,h2,i2\n")

fit.print("fit b(x,y) \"temp.dat\" using 1:2:7:(1) via a1,b1,c1,d1,e1,f1,g1,h1,i1\n")
fit.print("set print \"cell_back.out\" append\n")
fit.print("print \"#{gmt} \",a1,b2,c1,d1,e1,f1,g1,h1,i1\n")

fit.print("fit a(x,y) \"temp.dat\" using 1:2:8:(1) via a3,b3,c3,d3,e3,f3,g3,h3,i3\n")
fit.print("set print \"cell_ave.out\" append\n")
fit.print("print \"#{gmt} \",a3,b3,c3,d3,e3,f3,g3,h3,i3\n")

fit.print("splot \"temp.dat\" using 1:2:5 title \"Front Plate Data\", \"temp.dat\" using 1:2:6 title \"Mid Plate Data\", \"temp.dat\" using 1:2:7 title \"Back Plate Data\", f(x,y) title \"Front Plate Fit\", m(x,y) title \"Mid Plate Fit\", b(x,y) title \"Back Plate Fit\"\n")
fit.print("pause -1\n")

fit.close
fit = nil

system("gnuplot -persist fit.gnu >& /dev/null")
#   system("rm fit.gnu")
system("mv temp.dat #{gmt}_temp.dat")
