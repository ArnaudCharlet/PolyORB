------------------------------------------------------------------------------
--                                                                          --
--                            GLADE COMPONENTS                              --
--                                                                          --
--                               X E _ S E M                                --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--                            $Revision$
--                                                                          --
--         Copyright (C) 1995-2004 Free Software Foundation, Inc.           --
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

with GNAT.Table;

with XE;               use XE;
with XE_Front;          use XE_Front;
with XE_Flags;         use XE_Flags;
with XE_IO;            use XE_IO;
with XE_List;          use XE_List;
with XE_Names;         use XE_Names;
with XE_Types;         use XE_Types;
with XE_Units;         use XE_Units;
with XE_Utils;         use XE_Utils;

package body XE_Sem is

   package Sources is new GNAT.Table
     (Table_Component_Type => File_Name_Type,
      Table_Index_Type     => Natural,
      Table_Low_Bound      => 1,
      Table_Initial        => 20,
      Table_Increment      => 100);

   procedure Apply_Default_Channel_Attributes (Channel : Channel_Id);
   --  When a channel attribute has not been assigned, apply the
   --  default channel attribute.

   procedure Apply_Default_Partition_Attributes (Partition : Partition_Id);
   --  When a partition attribute has not been assigned, apply the
   --  default partition attribute.

   procedure Assign_Partition_Tasking (Partition : Partition_Id);
   --  Assign partition tasking based on its configured units. Assign
   --  termination policy at the same time.

   procedure Assign_Tasking_From_Unit_Categorization (ALI : ALI_Id);
   --  Assign tasking when unit is RCI, RACW, pure or preelaborated.

   procedure Assign_Tasking_From_Unit_Dependencies
     (ALI     : ALI_Id;
      Tasking : in out Character);
   --  Assign tasking when it is required by dependencies. If the use
   --  of tasking has not been analyzed for a dependency, then push it
   --  in the stack to investigate whether it requires tasking or not.

   procedure Detect_Configured_Channel_Duplication
     (Channel : Channel_Id;
      Success : in out Boolean);
   --  Detect when two channels are defined designating the same
   --  partition pair. This may be incorrect as the configuration of
   --  the two channels may be inconsistent.

   procedure Detect_Empty_Partition
     (Partition : Partition_Id;
      Success   : in out Boolean);
   --  Detect empty partition since they cannot register to the
   --  distributed system.

   procedure Detect_Incorrect_Main_Subprogram
     (Partition : Partition_Id;
      Success   : in out Boolean);
   --  Detect that the configured unit used as main subprogram is
   --  really a main subprogram from the Ada point of view.

   procedure Detect_Mal_Formed_Location
     (Location : Location_Id;
      Success  : in out Boolean);
   --  Detecte that the major location is not missing.

   procedure Detect_Multiply_Assigned_Conf_Unit
     (Conf_Unit : Conf_Unit_Id;
      Success   : in out Boolean);
   --  RCI and SP units cannot be multiply assigned. They have to be
   --  unique in the global distributed system. No replication yet.

   procedure Detect_Non_Ada_Conf_Unit
     (Conf_Unit : Conf_Unit_Id;
      Success   : in out Boolean);
   --  Detect that configured units do really designate Ada units.

   procedure Detect_Non_Collocated_Categorized_Child_Unit
     (Conf_Unit : Conf_Unit_Id;
      Success   : in out Boolean);
   --  When two RCI or SP units are child and parent, they have to be
   --  collocated as they have visibility on their private parts.

   procedure Detect_Non_Configured_Categorized_Unit
     (ALI     : ALI_Id;
      Success : in out Boolean);
   --  A RCI or SP unit has to be configured on one partition. This
   --  rule is applied only when we produce the global distributed
   --  system. If a unit is not configured then we already know that
   --  it is erroneous.

   procedure Find_Stubs_And_Stamps_From_Closure (Partition : Partition_Id);
   --  Explore the partition transitive closure to compute the list of
   --  units for which we need only their stubs (RCI and SP that are
   --  not configured on this partition). We need this list to check
   --  the version consistency between stubs and skels. In the same
   --  time, compute the most recent file time stamp to see whether we
   --  need to update the partition executable file.

   -------------
   -- Analyze --
   -------------

   procedure Analyze is
      A  : ALI_Id;
      CU : Conf_Unit_Id;
      OK : Boolean := True;
      T  : Character;

   begin
      --  XXX Resolve defaults ...
      --  Add units configured on the partition type to each
      --  partition (for instance, main subprogram).

      CU := Partitions.Table (Default_Partition_Id).First_Unit;
      while CU /= No_Conf_Unit_Id loop
         for J in Partitions.First + 1 .. Partitions.Last loop
            Add_Conf_Unit (Conf_Units.Table (CU).Name, J);
         end loop;
         CU := Conf_Units.Table (CU).Next_Unit;
      end loop;

      XE_List.Initialize;
      Main_Subprogram := Partitions.Table (Main_Partition).Main_Subprogram;
      if Partitions.Table (Main_Partition).To_Build then
         Register_Unit_To_Load (Main_Subprogram);
      end if;
      for U in Conf_Units.First .. Conf_Units.Last loop
         if To_Build (U) then
            Register_Unit_To_Load (Conf_Units.Table (U).Name);
         end if;
      end loop;
      Load_All_Registered_Units;

      ----------------------------
      -- Use of Name Table Info --
      ----------------------------

      --  All unit names and file names are entered into the Names
      --  table. The Info and Byte fields of these entries are used as
      --  follows:
      --
      --    Unit name           Info field has Unit_Id
      --                        Byte fiels has Partition_Id (*)
      --    Conf. unit name     Info field has ALI_Id
      --                        Byte fiels has Partition_Id (*)
      --    ALI file name       Info field has ALI_Id
      --    Source file name    Info field has ALI_Id
      --
      --  (*) A (normal, RT) unit may be assigned to several partitions.

      --  We want to detect whether these configured units are real
      --  ada units. Set the configured unit name to No_ALI_Id. When
      --  we load an ali file, its unit name is set to its ali id. If
      --  a configured unit name has no ali id, it is not an Ada unit.
      --  Assign byte field of configured unit name to No_Partition_Id
      --  in order to detect units that are multiply assigned.

      for J in Conf_Units.First .. Conf_Units.Last loop
         Set_ALI_Id       (Conf_Units.Table (J).Name, No_ALI_Id);
         Set_Partition_Id (Conf_Units.Table (J).Name, No_Partition_Id);
      end loop;

      --  Set name table info of conf. unit name (%s or %b removed) to
      --  ALI id. Set use of tasking to unknown.

      for J in ALIs.First .. ALIs.Last loop
         Set_ALI_Id (Units.Table (ALIs.Table (J).Last_Unit).Uname, J);
         Set_Tasking (J, '?');
      end loop;

      if not Quiet_Mode then
         Message ("checking configuration consistency");
      end if;

      if Debug_Mode then
         Message ("detect non Ada configured units");
         Message ("detect (RCI/SP) multiply assigned configured units");
      end if;

      for J in Conf_Units.First .. Conf_Units.Last loop
         if Partitions.Table (Conf_Units.Table (J).Partition).To_Build then
            Detect_Non_Ada_Conf_Unit (J, OK);
            Detect_Multiply_Assigned_Conf_Unit (J, OK);
         end if;
      end loop;

      if Partitions.Table (Default_Partition_Id).To_Build then
         if Debug_Mode then
            Message ("detect non configured (RCI/SP) categorized units");
         end if;

         for J in ALIs.First .. ALIs.Last loop
            Detect_Non_Configured_Categorized_Unit (J, OK);
         end loop;
      end if;

      if Debug_Mode then
         Message ("detect non collocated (RCI/SP) child and parents");
      end if;

      for J in Conf_Units.First .. Conf_Units.Last loop
         if To_Build (J) then
            Detect_Non_Collocated_Categorized_Child_Unit (J, OK);
         end if;
      end loop;

      if Debug_Mode then
         Message ("detect empty partitions");
         Message ("detect incorrect main subprograms");
      end if;

      for J in Partitions.First + 1 .. Partitions.Last loop
         if Partitions.Table (J).To_Build then
            Detect_Empty_Partition (J, OK);
            Detect_Incorrect_Main_Subprogram (J, OK);
         end if;
      end loop;

      if Debug_Mode then
         Message ("detect channel duplications");
      end if;

      for J in Channels.First + 1 .. Channels.Last loop
         Detect_Configured_Channel_Duplication (J, OK);
      end loop;

      if Debug_Mode then
         Message ("detect mal formed locations");
      end if;

      for J in Locations.First .. Locations.Last loop
         Detect_Mal_Formed_Location (J, OK);
      end loop;

      if not OK then
         raise Partitioning_Error;
      end if;

      for J in Partitions.First + 1 .. Partitions.Last loop
         if Partitions.Table (J).To_Build then
            Apply_Default_Partition_Attributes (J);
         end if;
      end loop;

      for J in Channels.First + 1 .. Channels.Last loop
         Apply_Default_Channel_Attributes (J);
      end loop;

      if not Quiet_Mode then
         Show_Configuration;
      end if;

      if Debug_Mode then
         Message ("look for units dragging tasking");
      end if;

      --  This step checks whether we need tasking on a partition.
      --
      --  Notation:
      --     '?' : unknown
      --     'P' : tasking is required because of PCS code
      --     'U' : tasking is required because of user code
      --     'N' : tasking is not required for this unit
      --
      --  Check whether a unit comes with tasking. Possibly because of
      --  its dependencies. Note that we do not look any further a
      --  dependency designating a RCI unit since it may not be
      --  collocated with the initial unit. Check also whether this
      --  unit is RCI and or has RACW as such a unit requires tasking
      --  from the PCS. Check whether the partition is candidate for a
      --  local termination.

      Partitions.Table (Main_Partition).Tasking := 'P';
      for J in Conf_Units.First .. Conf_Units.Last loop
         Set_Partition_Id
           (Conf_Units.Table (J).Name,
            Conf_Units.Table (J).Partition);

         if To_Build (J) then
            if Debug_Mode then
               Message ("[tasking] append", Conf_Units.Table (J).Name);
            end if;
            Sources.Append (ALIs.Table (Conf_Units.Table (J).My_ALI).Sfile);
         end if;
      end loop;

      while Sources.First <= Sources.Last loop
         A := Get_ALI_Id (Sources.Table (Sources.Last));

         if Debug_Mode then
            Message ("[tasking] analyze", ALIs.Table (A).Afile);
         end if;

         Assign_Tasking_From_Unit_Categorization (A);

         --  The use of tasking is still unknown. Investigate into the
         --  dependencies as long as they are collocated.

         if Get_Tasking (A) = '?' then
            T := 'N';

            if Debug_Mode then
               Message ("[tasking] analyze", ALIs.Table (A).Afile, "deps");
            end if;

            Assign_Tasking_From_Unit_Dependencies (A, T);

            --  The use of tasking has been fully analyzed.

            if T /= '?' then
               if Debug_Mode then
                  Message ("[tasking]", ALIs.Table (A).Uname, "tasking " & T);
               end if;

               Set_Tasking (A, T);
               Sources.Decrement_Last;
            end if;

         else
            Sources.Decrement_Last;
         end if;
      end loop;

      if Debug_Mode then
         Message ("find partition stub-only units");
         Message ("update partition most recent stamp");
      end if;

      for J in Partitions.First + 1 .. Partitions.Last loop
         if Partitions.Table (J).To_Build then
            Assign_Partition_Tasking (J);
            Find_Stubs_And_Stamps_From_Closure (J);
         end if;
      end loop;
   end Analyze;

   --------------------------------------
   -- Apply_Default_Channel_Attributes --
   --------------------------------------

   procedure Apply_Default_Channel_Attributes (Channel : Channel_Id) is
      Current : Channel_Type renames Channels.Table (Channel);
      Default : Channel_Type renames Channels.Table (Default_Channel_Id);

   begin
      if No (Current.Filter) then
         Current.Filter := Default.Filter;
      end if;
   end Apply_Default_Channel_Attributes;

   ----------------------------------------
   -- Apply_Default_Partition_Attributes --
   ----------------------------------------

   procedure Apply_Default_Partition_Attributes (Partition : Partition_Id) is
      Current : Partition_Type renames Partitions.Table (Partition);
      Default : Partition_Type renames Partitions.Table (Default_Partition_Id);

   begin
      Current.Partition_Dir := Dir (Configuration, Current.Name);
      Current.Partition_Dir := Dir (Id (Root), Current.Partition_Dir);

      if No (Current.Command_Line) then
         Current.Command_Line := Default.Command_Line;
      end if;

      if No (Current.Executable_Dir) then
         Current.Executable_Dir := Default.Executable_Dir;
      end if;

      Current.Executable_File := Current.Name & Exe_Suffix_Id;
      if Present (Current.Executable_Dir) then
         Current.Executable_File :=
           Dir (Current.Executable_Dir, Current.Executable_File);
      end if;

      if No (Current.Filter) then
         Current.Filter := Default.Filter;
      end if;

      if No (Current.Main_Subprogram) then
         Current.Main_Subprogram := Default.Main_Subprogram;
      end if;


      if Current.Host = No_Host_Id then
         Current.Host := Default.Host;
      end if;

      if Current.Light_PCS = BMaybe then
         Current.Light_PCS := Default.Light_PCS;
      end if;

      if Current.Passive = BMaybe then
         Current.Passive := Default.Passive;
      end if;

      if Current.Priority = No_Priority then
         Current.Priority := Default.Priority;
      end if;

      if Current.First_Network_Loc = No_Location_Id then
         Current.First_Network_Loc := Default.First_Network_Loc;
         Current.Last_Network_Loc  := Default.Last_Network_Loc;
      end if;

      if Current.Reconnection = No_Reconnection then
         Current.Reconnection := Default.Reconnection;
      end if;

      if Current.Storage_Loc = No_Location_Id then
         Current.Storage_Loc := Default.Storage_Loc;
      end if;

      if Current.Task_Pool = No_Task_Pool then
         Current.Task_Pool := Default.Task_Pool;
      end if;

      if Current.Termination = No_Termination then
         Current.Termination := Default.Termination;
      end if;
   end Apply_Default_Partition_Attributes;

   ------------------------------
   -- Assign_Partition_Tasking --
   ------------------------------

   procedure Assign_Partition_Tasking (Partition : Partition_Id) is
      Current : Partition_Type renames Partitions.Table (Partition);
      Tasking : Character;
      Unit    : Conf_Unit_Id;

   begin
      Tasking := Current.Tasking;
      if Tasking /= '?' then
         return;
      end if;
      Tasking := 'N';

      --  Append all the source dependencies of units which are
      --  assigned to partition.

      Unit := Current.First_Unit;
      while Unit /= No_Conf_Unit_Id loop
         case Get_Tasking (Conf_Units.Table (Unit).My_ALI) is
            when 'P' =>
               Tasking := 'P';

            when 'U' =>
               if Tasking /= 'P' then
                  Tasking := 'U';
               end if;

            when others =>
               null;
         end case;
         Unit := Conf_Units.Table (Unit).Next_Unit;
      end loop;
      Current.Tasking := Tasking;

      if Debug_Mode then
         Message ("partition", Current.Name, "has tasking " & Tasking);
      end if;

      if Current.Termination = No_Termination and then Tasking /= 'P' then
         Current.Termination := Local_Termination;

         if Debug_Mode then
            Message ("local termination forced for", Current.Name);
         end if;
      end if;
   end Assign_Partition_Tasking;

   ---------------------------------------------
   -- Assign_Tasking_From_Unit_Categorization --
   ---------------------------------------------

   procedure Assign_Tasking_From_Unit_Categorization (ALI : ALI_Id) is
      N : constant Unit_Name_Type := ALIs.Table (ALI).Uname;

   begin
      for J in ALIs.Table (ALI).First_Unit .. ALIs.Table (ALI).Last_Unit loop

         --  No need to investigate further when the unit is a RCI
         --  unit or has RACW objects.

         if Units.Table (J).RCI
           or else Units.Table (J).Has_RACW
         then
            if Debug_Mode then
               Message ("[tasking]", N, "requires tasking P");
            end if;
            Set_Tasking (ALI, 'P');
            exit;

         elsif Units.Table (J).Pure
           or else Units.Table (J).Preelaborated
         then
            if Debug_Mode then
               Message ("[tasking]", N, "requires tasking N");
            end if;
            Set_Tasking (ALI, 'N');
            exit;
         end if;
      end loop;
   end Assign_Tasking_From_Unit_Categorization;

   -------------------------------------------
   -- Assign_Tasking_From_Unit_Dependencies --
   -------------------------------------------

   procedure Assign_Tasking_From_Unit_Dependencies
     (ALI     : ALI_Id;
      Tasking : in out Character)
   is
      N : constant Unit_Name_Type := ALIs.Table (ALI).Uname;
      D : ALI_Id;
      U : Unit_Id;

   begin
      for J in ALIs.Table (ALI).First_Sdep .. ALIs.Table (ALI).Last_Sdep loop

         --  Get corresponding ali and then unit spec if possible. But
         --  first discard predefined units since they do not bring
         --  tasking with them.

         D := Get_ALI_Id (Sdep.Table (J).Sfile);
         if Is_Predefined_File (Sdep.Table (J).Sfile) then
            null;

         elsif D /= No_ALI_Id then
            U := ALIs.Table (D).Last_Unit;

            --  This is a dependency on the unit itself

            if Units.Table (U).My_ALI = ALI then
               null;

            --  This unit may not be collocated with the last unit
            --  in the sources table or they cannot drag any tasking.

            elsif Units.Table (U).RCI
              or else Units.Table (U).Preelaborated
              or else Units.Table (U).Pure
            then
               null;

            --  This unit has not been yet analyzed. Keep the last
            --  unit from the sources table in the stack and push
            --  this new one.

            elsif Get_Tasking (Units.Table (U).My_ALI) = '?' then
               if Debug_Mode then
                  Message ("[tasking]", N, "postponed");
               end if;

               Tasking := '?';
               Sources.Append (Sdep.Table (J).Sfile);

               if Debug_Mode then
                  Message ("[tasking] append", N);
               end if;

            --  There are other units to analyze before making any
            --  conclusion.

            elsif Tasking = '?' then
               null;

            --  Declare the use of tasking if the dependency use
            --  tasking.

            elsif Get_Tasking (Units.Table (U).My_ALI) = 'U'
              or else Get_Tasking (Units.Table (U).My_ALI) = 'P'
            then
               if Tasking /= 'P' then
                  Tasking := Get_Tasking (Units.Table (U).My_ALI);
                  if Debug_Mode then
                     if Tasking = 'U' then
                        Message ("[tasking]", N, "requires tasking U");

                     else
                        Message ("[tasking]", N, "requires tasking P");
                     end if;
                  end if;

               elsif Debug_Mode then
                  Message ("[tasking]", N, "still requires tasking P");
               end if;
            end if;
         end if;
      end loop;
   end Assign_Tasking_From_Unit_Dependencies;

   -------------------------------------------
   -- Detect_Configured_Channel_Duplication --
   -------------------------------------------

   procedure Detect_Configured_Channel_Duplication
     (Channel : Channel_Id;
      Success : in out Boolean)
   is
      N  : Name_Id := Channels.Table (Channel).Name;
      LP : Partition_Id renames Channels.Table (Channel).Lower.My_Partition;
      UP : Partition_Id renames Channels.Table (Channel).Upper.My_Partition;
      C  : Channel_Id;

   begin
      if UP = LP then
         Message ("channel", Quote (N), "is an illegal pair of partitions");
         Success := False;
      end if;

      Get_Name_String (Partitions.Table (UP).Name);
      Add_Char_To_Name_Buffer ('#');
      Get_Name_String_And_Append (Partitions.Table (UP).Name);
      N := Name_Find;
      C := Get_Channel_Id (N);

      if C /= No_Channel_Id then
         Message ("channels", Quote (N), "and",
                  Quote (Channels.Table (C).Name),
                  "designate the same pair");
         Success := False;
      end if;

      Set_Channel_Id (N, Channel);
   end Detect_Configured_Channel_Duplication;

   ----------------------------
   -- Detect_Empty_Partition --
   ----------------------------

   procedure Detect_Empty_Partition
     (Partition : Partition_Id;
      Success   : in out Boolean)
   is
      N : constant Name_Id := Partitions.Table (Partition).Name;

   begin
      --  We cannot have an empty partition

      if Partitions.Table (Partition).First_Unit = No_Conf_Unit_Id then
         Message ("partition", Quote (N), "is empty");
         Success := False;
      end if;
   end Detect_Empty_Partition;

   --------------------------------------
   -- Detect_Incorrect_Main_Subprogram --
   --------------------------------------

   procedure Detect_Incorrect_Main_Subprogram
     (Partition : Partition_Id;
      Success   : in out Boolean)
   is
      N : constant Unit_Name_Type :=
        Partitions.Table (Partition).Main_Subprogram;
      A : ALI_Id;

   begin
      if No (N) then
         return;
      end if;

      A := Get_ALI_Id (N);
      if A /= No_ALI_Id and then ALIs.Table (A).Main_Program = None then
         Message ("", Quote (N), "is not a main program");
         Success := False;
      end if;
   end Detect_Incorrect_Main_Subprogram;

   --------------------------------
   -- Detect_Mal_Formed_Location --
   --------------------------------

   procedure Detect_Mal_Formed_Location
     (Location : Location_Id;
      Success  : in out Boolean) is
   begin
      Get_Name_String (Locations.Table (Location).Major);
      if Name_Len = 0 then
         Add_Str_To_Name_Buffer ("://");
         if Present (Locations.Table (Location).Minor) then
            Get_Name_String_And_Append (Locations.Table (Location).Minor);
         end if;
         Message ("missing location name in", Quote (Name_Find));
         Success := False;
      end if;
   end Detect_Mal_Formed_Location;

   ----------------------------------------
   -- Detect_Multiply_Assigned_Conf_Unit --
   ----------------------------------------

   procedure Detect_Multiply_Assigned_Conf_Unit
     (Conf_Unit : Conf_Unit_Id;
      Success   : in out Boolean)
   is
      N : constant Name_Id := Conf_Units.Table (Conf_Unit).Name;
      A : constant ALI_Id  := Get_ALI_Id (N);
      U : Unit_Id;

   begin
      if A = No_ALI_Id then
         return;
      end if;

      --  The last unit is always the spec when there is a spec.

      U := ALIs.Table (A).Last_Unit;
      Conf_Units.Table (Conf_Unit).My_Unit := U;
      Conf_Units.Table (Conf_Unit).My_ALI  := A;

      if Units.Table (U).Is_Generic then
         Message ("generic unit", Quote (N),
                  "cannot be assigned to a partition");
         Success := False;

      elsif Units.Table (U).RCI or else Units.Table (U).Shared_Passive then

         --  If null, we have not yet assigned this rci or sp unit
         --  name to a partition.

         if Get_Partition_Id (N) /= No_Partition_Id then
            if Units.Table (U).RCI then
               Message ("RCI Ada unit", Quote (N), "has been assigned twice");
            else
               Message ("SP Ada unit", Quote (N), "has been assigned twice");
            end if;
            Success := False;
         end if;

         --  Assign unit to partition in order not to assign it twice
         --  as this unit is a RCI or a SP package.

         Set_Partition_Id (N, Conf_Units.Table (Conf_Unit).Partition);
      end if;
   end Detect_Multiply_Assigned_Conf_Unit;

   ------------------------------
   -- Detect_Non_Ada_Conf_Unit --
   ------------------------------

   procedure Detect_Non_Ada_Conf_Unit
     (Conf_Unit : Conf_Unit_Id;
      Success   : in out Boolean)
   is
      N : constant Unit_Name_Type := Conf_Units.Table (Conf_Unit).Name;

   begin
      --  There is no ali file associated to this configured
      --  unit. The configured unit is not an Ada unit.

      if Get_ALI_Id (N) = No_ALI_Id then
         Message ("configured unit", Quote (N), "is not an Ada unit");
         Success := False;
      end if;
   end Detect_Non_Ada_Conf_Unit;

   --------------------------------------------------
   -- Detect_Non_Collocated_Categorized_Child_Unit --
   --------------------------------------------------

   procedure Detect_Non_Collocated_Categorized_Child_Unit
     (Conf_Unit : Conf_Unit_Id;
      Success   : in out Boolean)
   is
      P : constant Partition_Id   := Conf_Units.Table (Conf_Unit).Partition;
      U : Unit_Id                 := Conf_Units.Table (Conf_Unit).My_Unit;
      X : constant Unit_Name_Type := Conf_Units.Table (Conf_Unit).Name;
      N : Unit_Name_Type          := X;
      A : ALI_Id;

   begin
      if not Units.Table (U).RCI
        and then not Units.Table (U).Shared_Passive
      then
         return;
      end if;

      Get_Name_String (N);

      --  Find a parent

      while Name_Len > 0
        and then Name_Buffer (Name_Len) /= '.'
      loop
         Name_Len := Name_Len - 1;
      end loop;

      --  There is a parent

      if Name_Len > 1 then
         Name_Len := Name_Len - 1;
         N := Name_Find;
         A := Get_ALI_Id (N);

         --  When this is an issue this has already been reported

         if A = No_ALI_Id then
            return;
         end if;

         --  It is a RCI or SP package

         U := ALIs.Table (A).Last_Unit;

         if Units.Table (U).RCI
           or else Units.Table (U).Shared_Passive
         then
            --  There are not on the same partition

            if Get_Partition_Id (N) /= P then
               Message ("", Quote (N), "and", Quote (X),
                        "are not on the same partition");
               Success := False;
            end if;
         end if;
      end if;
   end Detect_Non_Collocated_Categorized_Child_Unit;

   --------------------------------------------
   -- Detect_Non_Configured_Categorized_Unit --
   --------------------------------------------

   procedure Detect_Non_Configured_Categorized_Unit
     (ALI     : ALI_Id;
      Success : in out Boolean)
   is
      U : constant Unit_Id := ALIs.Table (ALI).Last_Unit;
      N : constant Unit_Name_Type := Units.Table (U).Uname;

   begin
      if (Units.Table (U).RCI or else Units.Table (U).Shared_Passive)
        and then not Units.Table (U).Is_Generic
        and then Get_Partition_Id (N) = No_Partition_Id
      then
         if Units.Table (U).RCI then
            Message ("RCI Ada unit", Quote (Name (N)),
                     "has not been assigned to a partition");
         else
            Message ("Shared passive Ada unit", Quote (Name (N)),
                     "has not been assigned to a partition");
         end if;
         Success := False;
      end if;
   end Detect_Non_Configured_Categorized_Unit;

   ----------------------------------------
   -- Find_Stubs_And_Stamps_From_Closure --
   ----------------------------------------

   procedure Find_Stubs_And_Stamps_From_Closure (Partition : Partition_Id) is
      CU : Conf_Unit_Id;
      U  : Unit_Id;
      A  : ALI_Id;
      S  : File_Name_Type;
      L  : Stub_Id;

   begin
      Partitions.Table (Partition).First_Stub := Stubs.Last + 1;
      Partitions.Table (Partition).Last_Stub  := Stubs.Last;

      --  Append all the source dependencies of units which are
      --  assigned to partition.

      CU := Partitions.Table (Partition).First_Unit;
      while CU /= No_Conf_Unit_Id loop
         A := Get_ALI_Id (Conf_Units.Table (CU).Name);

         if Debug_Mode then
            Message ("update stamp from", ALIs.Table (A).Afile);
         end if;

         --  Update most recent stamp of this partition

         Update_Most_Recent_Stamp (Partition, ALIs.Table (A).Afile);

         for K in ALIs.Table (A).First_Sdep .. ALIs.Table (A).Last_Sdep loop

            --  Append Sfile only when it does not designate the
            --  source file associated to ALI A.

            if Get_ALI_Id (Sdep.Table (K).Sfile) /= A then
               Sources.Append (Sdep.Table (K).Sfile);
            end if;
         end loop;
         CU := Conf_Units.Table (CU).Next_Unit;
      end loop;

      --  Explore the dependencies

      <<Next_Dependency>>
      while Sources.First <= Sources.Last loop
         S := Sources.Table (Sources.Last);
         Sources.Decrement_Last;
         A := Get_ALI_Id (S);

         if A = No_ALI_Id then
            goto Next_Dependency;
         end if;

         U := ALIs.Table (A).Last_Unit;

         if Debug_Mode then
            Message ("check stamp", ALIs.Table (A).Afile);
         end if;

         --  Update most recent stamp of this partition

         Update_Most_Recent_Stamp (Partition, ALIs.Table (A).Afile);

         --  This unit has already been assigned to this
         --  partition. No need to explore any further.

         if Get_Partition_Id (S) = Partition then
            null;

         elsif Units.Table (U).RCI
           or else Units.Table (U).Shared_Passive
         then
            --  This unit is not assigned to partition J and it
            --  is a RCI or SP unit. Therefore, we append it to
            --  the partition stub list.

            Stubs.Increment_Last;
            L := Stubs.Last;
            Stubs.Table (L) := Name (Units.Table (U).Uname);

            if Partitions.Table (Partition).Last_Stub <
              Partitions.Table (Partition).First_Stub
            then
               Partitions.Table (Partition).First_Stub := L;
            end if;
            Partitions.Table (Partition).Last_Stub := L;

         else
            --  Mark this unit as explored and append its dependencies

            Set_Partition_Id (S, Partition);
            for K in ALIs.Table (A).First_Sdep .. ALIs.Table (A).Last_Sdep loop

               --  Append Sfile only when it does not designate the
               --  source file associated to ALI A.

               if Get_ALI_Id (Sdep.Table (K).Sfile) /= A
                 and then Get_Partition_Id (Sdep.Table (K).Sfile) /= Partition
               then
                  Sources.Append (Sdep.Table (K).Sfile);
               end if;
            end loop;
         end if;
      end loop;
   end Find_Stubs_And_Stamps_From_Closure;

end XE_Sem;