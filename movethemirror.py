import sys
import gtk
import os

class MirrorMover:
        
        
     def RefreshOffsets(self):
          for ii in range(0,19):
               textbox = self.builder.get_object( 'order' + str(ii+1) + '_label' )
               
               if self.offsets[ii] == 0:
                    textbox.set_text(str(self.offsets[ii]))
               else:
                    textbox.set_use_markup(gtk.TRUE)
                    textbox.set_markup('<span size="18000"><b>' + str(self.offsets[ii]) + '</b></span>')
                         
          
     def delete_event(self, widget, event, data=None):
          gtk.main_quit()
          return False
  
     def ZeroForces_Clicked(self, widget, data=None):
          
          #Create the zrn file
          outfile = '/mmt/shwfs/datadir/manualmirrormove.zrn'
          output = open(outfile, 'w')
          for ii in range(0,19):
               output.write(str(-1*self.offsets[ii])+'\n')
               self.offsets[ii] = 0
          output.close()
          self.RefreshOffsets()


          #Run BCV:

          actN = []
          ii = 1
          while ii <= 52:
               actN.append(ii)
               ii = ii + 1
          ii = 101
          while ii <=152:
               actN.append(ii)
               ii = ii + 1


          
          os.environ['WFSROOT'] = "/mmt/shwfs"
          mask = '1111111111111111111'
          m1_gain = '1.0' # This is true for f9. For f5, it should be 0.5. We need to figure out what to do with that
          command = '/mmt/shwfs/bcv ' + outfile + ' ' + mask + ' ' + m1_gain

          bcv_output = os.popen(command).read()
          forces = bcv_output.split()
          forcefile = '/mmt/shwfs/datadir/manualmirrormove.forces'
          force_output = open(forcefile, 'w')
          ii = 0
          for actuator in actN:
               force_output.write(str(actN[ii]) + ' ' + str(forces[ii])+'\n')
               ii = ii + 1
          force_output.close()
          
          #This is the command to send the forces to the mirror!
          move_mirror_command = '/mmt/scripts/cell_send_forces ' + forcefile
          print(move_mirror_command)
          force_output = os.popen(move_mirror_command).read()
          print(force_output)

 


      
     def ClearOffsets_Clicked(self, widget, data=None):
          
          #Clear the offsets (making them 0 but without moving the mirror)
          self.offsets = [0]*19
          self.sendoffsets = [0]*19
          self.RefreshOffsets()
          
          

               
     def ApplyOffsets_Clicked(self, widget, data=None):
                    
          
          for ii in range(0,19):
               textbox = self.builder.get_object( 'order_entry' + str(ii+1) )
               offsetstring = textbox.get_text()
               if offsetstring == '' :
                    offsetstring = '0'
               newoffset = float(offsetstring)
               self.sendoffsets[ii] =  newoffset	    
               textbox.set_text('')

          #Create the zrn file
          outfile = '/mmt/shwfs/datadir/manualmirrormove.zrn'
          output = open(outfile, 'w')
          for ii in range(0,19):
               output.write(str(self.sendoffsets[ii])+'\n')
          output.close()
          


          #Run BCV:

          actN = []
          ii = 1
          while ii <= 52:
               actN.append(ii)
               ii = ii + 1
          ii = 101
          while ii <=152:
               actN.append(ii)
               ii = ii + 1


          
          os.environ['WFSROOT'] = "/mmt/shwfs"
          mask = '1111111111111111111'
          m1_gain = '1.0' # This is true for f9. For f5, it should be 0.5. We need to figure out what to do with that
          command = '/mmt/shwfs/bcv ' + outfile + ' ' + mask + ' ' + m1_gain

          bcv_output = os.popen(command).read()
          forces = bcv_output.split()
          forcefile = '/mmt/shwfs/datadir/manualmirrormove.forces'
          force_output = open(forcefile, 'w')
          ii = 0
          for actuator in actN:
               force_output.write(str(actN[ii]) + ' ' + str(forces[ii])+'\n')
               ii = ii + 1
          force_output.close()
          
          #This is the command to send the forces to the mirror!
          move_mirror_command = '/mmt/scripts/cell_send_forces ' + forcefile
          print(move_mirror_command)
          force_output = os.popen(move_mirror_command).read()
          print(force_output)


          for ii in range(0,19):
               self.offsets[ii] = self.offsets[ii] + self.sendoffsets[ii]
               textbox.set_text('')
          self.RefreshOffsets()




     def __init__(self):



          print("THIS IS THE F9 VERSION OF THE CODE.  THERE MAY NOT BE F5. TALK TO RICHARD FOR WHAT CHANGES NEED MADE")
    	#Initialize some variables (ok, a lot of them)
          self.offsets = [0]*19
          self.sendoffsets = [0]*19
          
          self.builder = gtk.Builder()
          self.builder.add_from_file("/mmt/shwfs/bendthemirror.glade") 
          
          self.window = self.builder.get_object("MainWindow")
          self.window.connect("delete_event", self.delete_event)
          self.builder.connect_signals(self)       
          
          
        #Setup the buttons
          self.ZeroForcesButton = self.builder.get_object("ZeroForces_Button")
          self.ZeroForcesButton.connect("clicked", self.ZeroForces_Clicked)
          
          self.ClearOffsetsButton = self.builder.get_object("ClearOffset_Button")
          self.ClearOffsetsButton.connect("clicked", self.ClearOffsets_Clicked)
          
          self.ApplyOffsetsButton = self.builder.get_object("ApplyOffsets_Button")
          self.ApplyOffsetsButton.connect("clicked", self.ApplyOffsets_Clicked)
          


if __name__ == "__main__":
     editor = MirrorMover()
     editor.window.show()
     gtk.main()
