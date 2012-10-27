#!/usr/bin/env python2

"""
make_thermalization_scripts.py
Author: Jonah Miller (jonah.maxwell.miller@gmail.com)

This program reads all *.boundary2p1 files given to it as input, and,
for each input boundary, writes a script to thermalize a spacetime
with either the initial boundary or the final boundary, or both as the
input boundary file. If one of hte two boundaries is left unset, it is
assumed to be a tetrahedron.

You can set the other parameters of the autogenerated script by
changing the global constants of this file.

To set which boundary the script sets the boundary file to, use the
first command line argument. Put an "l" in the first command line
argument to make it set the initial boundary. Put an "r" in the first
command line argument to set the final boundary. If you put neigher in
the first argument (use a dash for consistency, but it doesn't really
matter). The remaining command line arguments are boundary file names.

Example calls:
----------------------------------------

# This one sets the boundary file to the initial boundary
python2 make_thermalization_scripts.py l TS2-V64-k1.0-kkk0.7577200487786184d0-top.boundary

# This one makes a script with a tetrahedron on both boundaries.
makes neigher boundary -

# For each file in the directory, set that file to both boundaries.
python2 make_thermalization_scripts.py lr ./* 
"""

# Import modules
#----------------------------------------------------------------------
import sys # For the operating system/file system commands
#----------------------------------------------------------------------

# Important global constants
#----------------------------------------------------------------------
# The function used to gather data
DATA_GATHERING_FUNCTION = "generate-data-in-time"

# Usually initial sweep. For generate-data-in-time, however, it's the
# number of seconds we want to generate data for.
DATA_GATHERING_INPUT = 60*60*23.75 # currently: 23 hours, 45 minutes

# The total number of sweeps you want. If DATA_GATHERING_FUNCTION is
# generate-data-in-time, this doesn't do anything other than change
# filenames, but you should set it to some value anyway.
NUM_SWEEPS = 50000

# The number of time slices in the simulation. MUST be an even
# number. If it isn't even, the program will MAKE it even.
NUM_TIME_SLICES = 28

# The target volume of the spacetime. Doesn't need to be exact.
TARGET_VOLUME = 30850

# The spatial topology of the spacetime. Almost always "S2" for sphere.
SPATIAL_TOPOLOGY = "S2"

# The boundary conditions. I don't know why you'd change these to
# "PERIODIC," since this script is for open boundary conditions.
BOUNDARY_CONDITIONS = "OPEN"

# The k0 coupling constant. Set this based on the time slices and the
# target volume. Other data analysis scripts can help you figure out
# what it needs to be.
K0 = 1.0

# The k3 coupling constant. Set this based on the time slices and the
# target volume. Other data analysis scripts can help you figure out
# what it needs to be.
K3 = 0.75772

# ALPHA is the length^2 of the time-like edges of tetrahedra. THere's
# no reason to change it from -1. As long as ALPHA is negative, it
# doesn't do anything.
ALPHA = -1

# SAVE_EVERY_N_SWEEPS decides how often a spacetime is saved.
SAVE_EVERY_N_SWEEPS = 10

# The damping parameter for the Metropolis algorithm.
EPS = 0.02 # 0.02 is the default

# Files end with *.script.lisp to differentiate them from packages.
OUTPUT_SUFFIX = ".script.lisp"

# The output directory the lisp thermalization script saves its files to.
OUTPUT_DIRECTORY = '""' # Default is present working directory.

# The functional form of the script. Don't change this.
LISP_SCRIPT = """;;;; Lisp script auto generated with
;;;; make_thermalization_scripts.py

;;;; Boundary file used to generate script: {}

(setf NUM-SWEEPS {})
(setf SAVE-EVERY-N-SWEEPS {})
(setf *eps* {})

;; Initialize spacetime
{}

;; Set coupling constants
(set-k0-k3-alpha {} {} {})

;; start the simulation
({})
"""
# ----------------------------------------------------------------------


# Function definitions
#----------------------------------------------------------------------
def ensure_correct_globals ():
    "Ensure the global constants are valid. Defensive coding."
    
    # Must be an integer
    DATA_GATHERING_INPUT = int(DATA_GATHERING_INPUT)
    NUM_SWEEPS = int(NUM_SWEEPS)
    NUM_TIME_SLICES = int(NUM_TIME_SLICES)
    TARGET_VOLUME = int(TARGET_VOLUME)
    SAVE_EVERY_N_SWEEPS = int(SAVE_EVERY_N_SWEEPS)

    # Ensure valid input.
    if SPATIAL_TOPOLOGY not in ("S2","T2"):
        raise ValueError("Spatial topology invalid.")
    if BOUNDARY_CONDITIONS not in ("OPEN","PERIODIC"):
        raise ValueError("Boundary conditions invalid.")
    if ALPHA >= 0:
        raise ValueError("alpha must be negative to preserve lorentzian"
                         +" structure.")
    # NUM_TIME_SLICES MUST BE EVEN
    if NUM_TIME_SLICES % 2 != 0:
        NUM_TIME_SLICES = NUM_TIME_SLICES - 1

    # Return true if successful.
    return True
    

def make_initialization (left_boundary=False, right_boundary=False):
    "Make the initialization part of the script."
    
    outstring = """(initialize-t-slices-with-v-volume
                    :num-time-slices {}
                    :target-volume {}
                    :spatial-topology {}
                    :boundary-conditions {}""".format(NUM_TIME_SLICES,
                                                      TARGET_VOLUME,
                                                      SPATIAL_TOPOLOGY,
                                                      BOUNDARY_CONDITIONS)    

    # If the boundaries need to be set, set them.
    if left_boundary:
        outstring += "\n :initial-spatial-geometry {}".format(left_boundary)
    if right_boundary:
        outstring += "\n :final-spatial-geometry {}".format(right_boundary)

    # Add the closing directory.
    outstring += ")"

    return outstring

def make_boundary_file_out(filename):
    "Concatenates the filename ending."
    index = filename.find(".boundary")
    return filename[:index]

def make_filename (boundary_file_name,
                   left_boundary=False, right_boundary=False):
    "Make the output file name."
    
    boundary_file_out = make_boundary_file_out(boundary_file_name)
    outstring = "AUTO_{}_{}_T0{}_V0{}_B_{}".format(SPATIAL_TOPOLOGY,
                                                   BOUNDARY_CONDITIONS,
                                                   NUM_TIME_SLICES,
                                                   TARGET_VOLUME,
                                                   boundary_file_out)
    outstring += OUTPUT_SUFFIX

    return outstring

def make_data_taking_command ():
    if DATA_GATHERING_FUNCTION == "generate-data-in-time":
        return DATA_GATHERING_FUNCTION + " " + str(DATA_GATHERING_INPUT)
    else:
        return DATA_GATHERING_FUNCTION

def make_script (boundary_file,left_boundary=False, right_boundary=False):
    return LISP_SCRIPT.format(boundary_file,
                              NUM_SWEEPS,SAVE_EVERY_N_SWEEPS,EPS,
                              make_initialization(left_boundary,
                                                  right_boundary),
                              K0,K3,ALPHA,
                              make_data_taking_command())

def make_output (boundary_file_name,left_boundary=False,
                 right_boundary=False):
    outfilename = make_filename(boundary_file_name,left_boundary,
                                right_boundary)
    print outfilename
    with open(outfilename,'w') as f:
        f.write(make_script(boundary_file_name,left_boundary,right_boundary))

#----------------------------------------------------------------------


# Main loop
if __name__ == "__main__":
    print "Making scripts!"
    print "Scriptnames..."
    if "l" in sys.argv[1] and "r" in sys.argv[1]:
        for f in sys.argv[2:]:
            make_output(f,f,f)
    elif "l" in sys.argv[1]:
        for f in sys.argv[2:]:
            make_output(f,f,False)
    elif "r" in sys.argv[1]:
        for f in sys.argv[2:]:
            make_output(f,False,f)
    else:
        for f in sys.argv[2:]:
            make_output(f,False,False)
    print "All done! Happy hacking!"
    
