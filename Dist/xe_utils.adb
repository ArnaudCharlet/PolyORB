------------------------------------------------------------------------------
--                                                                          --
--                            GLADE COMPONENTS                              --
--                                                                          --
--                             X E _ U T I L S                              --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--                            $Revision$                             --
--                                                                          --
--         Copyright (C) 1996-1998 Free Software Foundation, Inc.           --
--                                                                          --
-- GNATDIST is  free software;  you  can redistribute  it and/or  modify it --
-- under terms of the  GNU General Public License  as published by the Free --
-- Software  Foundation;  either version 2,  or  (at your option) any later --
-- version. GNATDIST is distributed in the hope that it will be useful, but --
-- WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHANTABI- --
-- LITY or FITNESS  FOR A PARTICULAR PURPOSE.  See the  GNU General  Public --
-- License  for more details.  You should  have received a copy of the  GNU --
-- General Public License distributed with  GNATDIST; see file COPYING.  If --
-- not, write to the Free Software Foundation, 59 Temple Place - Suite 330, --
-- Boston, MA 02111-1307, USA.                                              --
--                                                                          --
--                 GLADE  is maintained by ACT Europe.                      --
--                 (email: glade-report@act-europe.fr)                      --
--                                                                          --
------------------------------------------------------------------------------

with System;
with Unchecked_Deallocation;

with GNAT.OS_Lib;    use GNAT.OS_Lib;
with Csets;          use Csets;
with Debug;          use Debug;
with Make;           use Make;
with Namet;          use Namet;
with Opt;
with Osint;          use Osint;
with Output;         use Output;
with XE;             use XE;
with XE_Defs;        use XE_Defs;

with Ada.Command_Line; use Ada.Command_Line;

pragma Elaborate_All (Csets, Debug, Make, Namet, Opt, Osint, Output);

package body XE_Utils is

   Path         : constant String_Access := GNAT.OS_Lib.Getenv ("PATH");

   GNAT_Verbose   : String_Access;
   Gcc            : String_Access;
   Mkdir          : String_Access;
   Copy           : String_Access;
   Link           : String_Access;
   Chmod          : String_Access;
   Rm             : String_Access;
   Gnatbind       : String_Access;
   Gnatlink       : String_Access;
   Gnatmake       : String_Access;

   Up_To_Low : constant := Character'Pos ('A') - Character'Pos ('a');

   EOL : constant String := (1 => Ascii.LF);

   Output_Flag           : constant String_Access := new String' ("-o");
   Preserve              : constant String_Access := new String' ("-p");
   Symbolic              : constant String_Access := new String' ("-s");
   Force                 : constant String_Access := new String' ("-f");
   Compile_Flag          : constant String_Access := new String' ("-c");
   Exclude_File_Flag     : constant String_Access := new String' ("-x");
   Receiver_Compile_Flag : constant String_Access := new String' ("-gnatzr");
   Caller_Compile_Flag   : constant String_Access := new String' ("-gnatzc");

   Special_File_Flag     : constant String_Access := new String' ("-x");
   Ada_File_Flag         : constant String_Access := new String' ("ada");

   Object_Suffix         : String_Access;
   Executable_Suffix     : String_Access;

   Private_Id            : Name_Id;
   Caller_Id             : Name_Id;
   Receiver_Id           : Name_Id;

   Sem_Only_Flag    : constant String_Access := new String' ("-gnatc");
   --  Workaround : bad object file generated during stub generation

   No_Args          : constant Argument_List (1 .. 0) := (others => null);

   ---------
   -- "&" --
   ---------

   function "&" (Prefix, Suffix : Name_Id) return Name_Id is
   begin
      if Prefix = No_Name then
         return Suffix;
      elsif Suffix = No_Name then
         return Prefix;
      end if;
      Get_Name_String (Prefix);
      Get_Name_String_And_Append (Suffix);
      return Name_Find;
   end "&";

   function Locate
     (Exec_Name  : String;
      Show_Error : Boolean := True)
     return String_Access;

   ----------------
   -- Change_Dir --
   ----------------

   procedure Change_Dir (To : in File_Name_Type) is

      C_Path : String (1 .. Strlen (To) + 1);

      function Chdir (Path : System.Address) return Int;
      pragma Import (C, Chdir, "chdir");

   begin

      if Debug_Mode then
         Message ("change to dir ", To);
      end if;

      Get_Name_String (To);
      C_Path (1 .. Name_Len) := Name_Buffer (1 .. Name_Len);
      C_Path (Name_Len + 1) := Ascii.Nul;
      if Chdir (C_Path'Address) /= 0 then
         Message ("cannot change dir to ", To);
         raise Fatal_Error;
      end if;

      if Building_Script then
         if Name_Len < 3 or else Name_Buffer (1 .. 3) /= "../" then
            Write_Str  (Standout, "if test ! -d ");
            Write_Name (Standout, To);
            Write_Str  (Standout, "; then mkdir -p ");
            Write_Name (Standout, To);
            Write_Str  (Standout, "; fi");
            Write_Eol  (Standout);
         end if;
         Write_Str  (Standout, "cd ");
         Write_Name (Standout, To);
         Write_Eol  (Standout);
      end if;

   end Change_Dir;

   ------------------------
   -- Compile_RCI_Caller --
   ------------------------

   procedure Compile_RCI_Caller (Source, Object : in File_Name_Type) is
   begin
      Execute_Gcc
        (Source,
         Object,
         (Caller_Compile_Flag,
          I_GARLIC_Dir)
         );
   end Compile_RCI_Caller;

   --------------------------
   -- Compile_RCI_Receiver --
   --------------------------

   procedure Compile_RCI_Receiver (Source, Object : in File_Name_Type) is
   begin
      Execute_Gcc
        (Source,
         Object,
         (Receiver_Compile_Flag,
          I_GARLIC_Dir)
         );
   end Compile_RCI_Receiver;

   --------------------------
   -- Copy_With_File_Stamp --
   --------------------------

   procedure Copy_With_File_Stamp
     (Source, Target : in File_Name_Type;
      Maybe_Symbolic : in Boolean := False) is
      S : String_Access := new String (1 .. Strlen (Source));
      T : String_Access := new String (1 .. Strlen (Target));
      procedure Free is new Unchecked_Deallocation (String, String_Access);
   begin
      Get_Name_String (Source);
      S.all := Name_Buffer (1 .. Name_Len);
      Get_Name_String (Target);
      T.all := Name_Buffer (1 .. Name_Len);
      if Link = null then
         Execute (Copy, (Preserve, S, T));
      else
         Execute (Rm, (Force, T));
         if Maybe_Symbolic then
            Execute (Link, (Symbolic, S, T));
         else
            Execute (Link, (S, T));
         end if;
      end if;
      Free (S);
      Free (T);
   end Copy_With_File_Stamp;

   ------------
   -- Create --
   ------------

   procedure Create
     (File : in out File_Descriptor;
      Name : in File_Name_Type;
      Exec : in Boolean := False) is
      File_Name_Len : Natural := Strlen (Name);
      File_Name     : String (1 .. File_Name_Len + 1);
   begin
      Get_Name_String (Name);
      File_Name (1 .. File_Name_Len) := Name_Buffer (1 .. Name_Len);
      File_Name (File_Name_Len + 1) := Ascii.Nul;

      if Verbose_Mode then
         Message ("creating file ", Name);
      end if;

      File := Create_File (File_Name'Address, Text);

      if File = Invalid_FD then
         Message ("cannot create file ", Name);
         raise Fatal_Error;
      end if;

      if Exec then
         Execute
           (Chmod,
            (1 => new String'("u+x"),
             2 => new String'(File_Name (1 .. File_Name_Len))));
      end if;

   end Create;

   ----------------
   -- Create_Dir --
   ----------------

   procedure Create_Dir (To : in File_Name_Type) is
      Dir_Name_Len : Natural := Strlen (To);
      Dir_Name     : String (1 .. Dir_Name_Len);
   begin

      Get_Name_String (To);
      Dir_Name := Name_Buffer (1 .. Name_Len);
      for Index in Dir_Name'Range loop

         --  XXXXX
         if Dir_Name (Index) = Separator and then Index > 1 and then
            not Is_Directory (Dir_Name (1 .. Index - 1)) then
            Execute (Mkdir, (1 => new String'(Dir_Name (1 .. Index - 1))));
         elsif Index = Dir_Name'Last then
            Execute (Mkdir, (1 => new String'(Dir_Name)));
         end if;
      end loop;

   end Create_Dir;

   ------------
   -- Delete --
   ------------

   procedure Delete (File : in File_Name_Type) is
      Error : Boolean;
   begin
      if Verbose_Mode then
         Message ("deleting ", File);
      end if;
      Get_Name_String (File);
      Name_Len := Name_Len + 1;
      Name_Buffer (Name_Len) := Ascii.Nul;
      Delete_File (Name_Buffer'Address, Error);
   end Delete;

   -------------
   -- Execute --
   -------------

   procedure Execute
     (Prog : in String_Access;
      Args : in Argument_List) is
      Success : Boolean := False;
   begin

      if Verbose_Mode or else Building_Script then
         if Building_Script then
            Write_Str (Standout, Prog.all);
         else
            Write_Str (Prog.all);
         end if;
         for Index in Args'Range loop
            if Args (Index) /= null then
               if Building_Script then
                  Write_Str (Standout, " ");
                  Write_Str (Standout, Args (Index).all);
               else
                  Write_Str (" ");
                  Write_Str (Args (Index).all);
               end if;
            end if;
         end loop;
         if Building_Script then
            Write_Eol (Standout);
         else
            Write_Eol;
         end if;
      end if;

      Spawn (Prog.all, Args, Success);

      if not Success then
         Message ("", No_Name, Prog.all, No_Name, " failed");
         raise Fatal_Error;
      end if;

   end Execute;

   ------------------
   -- Execute_Bind --
   ------------------

   procedure Execute_Bind
     (Lib  : in File_Name_Type;
      Args : in Argument_List) is


      Length : constant Positive :=
        Args'Length + Binder_Switches.Last - Binder_Switches.First + 3;

      Bind_Flags   : Argument_List (1 .. Length);

      Lib_Name     : String (1 .. Strlen (Lib));

      N_Bind_Flags : Natural range 0 .. Length := 0;

   begin

      N_Bind_Flags := N_Bind_Flags + 1;
      Bind_Flags (N_Bind_Flags) := Exclude_File_Flag;

      --  various arguments

      for I in Args'Range loop
         N_Bind_Flags := N_Bind_Flags + 1;
         Bind_Flags (N_Bind_Flags) := Args (I);
      end loop;

      for I in Binder_Switches.First .. Binder_Switches.Last loop
         N_Bind_Flags := N_Bind_Flags + 1;
         Bind_Flags (N_Bind_Flags) := Binder_Switches.Table (I);
      end loop;

      --  <unit name>

      Get_Name_String (Lib);
      Lib_Name := Name_Buffer (1 .. Name_Len);
      N_Bind_Flags := N_Bind_Flags + 1;
      Bind_Flags (N_Bind_Flags) := new String'(Lib_Name);

      --  Call gnatbind

      Execute (Gnatbind, Bind_Flags (1 .. N_Bind_Flags));

   end Execute_Bind;

   -----------------
   -- Execute_Gcc --
   -----------------

   procedure Execute_Gcc
     (File   : in File_Name_Type;
      Object : in File_Name_Type;
      Args   : in Argument_List) is

      Length      : constant Natural
        := Gcc_Switches.Last - Gcc_Switches.First + 6 + Args'Length + 2;

      File_Name   : String_Access;
      Object_Name : String_Access;

      Gcc_Flags   : Argument_List (1 .. Length);

      N_Gcc_Flags : Natural range 0 .. Length := 0;

   begin

      N_Gcc_Flags := N_Gcc_Flags + 1;
      Gcc_Flags (N_Gcc_Flags) := Special_File_Flag;

      N_Gcc_Flags := N_Gcc_Flags + 1;
      Gcc_Flags (N_Gcc_Flags) := Ada_File_Flag;

      N_Gcc_Flags := N_Gcc_Flags + 1;
      Gcc_Flags (N_Gcc_Flags) := Compile_Flag;

      N_Gcc_Flags := N_Gcc_Flags + 1;
      Get_Name_String (File);
      File_Name := new String'(Name_Buffer (1 .. Name_Len));
      Gcc_Flags (N_Gcc_Flags) := File_Name;

      N_Gcc_Flags := N_Gcc_Flags + 1;
      Gcc_Flags (N_Gcc_Flags) := Output_Flag;

      N_Gcc_Flags := N_Gcc_Flags + 1;
      Get_Name_String (Object);
      Object_Name := new String'(Name_Buffer (1 .. Name_Len));
      Gcc_Flags (N_Gcc_Flags) := Object_Name;

      for I in Args'Range loop
         N_Gcc_Flags := N_Gcc_Flags + 1;
         Gcc_Flags (N_Gcc_Flags) := Args (I);
      end loop;

      for I in Gcc_Switches.First .. Gcc_Switches.Last loop
         N_Gcc_Flags := N_Gcc_Flags + 1;
         Gcc_Flags (N_Gcc_Flags) := Gcc_Switches.Table (I);
      end loop;

      N_Gcc_Flags := N_Gcc_Flags + 1;
      Gcc_Flags (N_Gcc_Flags) := I_Current_Dir;

      Execute (Gcc, Gcc_Flags);

      Free (File_Name);
      Free (Object_Name);

   end Execute_Gcc;

   ------------------
   -- Execute_Link --
   ------------------

   procedure Execute_Link
     (Lib  : in File_Name_Type;
      Exec : in File_Name_Type;
      Args : in Argument_List) is


      Length : constant Positive :=
        2 +            --  -o <executable name>
        1 +            --  <unit_name>
        Args'Length +
        Linker_Switches.Last - Linker_Switches.First + 1;

      Link_Flags   : Argument_List (1 .. Length);

      Lib_Name     : String (1 .. Strlen (Lib));
      Exec_Name    : String (1 .. Strlen (Exec));

      N_Link_Flags : Natural range 0 .. Length := 0;

   begin

      --  -o <executable name>

      Get_Name_String (Exec);
      Exec_Name := Name_Buffer (1 .. Name_Len);
      N_Link_Flags := N_Link_Flags + 1;
      Link_Flags (N_Link_Flags) := Output_Flag;
      N_Link_Flags := N_Link_Flags + 1;
      Link_Flags (N_Link_Flags) := new String'(Exec_Name);

      --  various arguments

      for I in Args'Range loop
         N_Link_Flags := N_Link_Flags + 1;
         Link_Flags (N_Link_Flags) := Args (I);
      end loop;

      --  <unit name>

      Get_Name_String (Lib);
      Lib_Name := Name_Buffer (1 .. Name_Len);
      N_Link_Flags := N_Link_Flags + 1;
      Link_Flags (N_Link_Flags) := new String'(Lib_Name);

      for I in Linker_Switches.First .. Linker_Switches.Last loop
         N_Link_Flags := N_Link_Flags + 1;
         Link_Flags (N_Link_Flags) := Linker_Switches.Table (I);
      end loop;

      --  Call gnatmake

      Execute (Gnatlink, Link_Flags (1 .. N_Link_Flags));

   end Execute_Link;

   ----------------
   -- GNAT_Style --
   ----------------

   function GNAT_Style (N : Name_Id) return String is
      Capitalized : Boolean := True;
   begin
      Get_Name_String (N);
      for I in 1 .. Name_Len loop
         if Name_Buffer (I) in 'a' .. 'z' then
            if Capitalized then
               Name_Buffer (I) :=
                 Character'Val (Character'Pos (Name_Buffer (I)) + Up_To_Low);
               Capitalized := False;
            end if;
         elsif Name_Buffer (I) = '_' or else Name_Buffer (I) = '.' then
            Capitalized := True;
         end if;
      end loop;
      return Name_Buffer (1 .. Name_Len);
   end GNAT_Style;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize is
      Dir_Sep    : String (1 .. 1) := (others => Directory_Separator);
      Name       : Name_Id;

   begin

      --  Default initialization of the flags affecting gnatdist

      Opt.Check_Readonly_Files     := False;
      Opt.Check_Object_Consistency := True;
      Opt.Compile_Only             := False;
      Opt.Dont_Execute             := False;
      Opt.Force_Compilations       := False;
      Opt.Quiet_Output             := False;
      Opt.Minimal_Recompilation    := False;
      Opt.Verbose_Mode             := False;

      --  Package initializations. The order of calls is important here.

      Output.Set_Standard_Error;
      Osint.Initialize (Osint.Make); --  reads gnatmake switches

      Gcc_Switches.Init;
      Binder_Switches.Init;
      Linker_Switches.Init;

      Csets.Initialize;
      Namet.Initialize;

      Gcc             := Locate ("gcc");
      Mkdir           := Locate ("mkdir");
      Copy            := Locate ("cp");
      Link            := Locate ("ln", False);
      Chmod           := Locate ("chmod");
      Rm              := Locate ("rm");
      Gnatbind        := Locate ("gnatbind");
      Gnatlink        := Locate ("gnatlink");
      Gnatmake        := Locate ("gnatmake");

      GNATLib_Compile_Flag := new String'("-gnatg");
      Object_Suffix        := Get_Object_Suffix;
      Executable_Suffix    := Get_Executable_Suffix;

      Inc_Path_Flag  := Str_To_Id ("-I");
      Lib_Path_Flag  := Str_To_Id ("-L");
      Private_Id     := Str_To_Id ("private");
      Caller_Id      := Str_To_Id ("caller");
      Receiver_Id    := Str_To_Id ("receiver");
      Parent_Dir     := Str_To_Id ("..");

      Obj_Suffix     := Str_To_Id (Object_Suffix.all);
      Exe_Suffix     := Str_To_Id (Executable_Suffix.all);

      ALI_Suffix     := Str_To_Id (".ali");
      ADS_Suffix     := Str_To_Id (".ads");
      ADB_Suffix     := Str_To_Id (".adb");

      Spec_Suffix    := Str_To_Id ("%s");
      Body_Suffix    := Str_To_Id ("%b");

      Dir_Sep_Id     := Str_To_Id (Dir_Sep);
      Dot_Sep_Id     := Str_To_Id (".");

      DSA_Dir        := Str_To_Id ("dsa");

      Caller_Dir     := DSA_Dir & Dir_Sep_Id & Private_Id &
                       Dir_Sep_Id & Caller_Id;
      Receiver_Dir   := DSA_Dir & Dir_Sep_Id & Private_Id &
                       Dir_Sep_Id & Receiver_Id;

      Original_Dir   := Parent_Dir & Dir_Sep_Id &
                        Parent_Dir & Dir_Sep_Id &
                        Parent_Dir;

      PWD_Id         := Str_To_Id ("`pwd`") & Dir_Sep_Id;

      Build_Stamp_File    := Str_To_Id ("glade.sta");
      Elaboration_File    := Str_To_Id ("s-garela");
      Elaboration_Name    := Str_To_Id ("System.Garlic.Elaboration");
      Partition_Main_File := Str_To_Id ("partition");
      Partition_Main_Name := Str_To_Id ("Partition");

      declare
         Dir  : constant String_Access := Get_GARLIC_Dir;
         Len  : Natural;
      begin
         Len := Dir'Length;

         Get_Name_String (Inc_Path_Flag);
         Name_Buffer (Name_Len + 1 .. Name_Len + Len) := Dir.all;
         I_GARLIC_Dir := new String'(Name_Buffer (1 .. Name_Len + Len));

         Get_Name_String (Lib_Path_Flag);
         Name_Buffer (Name_Len + 1 .. Name_Len + Len) := Dir.all;
         L_GARLIC_Dir := new String'(Name_Buffer (1 .. Name_Len + Len));

         Name := Inc_Path_Flag & Dot_Sep_Id;
         Get_Name_String (Name);
         I_Current_Dir := new String'(Name_Buffer (1 .. Name_Len));

         Name := Inc_Path_Flag & Parent_Dir & Dir_Sep_Id & Parent_Dir &
           Dir_Sep_Id & Private_Id & Dir_Sep_Id & Caller_Id & Dir_Sep_Id;
         Get_Name_String (Name);
         I_Caller_Dir  := new String'(Name_Buffer (1 .. Name_Len));

         Name := Inc_Path_Flag & DSA_Dir &
           Dir_Sep_Id & Private_Id & Dir_Sep_Id & Caller_Id & Dir_Sep_Id;
         Get_Name_String (Name);
         I_DSA_Caller_Dir := new String'(Name_Buffer (1 .. Name_Len));

         Name := Inc_Path_Flag & Parent_Dir & Dir_Sep_Id & Parent_Dir &
           Dir_Sep_Id & Parent_Dir & Dir_Sep_Id;
         I_Original_Dir := new String'(Name_Buffer (1 .. Name_Len));

         Name := Lib_Path_Flag & Dot_Sep_Id;
         L_Current_Dir := new String'(Name_Buffer (1 .. Name_Len));

         Name := Lib_Path_Flag & Parent_Dir & Dir_Sep_Id & Parent_Dir &
           Dir_Sep_Id & Private_Id & Dir_Sep_Id & Caller_Id & Dir_Sep_Id;
         Get_Name_String (Name);
         L_Caller_Dir  := new String'(Name_Buffer (1 .. Name_Len));

         Name := Lib_Path_Flag & DSA_Dir &
           Dir_Sep_Id & Private_Id & Dir_Sep_Id & Caller_Id & Dir_Sep_Id;
         Get_Name_String (Name);
         L_DSA_Caller_Dir := new String'(Name_Buffer (1 .. Name_Len));

         Name := Lib_Path_Flag & Parent_Dir & Dir_Sep_Id & Parent_Dir &
           Dir_Sep_Id & Parent_Dir & Dir_Sep_Id;
         L_Original_Dir := new String'(Name_Buffer (1 .. Name_Len));

         for Next_Arg in 1 .. Argument_Count loop
            Scan_Make_Arg (Argument (Next_Arg));
         end loop;

         declare
            GARLIC_Flag : String (1 .. Len + 2);
         begin
            GARLIC_Flag (1 .. 2) := "-A";
            GARLIC_Flag (3 .. Len + 2) := Dir.all;
            Scan_Make_Arg (GARLIC_Flag);
         end;

         Osint.Add_Default_Search_Dirs;

         --  Source file lookups should be cached for efficiency.
         --  Source files are not supposed to change.

         --  Osint.Source_File_Data (Cache => True);

         Linker_Switches.Increment_Last;
         Linker_Switches.Table (Linker_Switches.Last)
           :=  new String'("-lgarlic");

         --  Use Gnatmake already defined switches.
         Verbose_Mode       := Opt.Verbose_Mode;
         Debug_Mode         := Debug.Debug_Flag_Q;
         Quiet_Output       := Opt.Quiet_Output;
         No_Recompilation   := Opt.Dont_Execute;
         Building_Script    := Opt.List_Dependencies;

         --  Use -dq for Gnatdist internal debugging.
         Debug.Debug_Flag_Q := False;

         --  Don't want log messages that would corrupt scripts.
         if Building_Script then
            Verbose_Mode := False;
            Quiet_Output := True;
         end if;

         Opt.Check_Source_Files := False;
         Opt.All_Sources        := False;

         if Verbose_Mode then
            GNAT_Verbose := new String' ("-v");
         else
            GNAT_Verbose := new String' ("-q");
         end if;

      end;

   end Initialize;

   ------------------
   -- Is_Directory --
   ------------------

   function Is_Directory (File : File_Name_Type) return Boolean is
   begin
      Get_Name_String (File);
      return Is_Directory (Name_Buffer (1 .. Name_Len));
   end Is_Directory;

   ---------------------
   -- Is_Regular_File --
   ---------------------

   function Is_Regular_File (File : File_Name_Type) return Boolean is
   begin
      Get_Name_String (File);
      return GNAT.OS_Lib.Is_Regular_File (Name_Buffer (1 .. Name_Len));
   end Is_Regular_File;

   ---------------------
   -- Is_Relative_Dir --
   ---------------------

   function Is_Relative_Dir (File : File_Name_Type) return Boolean is
   begin
      Get_Name_String (File);
      return Name_Len = 0 or else
        (Name_Buffer (1) /= Separator and then Name_Buffer (1) /= '/');
   end Is_Relative_Dir;

   ------------
   -- Locate --
   ------------

   function Locate
     (Exec_Name  : String;
      Show_Error : Boolean := True)
     return String_Access is
      Prog : String_Access;
   begin
      Prog := Locate_Regular_File (Exec_Name, Path.all);
      if Prog = null and then Show_Error then
         Message ("", No_Name, Exec_Name, No_Name, " is not in your path");
         raise Fatal_Error;
      end if;
      return Prog;
   end Locate;

   ---------
   -- ">" --
   ---------

   function ">" (File1, File2 : Name_Id) return Boolean is
   begin
      if Source_File_Stamp (File1) > Source_File_Stamp (File2) then
         if Debug_Mode then
            Write_Stamp_Comparison (File1, File2);
         end if;
         return True;
      else
         return False;
      end if;
   end ">";

   -------------
   -- Message --
   -------------

   procedure Message
     (S1 : in String  := "";
      S2 : in Name_Id := No_Name;
      S3 : in String  := "";
      S4 : in Name_Id := No_Name;
      S5 : in String  := "") is
   begin
      Write_Program_Name;
      Write_Str (": ");
      if S1 /= "" then
         Write_Str (S1);
      end if;
      if S2 /= No_Name then
         Write_Name (S2);
      end if;
      if S3 /= "" then
         Write_Str (S3);
      end if;
      if S4 /= No_Name then
         Write_Name (S4);
      end if;
      if S5 /= "" then
         Write_Str (S5);
      end if;
      Write_Eol;
   end Message;

   ---------------
   -- Str_To_Id --
   ---------------

   function Str_To_Id (S : String) return Name_Id is
   begin
      if S'Length = 0 then
         return No_Name;
      end if;
      Name_Buffer (1 .. S'Length) := S;
      Name_Len := S'Length;
      return Name_Find;
   end Str_To_Id;

   ------------
   -- Strlen --
   ------------

   function Strlen (Name : in Name_Id) return Natural is
   begin
      Get_Name_String (Name);
      return Name_Len;
   end Strlen;

   --------------
   -- To_Lower --
   --------------

   procedure To_Lower (S : in out String) is
   begin
      for I in S'Range loop
         if S (I) in 'A' .. 'Z' then
            S (I) := Character'Val (Character'Pos (S (I)) - Up_To_Low);
         end if;
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

   ------------
   -- U_To_N --
   ------------

   function U_To_N (U : in Unit_Name_Type) return Name_Id is
   begin
      if U /= No_Name then
         Get_Name_String (U);
         if Name_Buffer (Name_Len - 1) = '%' then --  %
            Name_Len := Name_Len - 2;
         end if;
         return Name_Find;
      else
         return U;
      end if;
   end U_To_N;

   -----------------
   -- Unlink_File --
   -----------------

   procedure Unlink_File (File : in File_Name_Type) is
      File_Name : String_Access := new String (1 .. Strlen (File));
      procedure Free is new Unchecked_Deallocation (String, String_Access);
   begin
      Get_Name_String (File);
      File_Name.all := Name_Buffer (1 .. Name_Len);
      Execute (Rm, (Force, File_Name));
      Free (File_Name);
   end Unlink_File;

   ---------------------------
   -- Write_Compile_Command --
   ---------------------------

   procedure Write_Compile_Command (Name : in File_Name_Type) is
   begin
      Write_Str  (Standout, Gnatmake.all);
      Write_Str  (Standout, " -c ");
      for I in Gcc_Switches.First .. Gcc_Switches.Last loop
         Write_Str (Standout, Gcc_Switches.Table (I).all);
         Write_Str (Standout, " ");
      end loop;
      Write_Name (Standout, Name);
      Write_Eol  (Standout);
   end Write_Compile_Command;

   ---------------
   -- Write_Eol --
   ---------------

   procedure Write_Eol
     (File   : in File_Descriptor;
      Stdout : in Boolean := False) is
   begin

      if File = Invalid_FD then
         raise Usage_Error;
      end if;

      if EOL'Length /= Write (File, EOL'Address, EOL'Length) then
         Write_Str ("error : disk full");
         Write_Eol;
         raise Fatal_Error;
      end if;

      if Stdout then
         Write_Eol (Standout);
      end if;

   end Write_Eol;

   ----------------------
   -- Write_File_Stamp --
   ----------------------

   procedure Write_File_Stamp
     (File : in File_Name_Type) is
   begin
      Write_Str (" (");
      Write_Str (String (Source_File_Stamp (File)));
      Write_Str (")");
   end Write_File_Stamp;

   ------------------------
   -- Write_Missing_File --
   ------------------------

   procedure Write_Missing_File
     (File  : in File_Name_Type) is
   begin
      Message ("", File, " does not exist");
   end Write_Missing_File;

   -------------------
   -- Uname_To_Name --
   -------------------

   procedure Write_Name
     (File   : in File_Descriptor;
      Name   : in Name_Id;
      Stdout : in Boolean := False) is
   begin

      if File = Invalid_FD then
         raise Usage_Error;
      end if;

      if Name /= No_Name then
         Get_Name_String (Name);
         if Name_Buffer (Name_Len - 1) = '%' then --  %
            Name_Len := Name_Len - 2;
         end if;
         if Write (File, Name_Buffer'Address, Name_Len) /= Name_Len then
            Write_Str ("error : disk full");
            Write_Eol;
            raise Fatal_Error;
         end if;

         if Stdout then
            Write_Name (Standout, Name);
         end if;

      end if;

   end Write_Name;

   ----------------------------
   -- Write_Stamp_Comparison --
   ----------------------------

   procedure Write_Stamp_Comparison
     (Newer, Older   : in File_Name_Type) is
   begin
      Write_Program_Name;
      Write_Str (": ");
      Write_Name (Newer);
      Write_File_Stamp (Newer);
      Write_Str (" > ");
      Write_Name (Older);
      Write_File_Stamp (Older);
      Write_Eol;
   end Write_Stamp_Comparison;

   ---------------
   -- Write_Str --
   ---------------

   procedure Write_Str
     (File   : in File_Descriptor;
      Line   : in String;
      Stdout : in Boolean := False) is
   begin

      if File = Invalid_FD then
         raise Usage_Error;
      end if;

      if Write (File, Line'Address, Line'Length) /= Line'Length then
         Write_Str ("error : disk full");
         Write_Eol;
         raise Fatal_Error;
      end if;

      if Stdout then
         Write_Str (Standout, Line);
      end if;

   end Write_Str;

   ---------------------
   -- Write_Unit_Name --
   ---------------------

   procedure Write_Unit_Name (U : in Unit_Name_Type) is
   begin
      Get_Decoded_Name_String (U);
      for J in 1 .. Name_Len loop
         if Name_Buffer (J) = '-' then
            Name_Buffer (J) := '.';
         end if;
      end loop;
      Name_Len := Name_Len - 2;
      Write_Str (Name_Buffer (1 .. Name_Len));
   end Write_Unit_Name;

end XE_Utils;
