------------------------------------------------------------------------------
--                                                                          --
--                           POLYORB COMPONENTS                             --
--                                                                          --
--                             X E _ U T I L S                              --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--         Copyright (C) 1995-2011, Free Software Foundation, Inc.          --
--                                                                          --
-- PolyORB is free software; you  can  redistribute  it and/or modify it    --
-- under terms of the  GNU General Public License as published by the  Free --
-- Software Foundation;  either version 2,  or (at your option)  any  later --
-- version. PolyORB is distributed  in the hope that it will be  useful,    --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License  for more details.  You should have received  a copy of the GNU  --
-- General Public License distributed with PolyORB; see file COPYING. If    --
-- not, write to the Free Software Foundation, 51 Franklin Street, Fifth    --
-- Floor, Boston, MA 02111-1301, USA.                                       --
--                                                                          --
-- As a special exception,  if other files  instantiate  generics from this --
-- unit, or you link  this unit with other files  to produce an executable, --
-- this  unit  does not  by itself cause  the resulting  executable  to  be --
-- covered  by the  GNU  General  Public  License.  This exception does not --
-- however invalidate  any other reasons why  the executable file  might be --
-- covered by the  GNU Public License.                                      --
--                                                                          --
--                  PolyORB is maintained by AdaCore                        --
--                     (email: sales@adacore.com)                           --
--                                                                          --
------------------------------------------------------------------------------

with Ada.Characters.Handling; use Ada.Characters.Handling;
with Ada.Command_Line;        use Ada.Command_Line;

with GNAT.Directory_Operations; use GNAT.Directory_Operations;

with Platform;

with XE_Defs;          use XE_Defs;
with XE_Flags;         use XE_Flags;
with XE_IO;            use XE_IO;
with XE_Names;         use XE_Names;

package body XE_Utils is

   type Name_Array is array (Natural range <>) of Name_Id;
   type Name_Array_Ptr is access Name_Array;

   Main_Sources        : Name_Array_Ptr;
   Current_Main_Source : Natural := 1;
   Last_Main_Source    : Natural := 0;

   type Make_Program_Type is (None, Compiler, Binder, Linker);

   Program_Args : Make_Program_Type := None;
   --  Used to indicate if we are scanning gnatmake, gcc, gnatbind, or
   --  gnatbind options within the gnatmake command line.

   procedure Ensure_Make_Args;
   --  Reset Program_Args to None, adding "-margs" to make switches if needed

   Project_File_Name_Expected : Boolean := False;
   --  Used to keep state between invocations of Scan_Dist_Arg. True when
   --  previous argument was "-P".

   function Dup (Fd : File_Descriptor) return File_Descriptor;
   pragma Import (C, Dup);

   procedure Dup2 (Old_Fd, New_Fd : File_Descriptor);
   pragma Import (C, Dup2);

   GNAT_Driver : String_Access;
   GPRBuild    : String_Access;

   List_Command    : constant String_Access := new String'("list");
   Build_Command   : constant String_Access := new String'("make");
   Compile_Command : constant String_Access := new String'("compile");

   function Locate
     (Exec_Name  : String;
      Show_Error : Boolean := True) return String_Access;
   --  look for Exec_Name on the path. If Exec_Name is found then the full
   --  pathname for Exec_Name is returned. If Exec_Name is not found and
   --  Show_Error is set to False then null is returned. If Exec_Name is not
   --  found and Show_Error is set to True then Fatal_Error is raised.

   procedure Add_Make_Switch (Argv : String_Access);
   procedure Add_Make_Switch (Argv : String);
   procedure Add_List_Switch (Argv : String);
   procedure Add_Main_Source (Source : String);
   procedure Add_Source_Directory (Argv : String);

   procedure Fail
     (S1 : String;
      S2 : String := No_Str;
      S3 : String := No_Str);

   type Sigint_Handler is access procedure;
   pragma Convention (C, Sigint_Handler);

   procedure Install_Int_Handler (Handler : Sigint_Handler);
   pragma Import (C, Install_Int_Handler, "__gnat_install_int_handler");
   --  Called by Gnatmake to install the SIGINT handler below

   procedure Sigint_Intercepted;
   pragma Convention (C, Sigint_Intercepted);
   --  Called when the program is interrupted by Ctrl-C to delete the
   --  temporary mapping files and configuration pragmas files.

   procedure Check_User_Provided_S_RPC (Dir : String);
   --  Check whether the given directory contains a user-provided version of
   --  s-rpc.adb, and if so set the global flag User_Provided_S_RPC to True.

   function Is_Project_Switch (S : String) return Boolean;
   --  True if S is a builder command line switch specifying a project file

   ---------
   -- "&" --
   ---------

   function "&"
     (L : File_Name_Type;
      R : File_Name_Type)
     return File_Name_Type is
   begin
      Name_Len := 0;
      if Present (L) then
         Get_Name_String_And_Append (L);
      end if;
      if Present (R) then
         Get_Name_String_And_Append (R);
      end if;
      return Name_Find;
   end "&";

   ---------
   -- "&" --
   ---------

   function "&"
     (L : File_Name_Type;
      R : String) return File_Name_Type
   is
   begin
      Name_Len := 0;
      if Present (L) then
         Get_Name_String_And_Append (L);
      end if;
      Add_Str_To_Name_Buffer (R);
      return Name_Find;
   end "&";

   ---------------------
   -- Add_List_Switch --
   ---------------------

   procedure Add_List_Switch (Argv : String) is
   begin
      List_Switches.Append (new String'(Argv));
   end Add_List_Switch;

   ---------------------
   -- Add_Main_Source --
   ---------------------

   procedure Add_Main_Source (Source : String) is
   begin
      if Main_Sources = null then
         Main_Sources := new Name_Array (1 .. Argument_Count);
      end if;
      Name_Len := 0;
      Add_Str_To_Name_Buffer (Source);
      Last_Main_Source := Last_Main_Source + 1;
      Main_Sources (Last_Main_Source) := Name_Find;
   end Add_Main_Source;

   ---------------------
   -- Add_Make_Switch --
   ---------------------

   procedure Add_Make_Switch (Argv : String_Access) is
   begin
      Make_Switches.Append (Argv);
   end Add_Make_Switch;

   ---------------------
   -- Add_Make_Switch --
   ---------------------

   procedure Add_Make_Switch (Argv : String) is
   begin
      Make_Switches.Append (new String'(Argv));
   end Add_Make_Switch;

   --------------------------
   -- Add_Source_Directory --
   --------------------------

   procedure Add_Source_Directory (Argv : String) is
   begin
      Check_User_Provided_S_RPC (Argv);
      Source_Directories.Append (new String'(Argv));
   end Add_Source_Directory;

   -----------
   -- Build --
   -----------

   procedure Build
     (Library    : File_Name_Type;
      Arguments  : Argument_List;
      Fatal      : Boolean := True;
      Progress   : Boolean := False)
   is
      Length            : constant Positive :=
                            Arguments'Length + 5
                              + Make_Switches.Last
                              - Make_Switches.First;
      Flags             : Argument_List (1 .. Length);
      N_Flags           : Natural := 0;
      Library_Name_Flag : Natural;
      Success           : Boolean;
      Has_Prj           : Boolean := False;
      Index             : Natural;

      Builder : String_Access;
   begin
      if Use_GPRBuild then
         Builder := GPRBuild;

      else
         Builder := GNAT_Driver;

         --  gnat make

         N_Flags := N_Flags + 1;
         Flags (N_Flags) := Build_Command;
      end if;

      if Quiet_Mode then
         --  Pass -q to gnatmake

         N_Flags := N_Flags + 1;
         Flags (N_Flags) := Quiet_Flag;

      elsif Verbose_Mode then
         --  Pass -v to gnatmake

         N_Flags := N_Flags + 1;
         Flags (N_Flags) := Verbose_Flag;
      end if;

      if Progress then
         --  Pass -d to gnatmake

         N_Flags := N_Flags + 1;
         Flags (N_Flags) := Progress_Flag;
      end if;

      --  Library file name (free'd at exit of Compile, must record position
      --  in Flags array).

      N_Flags := N_Flags + 1;
      Get_Name_String (Library);
      Flags (N_Flags) := new String'(Name_Buffer (1 .. Name_Len));
      Library_Name_Flag := N_Flags;

      for I in Arguments'Range loop
         N_Flags := N_Flags + 1;
         Flags (N_Flags) := Arguments (I);

         --  Detect any project file

         if Is_Project_Switch (Arguments (I).all) then
            Has_Prj := True;
         end if;
      end loop;

      Index := Make_Switches.First;
      while Index <= Make_Switches.Last loop

         --  If there is a project file among the arguments then any
         --  project file from the Make switches is ignored.

         if Has_Prj
           and then Is_Project_Switch (Make_Switches.Table (Index).all)
         then
            if Make_Switches.Table (Index).all = Project_File_Flag.all then

               --  Case of "-P" followed by project file name in a separate
               --  argument.

               Index := Index + 1;
            end if;

         else
            N_Flags := N_Flags + 1;
            Flags (N_Flags) := Make_Switches.Table (Index);
         end if;

         Index := Index + 1;
      end loop;

      --  Call gnat make

      Execute (Builder, Flags (1 .. N_Flags), Success);

      --  Free library file name argument

      Free (Flags (Library_Name_Flag));

      if not Success and then Fatal then
         raise Compilation_Error;
      end if;
   end Build;

   ----------------
   -- Capitalize --
   ----------------

   function Capitalize (N : Name_Id) return Name_Id is
   begin
      Get_Name_String (N);
      Capitalize (Name_Buffer (1 .. Name_Len));
      return Name_Find;
   end Capitalize;

   ----------------
   -- Capitalize --
   ----------------

   function Capitalize (S : String) return String is
      R : String := S;
   begin
      Capitalize (R);
      return R;
   end Capitalize;

   ----------------
   -- Capitalize --
   ----------------

   procedure Capitalize (S : in out String) is
      Capitalized : Boolean := True;

   begin
      for J in S'Range loop
         if S (J) in 'a' .. 'z' then
            if Capitalized then
               S (J) := To_Upper (S (J));
            end if;
            Capitalized := False;

         elsif S (J) in 'A' .. 'Z' then
            if not Capitalized then
               S (J) := To_Lower (S (J));
            end if;
            Capitalized := False;

         elsif S (J) = '_' or else S (J) = '.' then
            Capitalized := True;
         end if;
      end loop;
   end Capitalize;

   -------------------------------
   -- Check_User_Provided_S_RPC --
   -------------------------------

   procedure Check_User_Provided_S_RPC (Dir : String) is
   begin
      --  Special kludge: if the user provides his own version of s-rpc, the
      --  PCS should not provide it.

      if Is_Readable_File (Dir & Dir_Separator & "s-rpc.adb") then
         XE_Flags.User_Provided_S_RPC := True;
      end if;
   end Check_User_Provided_S_RPC;

   -------------
   -- Compile --
   -------------

   procedure Compile
     (Source    : File_Name_Type;
      Arguments : Argument_List;
      Fatal     : Boolean := True)
   is
      Length  : constant Natural :=
                  Arguments'Length + 5
                    + Make_Switches.Last
                    - Make_Switches.First;
      Flags   : Argument_List (1 .. Length);
      N_Flags : Natural := 0;
      Success : Boolean;
      Has_Prj : Boolean := False;
      Index   : Natural;

   begin
      --  gnat compile

      N_Flags := N_Flags + 1;
      Flags (N_Flags) := Compile_Command;

      --  Source file name (free'd at exit of Compile, must be at constant
      --  position in Flags array).

      N_Flags := N_Flags + 1;
      Get_Name_String (Source);
      Flags (N_Flags) :=
        new String'(Normalize_Pathname
                      (Name_Buffer (1 .. Name_Len),
                       Resolve_Links => Resolve_Links));

      --  Check whether we have a predefined unit

      Name_Len := 0;
      Add_Str_To_Name_Buffer (Strip_Directory (Flags (N_Flags).all));
      if Name_Len > 2
        and then Name_Buffer (2) = '-'
        and then (Name_Buffer (1) = 'a'
                  or else Name_Buffer (1) = 'g'
                  or else Name_Buffer (1) = 's')
      then
         N_Flags := N_Flags + 1;
         Flags (N_Flags) := Readonly_Flag;
      end if;

      if Quiet_Mode then
         --  Pass -q to gnatmake

         N_Flags := N_Flags + 1;
         Flags (N_Flags) := Quiet_Flag;

      elsif Verbose_Mode then
         --  Pass -v to gnatmake

         N_Flags := N_Flags + 1;
         Flags (N_Flags) := Verbose_Flag;
      end if;

      for I in Arguments'Range loop
         N_Flags := N_Flags + 1;
         Flags (N_Flags) := Arguments (I);

         --  Detect any project file

         if Is_Project_Switch (Arguments (I).all) then
            Has_Prj := True;
         end if;
      end loop;

      Index := Make_Switches.First;
      while Index <= Make_Switches.Last loop

         --  If there is a project file among the arguments then any
         --  project file from the Make switches is ignored.

         if Has_Prj
           and then Is_Project_Switch (Make_Switches.Table (Index).all)
         then
            if Make_Switches.Table (Index).all = Project_File_Flag.all then

               --  Case of "-P" followed by project file name in a separate
               --  argument.

               Index := Index + 1;
            end if;

         else
            N_Flags := N_Flags + 1;
            Flags (N_Flags) := Make_Switches.Table (Index);
         end if;

         Index := Index + 1;
      end loop;

      Execute (GNAT_Driver, Flags (1 .. N_Flags), Success);

      --  Free source file name argument

      Free (Flags (2));

      if not Success and then Fatal then
         raise Compilation_Error;
      end if;
   end Compile;

   ----------------------
   -- Ensure_Make_Args --
   ----------------------

   procedure Ensure_Make_Args is
   begin
      if Program_Args /= None then
         Add_Make_Switch (Make_Args_Flag);
         Program_Args := None;
      end if;
   end Ensure_Make_Args;

   -------------
   -- Execute --
   -------------

   procedure Execute
     (Command   : String_Access;
      Arguments : Argument_List;
      Success   : out Boolean)
   is
   begin
      if not Quiet_Mode then
         Set_Standard_Error;
         Write_Str (Command.all);
         for J in Arguments'Range loop
            if Arguments (J) /= null then
               Write_Str (" ");
               Write_Str (Arguments (J).all);
            end if;
         end loop;
         Write_Eol;
         Set_Standard_Output;
      end if;

      Spawn (Command.all, Arguments, Success);
   end Execute;

   ------------------
   -- Exit_Program --
   ------------------

   procedure Exit_Program (Code : Exit_Code_Type) is
      Status : Integer := 0;

   begin
      Remove_All_Temp_Files;
      if Code /= E_Success then
         Status := 1;
      end if;
      OS_Exit (Status);
   end Exit_Program;

   ----------
   -- Fail --
   ----------

   procedure Fail
     (S1 : String;
      S2 : String := No_Str;
      S3 : String := No_Str) is
   begin
      Write_Program_Name;
      Write_Str (": ");
      Write_Str (S1);
      Write_Str (S2);
      Write_Str (S3);
      Write_Eol;
      raise Usage_Error;
   end Fail;

   --------
   -- Id --
   --------

   function Id (S : String) return Name_Id is
   begin
      if S'Length = 0 then
         return No_Name;
      end if;
      Name_Buffer (1 .. S'Length) := S;
      Name_Len := S'Length;

      return Name_Find;
   end Id;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize is
   begin
      XE_Names.Initialize;
      Set_Space_Increment (3);

      Cfg_Suffix_Id  := Id (Cfg_Suffix);
      Obj_Suffix_Id  := Id (Obj_Suffix);
      Exe_Suffix_Id  := Id (Exe_Suffix);
      ALI_Suffix_Id  := Id (ALI_Suffix);
      ADB_Suffix_Id  := Id (ADB_Suffix);
      ADS_Suffix_Id  := Id (ADS_Suffix);
      Root_Id        := Dir (Id (Root), Id (Platform.Target));
      Part_Dir_Name  := Dir (Root_Id, Id ("partitions"));
      Stub_Dir_Name  := Dir (Root_Id, Id ("stubs"));
      Stub_Dir       := new String'(Name_Buffer (1 .. Name_Len));
      PWD_Id         := Dir (Id ("`pwd`"), No_File_Name);
      I_Current_Dir  := new String'("-I.");
      E_Current_Dir  := new String'("-I-");

      Monolithic_Obj_Dir  := Dir (Root_Id, Id ("obj"));

      PCS_Project        := Id ("pcs_project");
      Set_Corresponding_Project_File_Name (PCS_Project_File);

      Part_Main_Src_Name := Id ("partition" & ADB_Suffix);
      Part_Main_ALI_Name := To_Afile (Part_Main_Src_Name);
      Part_Main_Obj_Name := To_Ofile (Part_Main_Src_Name);

      Part_Prj_File_Name := Id ("partition.gpr");

      Overridden_PCS_Units := Id ("pcs_excluded.lst");

      Name_Len := 2;
      Name_Buffer (1 .. 2) := "-A";
      Get_Name_String_And_Append (Stub_Dir_Name);
      A_Stub_Dir := new String'(Name_Buffer (1 .. Name_Len));

      for J in 1 .. Argument_Count loop
         Scan_Dist_Arg (Argument (J), Implicit => False);
      end loop;

      if Project_File_Name_Expected then
         Fail ("project file name missing after -P");
      end if;

      if Check_Readonly_Files and then Project_File_Name = null then
         --  If the user asks for recompilation of files with read-only ALIs
         --  (in practice recompilation of the GNAT runtime), and no project
         --  has been provided, then assume that additional files to be
         --  recompiled won't be covered by the generated project, and pass
         --  extra flag to gnatmake to allow compiling them anyway.

         Ensure_Make_Args;
         Add_Make_Switch (External_Units_Flag);
      end if;

      XE_Defs.Initialize;

      Install_Int_Handler (Sigint_Intercepted'Access);

      Create_Dir (Monolithic_Obj_Dir);
      Create_Dir (Stub_Dir_Name);
      Create_Dir (Part_Dir_Name);

      if Platform.Is_Cross then
         GNAT_Driver := Locate (Platform.Target & "-gnat");
      else
         GNAT_Driver := Locate ("gnat");
      end if;

      --  Note: we initialize variable GPRBuild in Scan_Dist_Arg rather than
      --  unconditionally in Initialize so that the absence of gprbuild does
      --  not cause initialization to fail in the normal case where -dB is not
      --  used.

      Check_User_Provided_S_RPC (".");
   end Initialize;

   -----------------------
   -- Is_Project_Switch --
   -----------------------

   function Is_Project_Switch (S : String) return Boolean is
      Fl : String renames Project_File_Flag.all;
   begin
      return S'Length >= Fl'Length
               and then S (S'First .. S'First + Fl'Length - 1) = Fl;
   end Is_Project_Switch;

   ----------
   -- List --
   ----------

   procedure List
     (Sources   : File_Name_List;
      Arguments : Argument_List;
      Output    : out File_Name_Type;
      Fatal     : Boolean := True)
   is
      Length  : constant Natural :=
        Sources'Length + 4
        + Arguments'Length
        + List_Switches.Last
        - List_Switches.First;
      Flags   : Argument_List (1 .. Length);
      N_Flags : Natural := 0;
      File    : GNAT.OS_Lib.File_Descriptor;
      Success : Boolean;
      Result  : File_Name_Type := No_File_Name;
      Has_Prj : Boolean := False;
      Index   : Natural;
      Predef  : Boolean := False;

      Saved_Standout : File_Descriptor;

   begin
      --  gnat list

      N_Flags := N_Flags + 1;
      Flags (N_Flags) := List_Command;

      --  Source file names (free'd at exit of List, must be at constant
      --  position in Flags array).

      for J in Sources'Range loop
         N_Flags := N_Flags + 1;
         Get_Name_String (Sources (J));
         Flags (N_Flags) := new String'(Name_Buffer (1 .. Name_Len));

         Predef := Predef or else Is_Predefined_File (Sources (J));
      end loop;

      if Predef then
         N_Flags := N_Flags + 1;
         Flags (N_Flags) := Readonly_Flag;
      end if;

      --  -q (because gnatmake is verbose instead of gcc)

      N_Flags := N_Flags + 1;
      Flags (N_Flags) := Quiet_Flag;

      for I in Arguments'Range loop
         N_Flags := N_Flags + 1;
         Flags (N_Flags) := Arguments (I);

         --  Detect any project file

         if Is_Project_Switch (Arguments (I).all) then
            Has_Prj := True;
         end if;
      end loop;

      Index := List_Switches.First;
      while Index <= List_Switches.Last loop

         --  If there is a project file among the arguments then any
         --  project file from the List switches is ignored.

         if Has_Prj
           and then Is_Project_Switch (List_Switches.Table (Index).all)
         then
            if List_Switches.Table (Index).all = Project_File_Flag.all then

               --  Case of "-P" followed by project file name in a separate
               --  argument.

               Index := Index + 1;
            end if;

         else
            N_Flags := N_Flags + 1;
            Flags (N_Flags) := List_Switches.Table (Index);
         end if;

         Index := Index + 1;
      end loop;

      Register_Temp_File (File, Result);
      Saved_Standout := Dup (Standout);
      Dup2 (File, Standout);

      Execute (GNAT_Driver, Flags (1 .. N_Flags), Success);

      Dup2 (Saved_Standout, Standout);
      Close (Saved_Standout);

      if not Success then
         if Fatal then
            raise Program_Error;
         end if;
         Remove_Temp_File (Result);
      end if;

      --  Free source filename arguments

      N_Flags := 1;
      for J in Sources'Range loop
         N_Flags := N_Flags + 1;
         Free (Flags (N_Flags));
      end loop;

      Output := Result;
   end List;

   ------------
   -- Locate --
   ------------

   function Locate
     (Exec_Name  : String;
      Show_Error : Boolean := True)
      return String_Access
   is
      Loc : String_Access;
   begin
      Name_Len := Exec_Name'Length;
      Name_Buffer (1 .. Name_Len) := Exec_Name;
      declare
         Exe : constant String := Name_Buffer (1 .. Name_Len);
      begin
         Loc := GNAT.OS_Lib.Locate_Exec_On_Path (Exe);
         if Loc = null and then Show_Error then
            raise Fatal_Error with Exe & " is not in your path";
         end if;
      end;
      return Loc;
   end Locate;

   -----------------------
   -- More_Source_Files --
   -----------------------

   function More_Source_Files return Boolean is
   begin
      return Current_Main_Source <= Last_Main_Source;
   end More_Source_Files;

   ----------
   -- Name --
   ----------

   function Name (N : Name_Id) return Name_Id is
   begin
      Get_Name_String (N);
      if Name_Len > 1
        and then Name_Buffer (Name_Len - 1) = '%'
      then
         Name_Len := Name_Len - 2;
         return Name_Find;
      end if;
      return N;
   end Name;

   ----------------------
   -- Next_Main_Source --
   ----------------------

   function Next_Main_Source return Name_Id is
      Source : Name_Id := No_Name;

   begin
      if Current_Main_Source <= Last_Main_Source then
         Source := Main_Sources (Current_Main_Source);
         Current_Main_Source := Current_Main_Source + 1;
      end if;
      return Source;
   end Next_Main_Source;

   --------
   -- No --
   --------

   function No (N : Name_Id) return Boolean is
   begin
      return N = No_Name;
   end No;

   ---------------------
   -- Number_Of_Files --
   ---------------------

   function Number_Of_Files return Natural is
   begin
      return Last_Main_Source;
   end Number_Of_Files;

   -------------
   -- Present --
   -------------

   function Present (N : Name_Id) return Boolean is
   begin
      return N /= No_Name;
   end Present;

   -----------
   -- Quote --
   -----------

   function Quote (N : Name_Id) return Name_Id is
   begin
      Name_Len := 0;
      Add_Char_To_Name_Buffer ('"'); -- "
      if Present (N) then
         Get_Name_String_And_Append (N);
      end if;
      Add_Char_To_Name_Buffer ('"'); -- "
      return Name_Find;
   end Quote;

   -------------------
   -- Scan_Dist_Arg --
   -------------------

   procedure Scan_Dist_Arg (Argv : String; Implicit : Boolean := True) is
   begin
      if Argv'Length = 0 then
         return;
      end if;

      if Argv = "-cargs" then
         Program_Args := Compiler;
         Add_Make_Switch (Comp_Args_Flag);
         return;

      elsif Argv = "-bargs" then
         Program_Args := Binder;
         Add_Make_Switch (Bind_Args_Flag);
         return;

      elsif Argv = "-largs" then
         Program_Args := Linker;
         Add_Make_Switch (Link_Args_Flag);
         return;

      elsif Argv = "-margs" then
         Program_Args := None;
         Add_Make_Switch (Make_Args_Flag);
         return;
      end if;

      case Program_Args is
         when Compiler | Binder | Linker =>
            Add_Make_Switch (Argv);
            return;
         when others =>
            null;
      end case;

      if Project_File_Name_Expected then
         Project_File_Name :=
           new String'(Normalize_Pathname (Argv,
                                           Resolve_Links => Resolve_Links));
         Add_List_Switch (Project_File_Name.all);
         Add_Make_Switch (Project_File_Name.all);
         Project_File_Name_Expected := False;

      elsif Argv (Argv'First) = '-' then

         if Argv'Length = 1 then
            Fail ("switch character cannot be followed by a blank");

         --  Processing for -I-

         elsif Argv = "-I-" then
            Add_List_Switch (Argv);
            Add_Make_Switch (Argv);

         --  Forbid -?- or -??- where ? is any character

         elsif Argv'Length in 3 .. 4 and then Argv (Argv'Last) = '-' then
            Fail ("Trailing ""-"" at the end of ", Argv, " forbidden.");

         --  Processing for -Adir, -Idir and -Ldir

         elsif Argv (Argv'First + 1) = 'A'
           or else Argv (Argv'First + 1) = 'I'
           or else Argv (Argv'First + 1) = 'L'
         then
            Add_List_Switch (Argv);
            Add_Make_Switch (Argv);
            if Argv (Argv'First + 1) = 'I' and then not Implicit then
               Add_Source_Directory (Argv (Argv'First + 2 .. Argv'Last));
            end if;

         --  Processing for -aIdir, -aLdir, -aOdir, -aPdir

         elsif Argv'Length >= 3
           and then Argv (Argv'First + 1) = 'a'
           and then (Argv (Argv'First + 2) = 'I'
             or else Argv (Argv'First + 2) = 'L'
             or else Argv (Argv'First + 2) = 'O'
             or else Argv (Argv'First + 2) = 'P')
         then
            Add_List_Switch (Argv);
            Add_Make_Switch (Argv);

            if Argv (Argv'First + 2) = 'I' and then not Implicit then
               Add_Source_Directory (Argv (Argv'First + 3 .. Argv'Last));
            end if;

         elsif Argv (Argv'First + 1) = 'P' then

            if Project_File_Name_Expected
                 or else Project_File_Name /= null
            then
               Fail ("cannot have several project files specified");
            end if;

            if Argv'Length > 2 then
               Project_File_Name :=
                 new String'(Normalize_Pathname
                              (Argv (Argv'First + 2 .. Argv'Last),
                               Resolve_Links => Resolve_Links));
               Add_List_Switch (Project_File_Flag.all);
               Add_List_Switch (Project_File_Name.all);
               Add_Make_Switch (Project_File_Flag.all);
               Add_Make_Switch (Project_File_Name.all);

            else
               Project_File_Name_Expected := True;
               Add_List_Switch (Project_File_Flag.all);
               Add_Make_Switch (Project_File_Flag.all);
            end if;

         elsif Argv (Argv'First + 1) = 'e' then
            Add_List_Switch (Argv);
            Add_Make_Switch (Argv);

            if Argv'Length = 3 and then Argv (Argv'Last) = 'L' then
               Resolve_Links := True;
            end if;

         --  Debugging switches

         elsif Argv (Argv'First + 1) = 'd' then

            --  -d: debugging traces

            if Argv'Length = 2 then
               Display_Compilation_Progress := True;

            else
               case Argv (Argv'First + 2) is
                  --  -dd: debug mode

                  when 'd' =>
                     Debug_Mode := True;

                  --  -df: output base names only in error messages (to ensure
                  --       constant output for testsuites).

                  when 'f' =>
                     Add_Make_Switch ("-df");

                  --  -dP: Force using project files to reference the PolyORB
                  --       PCS even on non-Windows platforms.

                  when 'P' =>
                     Use_PolyORB_Project := True;

                  --  -dB: Use gprbuild (implies -dP)
                  --       (for experimentation, not expected to work yet???)

                  when 'B' =>
                     GPRBuild := Locate ("gprbuild");
                     Use_GPRBuild := True;
                     Use_PolyORB_Project := True;

                  when others =>
                     --  Pass other debugging flags to the builder untouched

                     Add_Make_Switch (Argv);
               end case;
            end if;

         --  Processing for one character switches

         elsif Argv'Length = 2 then
            case Argv (Argv'First + 1) is
               when 'a' =>
                  Check_Readonly_Files := True;
                  Add_List_Switch (Argv);
                  Add_Make_Switch (Argv);

               when 'k' =>
                  Keep_Going := True;
                  Add_Make_Switch (Argv);

               when 't' =>
                  Keep_Tmp_Files := True;
                  Add_Make_Switch ("-dn");

               when 'q' =>
                  Quiet_Mode := True;
                  --  Switch is passed to gnatmake later on

               when 'v' =>
                  Verbose_Mode := True;
                  --  Switch is passed to gnatmake later on

               when others =>
                  --  Pass unrecognized switches to gnat make and gnat ls

                  Add_List_Switch (Argv);
                  Add_Make_Switch (Argv);
            end case;

         --  Processing for --PCS=

         elsif Argv'Length > 6
           and then Argv (Argv'First + 1 .. Argv'First + 5) = "-PCS="
         then
            Set_PCS_Name (Argv (Argv'First + 6 .. Argv'Last));

         --  Processing for --RTS=

         elsif Argv'Length > 6
           and then Argv (Argv'First + 1 .. Argv'First + 5) = "-RTS="
         then
            Add_List_Switch (Argv);
            Add_Make_Switch (Argv);

         --  Pass all unrecognized switches on to gnat make and gnat ls

         else
            Add_List_Switch (Argv);
            Add_Make_Switch (Argv);
         end if;

      else
         Add_Main_Source (Argv);
      end if;
   end Scan_Dist_Arg;

   --------------------
   -- Scan_Dist_Args --
   --------------------

   procedure Scan_Dist_Args (Args : String) is
      Argv : Argument_List_Access := Argument_String_To_List (Args);
   begin
      --  We have already processed the user command line: we might be in the
      --  -cargs or -largs section. If so, switch back to -margs now.

      Ensure_Make_Args;
      for J in Argv'Range loop
         if Argv (J)'Length > 0 then
            Scan_Dist_Arg (Argv (J).all);
         end if;
      end loop;
      Free (Argv);
   end Scan_Dist_Args;

   -----------------------------------------
   -- Set_Corresponding_Project_File_Name --
   -----------------------------------------

   procedure Set_Corresponding_Project_File_Name (N : out File_Name_Type) is
   begin
      Add_Str_To_Name_Buffer (".gpr");
      N := Name_Find;
   end Set_Corresponding_Project_File_Name;

   --------------------
   -- Show_Dist_Args --
   --------------------

   procedure Show_Dist_Args is
   begin
      for J in Make_Switches.First .. Make_Switches.Last loop
         Message ("make = " & Make_Switches.Table (J).all);
      end loop;
      for J in List_Switches.First .. List_Switches.Last loop
         Message ("list = " & List_Switches.Table (J).all);
      end loop;
   end Show_Dist_Args;

   ------------------------
   -- Sigint_Intercepted --
   ------------------------

   procedure Sigint_Intercepted is
   begin
      Exit_Program (E_Fatal);
   end Sigint_Intercepted;

   --------------
   -- To_Lower --
   --------------

   procedure To_Lower (S : in out String) is
   begin
      for J in S'Range loop
         S (J) := To_Lower (S (J));
      end loop;
   end To_Lower;

   --------------
   -- To_Lower --
   --------------

   procedure To_Lower (N : in out Name_Id) is
   begin
      Get_Name_String (N);
      To_Lower (Name_Buffer (1 .. Name_Len));
      N := Name_Find;
   end To_Lower;

   --------------
   -- To_Lower --
   --------------

   function To_Lower (N : Name_Id) return Name_Id is
   begin
      Get_Name_String (N);
      To_Lower (Name_Buffer (1 .. Name_Len));
      return Name_Find;
   end To_Lower;

   ---------------------------
   -- Set_Application_Names --
   ---------------------------

   procedure Set_Application_Names (Configuration_Name : Name_Id) is
   begin
      Get_Name_String (Configuration_Name);
      To_Lower (Name_Buffer (1 .. Name_Len));
      Add_Str_To_Name_Buffer ("_monolithic_app");

      Monolithic_App_Unit_Name := Name_Find;

      Add_Str_To_Name_Buffer (ADB_Suffix);
      Monolithic_Src_Base_Name := Name_Find;

      Monolithic_Src_Name := Dir (Root_Id, Monolithic_Src_Base_Name);
      Monolithic_ALI_Name := To_Afile (Monolithic_Src_Name);
      Monolithic_Obj_Name := To_Ofile (Monolithic_Src_Name);

      Get_Name_String (Configuration_Name);
      To_Lower (Name_Buffer (1 .. Name_Len));
      Add_Str_To_Name_Buffer ("_dist_app");
      Dist_App_Project := Name_Find;

      Set_Corresponding_Project_File_Name (Dist_App_Project_File);
   end Set_Application_Names;

   ------------------------
   -- Write_Missing_File --
   ------------------------

   procedure Write_Missing_File (Fname : File_Name_Type) is
   begin
      Message ("file", Fname, "does not exist");
   end Write_Missing_File;

   ----------------------------
   -- Write_Warnings_Pragmas --
   ----------------------------

   procedure Write_Warnings_Pragmas is
   begin
      --  Turn off warnings

      Write_Line ("pragma Warnings (Off);");

      --  Turn off style checks and set maximum line length to the largest
      --  supported value.

      Write_Line ("pragma Style_Checks (""NM32766"");");
   end Write_Warnings_Pragmas;

end XE_Utils;
