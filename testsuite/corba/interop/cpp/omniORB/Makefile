#######################################################################
# Shell setup

DEL = rm -f

#######################################################################
# C/C++ compiler to use

CXX = g++ -D__USE_OMNIORB__
LD  = g++

#######################################################################
# Setup for omniORB 4.1.2

# OMNIORB_PATH    = <path_to_omniORB_install_dir>
OMNIORB_PATH    = /usr
OMNIORB_BIN     = $(OMNIORB_PATH)/bin
OMNIORB_INC     = $(OMNIORB_PATH)/include 
OMNIORB_LIBPATH = $(OMNIORB_PATH)/lib
OMNIORB_LIB     = -lomniORB4 -lomnithread -lomniDynamic4

# IDL Compiler setup
IDL = $(OMNIORB_BIN)/omniidl
IDL_FLAGS = -bcxx

#######################################################################
# Makefile configured for omniORB 4.0.6

CXXFLAGS = -c -Wall -I$(OMNIORB_INC) -g	-I./
LD_FLAGS = -g
LIBS = -L$(OMNIORB_LIBPATH) $(OMNIORB_LIB) -pthread

PROG= all_types_dynclient all_types_dynserver all_types_client all_types_server all_functions_client

all: $(PROG)

all_types_dynserver: all_types_dynserver.o
	$(LD) all_types_dynserver.o $(LD_FLAGS) $(LIBS) -o all_types_dynserver

all_types_dynclient: all_types_dynclient.o
	$(LD) all_types_dynclient.o $(LD_FLAGS) $(LIBS) -o all_types_dynclient

all_types_dynclient.o: ../common/all_types_dynclient.cc
	$(CXX) $(CXXFLAGS) ../common/all_types_dynclient.cc

all_types_dynserver.o: ../common/all_types_dynserver.cc
	$(CXX) $(CXXFLAGS) ../common/all_types_dynserver.cc

all_functions_client: all_functionsSK.o all_functions_client.o 
	$(LD) all_functions_client.o all_functionsSK.o $(LD_FLAGS) $(LIBS) -o all_functions_client

all_functions_client.o: ../common/all_functions_client.cc
	$(CXX) $(CXXFLAGS) ../common/all_functions_client.cc

all_functionsSK.o: all_functions.hh
	$(CXX) $(CXXFLAGS) all_functionsSK.cc

all_functions.hh: ../../../../../examples/corba/all_functions/all_functions.idl
	$(IDL) $(IDL_FLAGS) ../../../../../examples/corba/all_functions/all_functions.idl

all_types_client: all_types_client.o all_typesSK.o
	$(LD) all_types_client.o all_typesSK.o $(LD_FLAGS) $(LIBS) -o all_types_client

all_types_server: all_types_server.o all_typesSK.o
	$(LD) all_types_server.o all_typesSK.o $(LD_FLAGS) $(LIBS) -o all_types_server

all_types_client.o: ../common/all_types_client.cc all_types.hh all_typesSK.cc
	$(CXX) $(CXXFLAGS) ../common/all_types_client.cc 

all_types_server.o: all_types.hh all_typesSK.cc ../common/all_types_server.cc ../common/all_types_imp.cc
	$(CXX) $(CXXFLAGS) ../common/all_types_server.cc

all_typesSK.o: all_types.hh all_typesSK.cc
	$(CXX) $(CXXFLAGS) all_typesSK.cc

all_types.hh all_typesSK.cc: ../../../../../examples/corba/all_types/all_types.idl
	$(IDL) $(IDL_FLAGS) ../../../../../examples/corba/all_types/all_types.idl

clean:
	$(DEL) *.o *~
	$(DEL) $(PROG)

distclean: clean
	$(DEL) all_types.hh all_typesSK.cc all_functions.hh all_functionsSK.cc
