# the following flags are system-dependant,
# they must be set to compile a program which uses omiORB
# see omniORB's user's guide chapter one for information
# All the following lines must be commented but one.

#linux
OMNIORB_SYSDEP_FLAGS = -D __x86__ -D __linux__ -D __OSVERSION__=2
OMNIORB_LIBS = -L../../omniORB_2.7.0/lib/i586_linux_2.0_glibc -lomniORB2 -lomniDynamic2 -lomnithread -lpthread -ltcpwrapGK

#Solaris
#OMNIORB_SYSDEP_FLAGS = -D __sparc__ -D __sunos__ -D __OSVERSION__=5
#OMNIORB_LIBS = -L../../omniORB_2.7.0/lib/sun4_sosV_5.5 -lomniORB2 -lomniDynamic2 -lomnithread -lpthread -lposix4 -mt -lsocket -lnsl -ltcpwrapGK -lstdc++

