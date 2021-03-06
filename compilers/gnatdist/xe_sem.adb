------------------------------------------------------------------------------
--                                                                          --
--                           POLYORB COMPONENTS                             --
--                                                                          --
--                               X E _ S E M                                --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--         Copyright (C) 1995-2013, Free Software Foundation, Inc.          --
--                                                                          --
-- This is free software;  you can redistribute it  and/or modify it  under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 3,  or (at your option) any later ver- --
-- sion.  This software is distributed in the hope  that it will be useful, --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License for  more details.                                               --
--                                                                          --
-- You should have received a copy of the GNU General Public License and    --
-- a copy of the GCC Runtime Library Exception along with this program;     --
-- see the files COPYING3 and COPYING.RUNTIME respectively.  If not, see    --
-- <http://www.gnu.org/licenses/>.                                          --
--                                                                          --
--                  PolyORB is maintained by AdaCore                        --
--                     (email: sales@adacore.com)                           --
--                                                                          --
------------------------------------------------------------------------------

with GNAT.Table;

with XE;               use XE;
with XE_Back;          use XE_Back;
with XE_Front;         use XE_Front;
with XE_Flags;         use XE_Flags;
with XE_IO;            use XE_IO;
with XE_List;          use XE_List;
with XE_Names;         use XE_Names;
with XE_Types;         use XE_Types;
with XE_Units;         use XE_Units;
with XE_Utils;         use XE_Utils;
with XE_Storages;      use XE_Storages;

package body XE_Sem is

   package Files is new GNAT.Table
     (Table_Component_Type => File_Name_Type,
      Table_Index_Type     => Natural,
      Table_Low_Bound      => 1,
      Table_Initial        => 20,
      Table_Increment      => 100);

   procedure Apply_Default_Channel_Attributes (Channel : Channel_Id);
   --  When a channel attribute has not been assigned, apply the
   --  default channel attribute.

   procedure Apply_Default_Partition_Attributes (Partition : Partition_Id);
   --  When a partition attribute has not been assigned, apply the default
   --  value for the attribute.

   procedure Assign_Unit_Tasking (ALI : ALI_Id);
   --  Assign PCS tasking for a RCI unit.

   procedure Assign_Partition_Termination (Partition : Partition_Id);
   --  Assign termination policy based on tasking policy.

   procedure Update_Partition_Tasking
     (ALI : ALI_Id; Partition : Partition_Id);
   --  Update partition tasking with ALI tasking as well as all its
   --  withed and collocated units.

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
   --  Check that the configured unit used as main subprogram is really a main
   --  subprogram from the Ada point of view.

   procedure Detect_Malformed_Location
     (Location : Location_Id;
      Success  : in out Boolean);
   --  Check that the major location is not missing

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

   procedure Analyze_Required_Storage_Supports
     (Partition : Partition_Id;
      Success   : in out Boolean);
   --  For the given partition, build the required storages table by
   --  analyzing shared passive packages configured on this partition
   --  and stub packages configured on other partitions.
   --  Also ensure that storage location specific constraints aren't
   --  violated (see nested procedure Detect_Storage_Constraint_Violation).

   procedure Assign_ORB_Tasking_Policy (Partition : Partition_Id);
   --  Assign ORB tasking policy to default if hasn't been assigned by
   --  user. Write warning messages if selected policy is incompatible
   --  with partition tasking or Task_Pool attribute.

   -------------
   -- Analyze --
   -------------

   procedure Analyze is
      A  : ALI_Id;
      CU : Conf_Unit_Id;
      OK : Boolean := True;
      P  : Partition_Id;

   begin
      XE_List.Initialize;

      --  Add units configured on the partition type to each
      --  partition (for instance, main subprogram).

      CU := Partitions.Table (Default_Partition_Id).First_Unit;
      while CU /= No_Conf_Unit_Id loop
         for J in Partitions.First + 1 .. Partitions.Last loop
            Add_Conf_Unit (Conf_Units.Table (CU).Name, J);
         end loop;
         CU := Conf_Units.Table (CU).Next_Unit;
      end loop;

      --  PCS may require to configure one of its RCI units on the main
      --  partition.

      if PCS_Conf_Unit /= No_Name then
         Add_Conf_Unit (PCS_Conf_Unit, Main_Partition);

         --  Also register this unit explicitly because we want its stubs to
         --  be built even if the main partition is not built and there are no
         --  explicit calls to it in user code.

         Register_Unit_To_Load (PCS_Conf_Unit);
      end if;

      Main_Subprogram := Partitions.Table (Main_Partition).Main_Subprogram;
      if Partitions.Table (Main_Partition).To_Build then
         Register_Unit_To_Load (Main_Subprogram);
      end if;

      --  Load the closure of all configured RCIs

      for U in Conf_Units.First .. Conf_Units.Last loop
         if To_Build (U) then
            Register_Unit_To_Load (Conf_Units.Table (U).Name);
         end if;
      end loop;

      Load_All_Registered_Units;

      ----------------------------
      -- Use of Name Table Info --
      ----------------------------

      --  All unit names and file names are entered into the Names table.
      --  The Info and Byte fields of these entries are used as follows:
      --
      --    Unit name           Info field has Unit_Id
      --    Conf. unit name     Info field has ALI_Id
      --                        Byte field has Partition_Id (*)
      --    ALI file name       Info field has ALI_Id
      --    Source file name    Info field has Unit_Id
      --
      --  (*) A (normal, RT) unit may be assigned to several partitions.

      --  We want to detect whether these configured units are real Ada units.
      --  Set the configured unit name to No_ALI_Id. When we load an ALI file,
      --  its unit name is set to its ALI Id. If a configured unit name has no
      --  ALI Id, it is not an Ada unit.
      --  The byte field of configured unit names is used to detect multiple
      --  assignment of a unit.

      for J in Conf_Units.First .. Conf_Units.Last loop
         Set_ALI_Id       (Conf_Units.Table (J).Name, No_ALI_Id);
         Set_Partition_Id (Conf_Units.Table (J).Name, No_Partition_Id);
      end loop;

      --  Set name table info of conf. unit name (%s or %b removed) to ALI Id.

      for J in ALIs.First .. ALIs.Last loop
         Set_ALI_Id (ALIs.Table (J).Uname, J);
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
         Message ("detect malformed locations");
      end if;

      for J in Locations.First .. Locations.Last loop
         Detect_Malformed_Location (J, OK);
      end loop;

      if not OK then
         raise Partitioning_Error;
      end if;

      for J in Partitions.First + 1 .. Partitions.Last loop
         --  Apply default values for unspecified attributes. Note that this
         --  must be done even for partitions that are not built, since their
         --  attributes might be referenced by other partitions, e.g. when
         --  generating an Ada starter procedure (which needs the partition's
         --  executable file name).

         Apply_Default_Partition_Attributes (J);
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
      --  Check whether a unit comes with tasking. Possibly because of
      --  its dependencies. Note that we do not look any further a
      --  dependency designating a RCI unit since it may not be
      --  collocated with the initial unit. Check also whether this
      --  unit is RCI and or has RACW as such a unit requires tasking
      --  from the PCS. Check whether the partition is candidate for a
      --  local termination.

      for J in ALIs.First .. ALIs.Last loop
         Set_Partition_Id (ALIs.Table (J).Uname, No_Partition_Id);
         Assign_Unit_Tasking (J);
      end loop;

      for J in Conf_Units.First .. Conf_Units.Last loop
         A := Conf_Units.Table (J).My_ALI;
         P := Conf_Units.Table (J).Partition;
         Set_Partition_Id (Conf_Units.Table (J).Name, P);

         if To_Build (J) then
            Update_Partition_Tasking (A, P);
         end if;
      end loop;
      Partitions.Table (Main_Partition).Tasking := PCS_Tasking;

      if Debug_Mode then
         Message ("find partition stub-only units");
         Message ("update partition most recent stamp");
      end if;

      for J in Partitions.First + 1 .. Partitions.Last loop
         if Partitions.Table (J).To_Build then
            Find_Stubs_And_Stamps_From_Closure (J);
         end if;
      end loop;

      if Debug_Mode then
         Message ("find needed storage supports");
      end if;

      --  As the analysis of needed storage supports should update partition
      --  tasking, it must be performed before the termination analysis.

      for J in Partitions.First + 1 .. Partitions.Last loop
         if Partitions.Table (J).To_Build then
            Analyze_Required_Storage_Supports (J, OK);
         end if;
      end loop;

      if not OK then
         raise Partitioning_Error;
      end if;

      if Debug_Mode then
         Message ("configure partition termination");
      end if;

      for J in Partitions.First + 1 .. Partitions.Last loop
         if Partitions.Table (J).To_Build then
            Assign_Partition_Termination (J);
            Assign_ORB_Tasking_Policy (J);
         end if;
      end loop;

   end Analyze;

   ---------------------------------------
   -- Analyze_Required_Storage_Supports --
   ---------------------------------------

   procedure Analyze_Required_Storage_Supports
     (Partition : Partition_Id;
      Success   : in out Boolean)
   is
      procedure Detect_Storage_Constraint_Violation (SLID : Location_Id);
      --  Needs comment???

      Current : Partition_Type renames Partitions.Table (Partition);

      -----------------------------------------
      -- Detect_Storage_Constraint_Violation --
      -----------------------------------------

      procedure Detect_Storage_Constraint_Violation (SLID : Location_Id)
      is
         Location           : Location_Type renames Locations.Table (SLID);
         Storage_Properties : constant Storage_Support_Type :=
                                Storage_Supports.Get (Location.Major);

      begin
         --  Some storage supports cannot be used on passive partitions

         if Current.Passive = BTrue
           and then not Storage_Properties.Allow_Passive
         then
            Message ("passive partition", Quote (Current.Name),
                     "cannot use", Quote (Location.Major), "storage support");
            Success := False;
            return;
         end if;

         --  Some storage supports cannot be used on partition with local
         --  termination.

         if Current.Termination = Local_Termination
              and then not Storage_Properties.Allow_Local_Term
         then
            Message ("partition", Quote (Current.Name),
                     "cannot locally terminate while using",
                     Quote (Location.Major), "storage support");
            Success := False;
            return;
         end if;

         --  Some storage supports need a PCS tasking profile

         if Storage_Properties.Need_Tasking
           and then Current.Tasking /= PCS_Tasking
         then
            Current.Tasking := PCS_Tasking;
            Message ("PCS tasking forced for", Quote (Current.Name),
                     "to use", Quote (Location.Major), "storage support");
         end if;
      end Detect_Storage_Constraint_Violation;

      Uname     : Name_Id;
      Unit      : Unit_Id;
      Conf_Unit : Conf_Unit_Id;
      Part      : Partition_Id;
      Location  : Location_Id;

   --  Start of processing for Analyze_Required_Storage_Supports

   begin
      --  Look up storage supports needed for shared passive stub
      --  packages configured on other partitions.

      for S in Current.First_Stub .. Current.Last_Stub loop
         Uname := Stubs.Table (S);
         Unit  := ALIs.Table (Get_ALI_Id (Uname)).Last_Unit;

         if Units.Table (Unit).Shared_Passive then
            Part     := Get_Partition_Id (Uname);
            Location := Partitions.Table (Part).Storage_Loc;

            if Location = No_Location_Id then
               Location := Default_Data_Location;
            end if;
            Detect_Storage_Constraint_Violation (Location);
            Add_Required_Storage
              (Current.First_Required_Storage,
               Current.Last_Required_Storage,
               Location,
               Unit,
               Owner => False);
         end if;
      end loop;

      --  Look up storage support needed for shared passive packages configured
      --  on this partition.

      Conf_Unit := Current.First_Unit;
      while Conf_Unit /= No_Conf_Unit_Id loop
         Unit := Conf_Units.Table (Conf_Unit).My_Unit;
         if Units.Table (Unit).Shared_Passive then
            Location := Current.Storage_Loc;

            if Location = No_Location_Id then
               Location := Default_Data_Location;
            end if;
            Detect_Storage_Constraint_Violation (Location);
            Add_Required_Storage
              (Current.First_Required_Storage,
               Current.Last_Required_Storage,
               Location,
               Unit,
               Owner => True);
         end if;

         Conf_Unit := Conf_Units.Table (Conf_Unit).Next_Unit;
      end loop;
   end Analyze_Required_Storage_Supports;

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
      Current.Partition_Dir := Dir (Part_Dir_Name, Current.Partition_Dir);

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
      if Current.Light_PCS = BFalse then
         Current.Tasking := PCS_Tasking;
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

      if Current.First_Env_Var = No_Env_Var_Id then
         Current.First_Env_Var := Default.First_Env_Var;
      else
         Env_Vars.Table (Current.Last_Env_Var).Next_Env_Var :=
           Default.First_Env_Var;
      end if;

      if Default.Last_Env_Var /= No_Env_Var_Id then
         Current.Last_Env_Var := Default.Last_Env_Var;
      end if;

      if Current.Reconnection = No_Reconnection then
         Current.Reconnection := Default.Reconnection;
      end if;

      if Current.Storage_Loc = No_Location_Id then
         Current.Storage_Loc := Default.Storage_Loc;
      end if;

      if Current.First_Required_Storage = No_Required_Storage_Id then
         Current.First_Required_Storage := Default.First_Required_Storage;
         Current.Last_Required_Storage  := Default.Last_Required_Storage;
      end if;

      if Current.Task_Pool = No_Task_Pool then
         Current.Task_Pool := Default.Task_Pool;
      end if;

      if Current.Termination = No_Termination then
         Current.Termination := Default.Termination;
      end if;

      if Current.ORB_Tasking_Policy = No_ORB_Tasking_Policy then
         Current.ORB_Tasking_Policy := Default.ORB_Tasking_Policy;
      end if;
   end Apply_Default_Partition_Attributes;

   -------------------------------
   -- Assign_ORB_Tasking_Policy --
   -------------------------------

   procedure Assign_ORB_Tasking_Policy (Partition : Partition_Id) is
      Current : Partition_Type renames Partitions.Table (Partition);

   begin
      if Current.Tasking = PCS_Tasking then

         --  If ORB tasking policy isn't assigned yet, use default

         if Current.ORB_Tasking_Policy = No_ORB_Tasking_Policy then
            Current.ORB_Tasking_Policy := Default_ORB_Tasking_Policy;
         end if;

         if Debug_Mode then
            Message ("partition", Current.Name, "has ORB tasking policy ",
                     ORB_Tasking_Policy_Img (Current.ORB_Tasking_Policy));
         end if;
      else

         --  Write a warning message if ORB tasking policy is assigned
         --  when partition has no ORB tasking.

         if Current.ORB_Tasking_Policy /= No_ORB_Tasking_Policy then
            Message ("Attribute ORB_Tasking_Policy has no effect when" &
                     "partition has no ORB tasking");
         end if;
      end if;

      --  Write a warning message if Task_Pool attribute is set
      --  when another than Thread_Pool ORB tasking poliy is
      --  selected.

      if Current.ORB_Tasking_Policy /= Thread_Pool
        and then Current.Task_Pool /= No_Task_Pool
      then
         Message ("Attribute Task_Pool has no effect when ",
                  ORB_Tasking_Policy_Img (Current.ORB_Tasking_Policy),
                  "ORB tasking policy is set");
      end if;

   end Assign_ORB_Tasking_Policy;

   ----------------------------------
   -- Assign_Partition_Termination --
   ----------------------------------

   procedure Assign_Partition_Termination (Partition : Partition_Id) is
      Current : Partition_Type renames Partitions.Table (Partition);

   begin
      if Debug_Mode then
         Message ("partition", Current.Name, "has tasking ",
                  Tasking_Img (Current.Tasking));
      end if;

      if Current.Termination = No_Termination then
         if Current.Tasking /= PCS_Tasking then
            Current.Termination := Local_Termination;

            if Debug_Mode then
               Message ("local termination forced for", Current.Name);
            end if;
         else
            Current.Termination := Global_Termination;
         end if;
      end if;

   end Assign_Partition_Termination;

   -------------------------
   -- Assign_Unit_Tasking --
   -------------------------

   procedure Assign_Unit_Tasking (ALI : ALI_Id) is
      T : Tasking_Type := Get_Tasking (ALI);

   begin
      for J in ALIs.Table (ALI).First_Unit .. ALIs.Table (ALI).Last_Unit loop

         --  No need to investigate further when the unit is a RCI unit or has
         --  RACW objects.

         if Units.Table (J).RCI or else Units.Table (J).Has_RACW then
            T := PCS_Tasking;
            exit;
         end if;
      end loop;

      if T = Unknown_Tasking then
         T := No_Tasking;
      end if;
      Set_Tasking (ALI, T);

      if Debug_Mode then
         Message ("unit", ALIs.Table (ALI).Uname,
                  "has tasking ", Tasking_Img (Get_Tasking (ALI)));
      end if;
   end Assign_Unit_Tasking;

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
      if A = No_ALI_Id or else ALIs.Table (A).Main_Program = No_Main then
         Message ("", Quote (N), "is not a main program");
         Success := False;
      end if;
   end Detect_Incorrect_Main_Subprogram;

   -------------------------------
   -- Detect_Malformed_Location --
   -------------------------------

   procedure Detect_Malformed_Location
     (Location : Location_Id;
      Success  : in out Boolean)
   is
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
   end Detect_Malformed_Location;

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
      A : constant ALI_Id         := Get_ALI_Id (N);

   begin
      --  If no ALI Id is associated with the unit name of the configured unit,
      --  then it is not an Ada unit.

      if A = No_ALI_Id then
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
      U : constant Unit_Id        := ALIs.Table (ALI).Last_Unit;
      N : constant Unit_Name_Type := ALIs.Table (ALI).Uname;

   begin
      if (Units.Table (U).RCI or else Units.Table (U).Shared_Passive)
        and then not Units.Table (U).Is_Generic
        and then Get_Partition_Id (N) = No_Partition_Id
      then
         if Units.Table (U).RCI then
            Message ("RCI Ada unit", Quote (N),
                     "has not been assigned to a partition");
         else
            Message ("Shared passive Ada unit", Quote (N),
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
      F  : File_Name_Type;
      L  : Stub_Id;

   begin
      Partitions.Table (Partition).First_Stub := Stubs.Last + 1;
      Partitions.Table (Partition).Last_Stub  := Stubs.Last;

      --  Reset Stamp_Checked flag

      for J in ALIs.First .. ALIs.Last loop
         ALIs.Table (J).Stamp_Checked := False;
      end loop;

      --  Append all the dependencies on units which are assigned to
      --  this partition.

      CU := Partitions.Table (Partition).First_Unit;
      while CU /= No_Conf_Unit_Id loop
         A := Conf_Units.Table (CU).My_ALI;

         --  Mark unit as already checked now

         ALIs.Table (A).Stamp_Checked := True;

         F := Dir (Monolithic_Obj_Dir, ALIs.Table (A).Afile);

         --  Update most recent stamp of this partition

         Update_Most_Recent_Stamp (Partition, F);

         for J in
           ALIs.Table (A).First_Unit .. ALIs.Table (A).Last_Unit
         loop
            for K in
              Units.Table (J).First_With .. Units.Table (J).Last_With
            loop
               if Present (Withs.Table (K).Afile) then
                  Files.Append (Withs.Table (K).Afile);
               end if;
            end loop;
         end loop;

         CU := Conf_Units.Table (CU).Next_Unit;
      end loop;

      --  Explore the withed units. Any Shared Passive or RCI unit that is
      --  seen from this point on is a stub unit (unlike conf units checked
      --  in the above loop).

      <<Next_With>>
      while Files.First <= Files.Last loop
         F := Files.Table (Files.Last);
         Files.Decrement_Last;
         A := Get_ALI_Id (F);

         --  Some units may not have ALI files like generic units

         if A = No_ALI_Id then
            if Debug_Mode then
               Write_Str ("no ALI info found for ");
               Write_Name (F);
               Write_Eol;
            end if;
            goto Next_With;
         end if;

         if ALIs.Table (A).Stamp_Checked then
            if Debug_Mode then
               Message
                 ("stamps already checked for", ALIs.Table (A).Uname);
            end if;
            goto Next_With;
         end if;

         --  Mark unit as checked

         ALIs.Table (A).Stamp_Checked := True;

         F := Dir (Monolithic_Obj_Dir, F);
         if Debug_Mode then
            Message ("check stamp", F);
         end if;

         --  Update most recent stamp of this partition

         Update_Most_Recent_Stamp (Partition, F);

         --  Check for stub

         U := ALIs.Table (A).Last_Unit;
         if not Units.Table (U).Is_Generic
           and then (Units.Table (U).RCI
                       or else Units.Table (U).Shared_Passive)
         then
            --  If RCI or SP unit is encountered now, mark it as a stub and do
            --  not explore its dependencies any further.

            Stubs.Increment_Last;
            L := Stubs.Last;
            Stubs.Table (L) := ALIs.Table (A).Uname;

            if Partitions.Table (Partition).Last_Stub = No_Stub_Id then
               Partitions.Table (Partition).First_Stub := L;
            end if;
            Partitions.Table (Partition).Last_Stub := L;

            if Verbose_Mode then
               Message ("append stub", ALIs.Table (A).Uname);
            end if;

         else
            --  Mark this unit as explored and append its dependencies

            if Debug_Mode then
               Message ("append dependencies of", ALIs.Table (A).Uname);
            end if;

            for J in
              ALIs.Table (A).First_Unit .. ALIs.Table (A).Last_Unit
            loop
               for K in
                 Units.Table (J).First_With .. Units.Table (J).Last_With
               loop
                  if Present (Withs.Table (K).Afile) then
                     A := Get_ALI_Id (Withs.Table (K).Afile);
                     if A /= No_ALI_Id
                          and then
                        not ALIs.Table (A).Stamp_Checked
                     then
                        Files.Append (Withs.Table (K).Afile);
                     end if;
                  end if;
               end loop;
            end loop;
         end if;
      end loop;
   end Find_Stubs_And_Stamps_From_Closure;

   ------------------------------
   -- Update_Partition_Tasking --
   ------------------------------

   procedure Update_Partition_Tasking
     (ALI       : ALI_Id;
      Partition : Partition_Id)
   is
      A : ALI_Id;
      F : File_Name_Type;
      N : Unit_Name_Type;
      U : Unit_Id;
      T : Tasking_Type renames Partitions.Table (Partition).Tasking;

   begin
      if Debug_Mode then
         Message ("update partition", Partitions.Table (Partition).Name,
                  "tasking", Tasking_Img (T));
      end if;

      Files.Append (ALIs.Table (ALI).Afile);
      while Files.First <= Files.Last loop
         F := Files.Table (Files.Last);
         Files.Decrement_Last;
         A := Get_ALI_Id (F);

         if Debug_Mode then
            Message ("pop unit", ALIs.Table (A).Uname);
         end if;

         --  Update partition tasking to unit tasking

         if T = PCS_Tasking then
            null;

         elsif T = User_Tasking then
            if ALIs.Table (A).Tasking = PCS_Tasking then
               if Debug_Mode then
                  Message ("update tasking from", Tasking_Img (T),
                           "to", Tasking_Img (ALIs.Table (A).Tasking));
               end if;

               T := ALIs.Table (A).Tasking;
            end if;

         else
            if T /= ALIs.Table (A).Tasking then
               if Debug_Mode then
                  Message ("update tasking from ", Tasking_Img (T),
                           " to ", Tasking_Img (ALIs.Table (A).Tasking));
               end if;

               T := ALIs.Table (A).Tasking;
            end if;
         end if;

         --  When needed, push into the collocated units stack the withed units

         for J in
           ALIs.Table (A).First_Unit .. ALIs.Table (A).Last_Unit
         loop
            for K in
              Units.Table (J).First_With .. Units.Table (J).Last_With
            loop
               F := Withs.Table (K).Afile;
               if Present (F) then
                  A := Get_ALI_Id (F);

                  --  Discard predefined units since they do not bring
                  --  tasking with them.

                  if Is_Predefined_File (F) then
                     null;

                  elsif A /= No_ALI_Id then
                     U := ALIs.Table (A).Last_Unit;
                     N := ALIs.Table (A).Uname;

                     --  Discard unit that has already been assigned
                     --  to this partition.

                     if Get_Partition_Id (N) = Partition then
                        null;

                     --  Discard this unit as it may not be collocated

                     elsif Units.Table (U).RCI
                       or else Units.Table (U).Shared_Passive
                     then
                        null;

                     --  Continue investigation later on

                     else
                        if Debug_Mode then
                           Message
                             ("push unit", N, "in partition",
                              Partitions.Table (Partition).Name);
                        end if;

                        Set_Partition_Id (N, Partition);
                        Files.Append (F);
                     end if;
                  end if;
               end if;
            end loop;
         end loop;
      end loop;
   end Update_Partition_Tasking;

end XE_Sem;
