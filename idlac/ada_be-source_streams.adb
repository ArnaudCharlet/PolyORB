------------------------------------------------------------------------------
--                                                                          --
--                          ADABROKER COMPONENTS                            --
--                                                                          --
--                A D A _ B E . S O U R C E _ S T R E A M S                 --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--          Copyright (C) 1999-2000 ENST Paris University, France.          --
--                                                                          --
-- AdaBroker is free software; you  can  redistribute  it and/or modify it  --
-- under terms of the  GNU General Public License as published by the  Free --
-- Software Foundation;  either version 2,  or (at your option)  any  later --
-- version. AdaBroker  is distributed  in the hope that it will be  useful, --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License  for more details.  You should have received  a copy of the GNU  --
-- General Public License distributed with AdaBroker; see file COPYING. If  --
-- not, write to the Free Software Foundation, 59 Temple Place - Suite 330, --
-- Boston, MA 02111-1307, USA.                                              --
--                                                                          --
--             AdaBroker is maintained by ENST Paris University.            --
--                     (email: broker@inf.enst.fr)                          --
--                                                                          --
------------------------------------------------------------------------------

with Ada.Characters.Handling; use Ada.Characters.Handling;
with Ada.Characters.Latin_1; use Ada.Characters.Latin_1;
with Ada.Unchecked_Deallocation;
with Ada.Text_IO;

with Ada_Be.Debug;
pragma Elaborate (Ada_Be.Debug);

package body Ada_Be.Source_Streams is

   Flag : constant Natural := Ada_Be.Debug.Is_Active ("ada_be.source_streams");
   procedure O is new Ada_Be.Debug.Output (Flag);

   procedure Set_Empty (Unit : in out Compilation_Unit) is
   begin
      Unit.Empty := True;
   end Set_Empty;

   procedure Put
     (Unit : in out Compilation_Unit;
      Text : String)
   is
      Indent_String : constant String
        (1 .. Unit.Indent_Level * Indent_Size)
        := (others => ' ');
   begin
      Unit.Empty := False;
      if Unit.At_BOL then
         Append (Unit.Library_Item, Indent_String);
         Unit.At_BOL := False;
      end if;
      Append (Unit.Library_Item, Text);
   end Put;

   procedure Put_Line
     (Unit : in out Compilation_Unit;
      Line : String) is
   begin
      Put (Unit, Line);
      New_Line (Unit);
   end Put_Line;

   procedure New_Line (Unit : in out Compilation_Unit) is
   begin
      Append (Unit.Library_Item, LF);
      Unit.At_BOL := True;
   end New_Line;

   procedure Inc_Indent (Unit : in out Compilation_Unit) is
   begin
      Unit.Indent_Level := Unit.Indent_Level + 1;
   end Inc_Indent;

   procedure Dec_Indent (Unit : in out Compilation_Unit) is
   begin
      Unit.Indent_Level := Unit.Indent_Level - 1;
   end Dec_Indent;

   function Is_Ancestor
     (U1 : String;
      U2 : String)
     return Boolean;
   --  True if library unit U1 is an ancestor of U2.

   function Is_Ancestor
     (U1 : String;
      U2 : String)
     return Boolean
   is
      use Ada.Characters.Handling;

      LU1 : constant String
        := To_Lower (U1) & ".";
      LU2 : constant String
        := To_Lower (U2);
   begin
      return True
        and then LU1'Length <= LU2'Length
        and then LU1 = LU2
        (LU2'First .. LU2'First + LU1'Length - 1);
   end Is_Ancestor;

   procedure Add_With
     (Unit   : in out Compilation_Unit;
      Dep    : String;
      Use_It : Boolean := False;
      Elab_Control : Elab_Control_Pragma := None)
   is
      Dep_Node : Dependency := Unit.Context_Clause;
      LU_Name : constant String
        := Unit.Library_Unit_Name.all;
   begin
      if False
        or else Dep = LU_Name
        or else Is_Ancestor (Dep, LU_Name)
      then
         --  No need to with oneself or one's ancestor.
         return;
      end if;

      pragma Debug (O ("Adding depend of " & LU_Name
                       & " (" & Unit.Kind'Img & ")"
                       & " upon " & Dep));

      if True
        and then Unit.Kind = Unit_Spec
        and then Is_Ancestor (LU_Name, Dep)
      then
         --  All hope abandon he who trieth to make a unit
         --  spec depend upon its child.
         pragma Debug (O ("The declaration of " & LU_Name
                          & " cannot depend on " & Dep));

         raise Program_Error;
      end if;

      while Dep_Node /= null and then Dep_Node.Library_Unit.all /= Dep loop
         Dep_Node := Dep_Node.Next;
      end loop;

      if Dep_Node = null then
         Dep_Node := new Dependency_Node'
           (Library_Unit => new String'(Dep),
            Use_It => Use_It,
            Elab_Control => Elab_Control,
            Next => Unit.Context_Clause);
         Unit.Context_Clause := Dep_Node;
      else
         Dep_Node.Use_It := Dep_Node.Use_It or else Use_It;
         if Elab_Control = Elaborate_All
           or else Dep_Node.Elab_Control = Elaborate_All then
            Dep_Node.Elab_Control := Elaborate_All;
         elsif Elab_Control = Elaborate
           or else Dep_Node.Elab_Control = Elaborate then
            Dep_Node.Elab_Control := Elaborate;
         else
            Dep_Node.Elab_Control := None;
         end if;
      end if;

   end Add_With;

   function New_Package
     (Name : String;
      Kind : Unit_Kind)
     return Compilation_Unit
   is
      The_Package : Compilation_Unit;
   begin
      The_Package.Library_Unit_Name := new String'(Name);
      The_Package.Kind := Kind;

      return The_Package;
   end New_Package;

   procedure Generate
     (Unit : Compilation_Unit;
      Is_Generic_Instanciation : Boolean := False;
      To_Stdout : Boolean := False)
   is
      function Ada_File_Name
        (Full_Name : String;
         Part      : Unit_Kind := Unit_Spec)
        return String;

      function Ada_File_Name
        (Full_Name : String;
         Part      : Unit_Kind := Unit_Spec)
        return String
      is
         Extension : constant array (Unit_Kind) of Character
           := (Unit_Spec => 's',
               Unit_Body => 'b');
         Result : String := Full_Name & ".ad?";
      begin
         for I in Result'First .. Result'Last - 4 loop
            if Result (I) = '.' then
               Result (I) := '-';
            else
               Result (I) := To_Lower (Result (I));
            end if;
         end loop;

         Result (Result'Last) := Extension (Part);
         return Result;
      end Ada_File_Name;

      use Ada.Text_IO;

      procedure Emit_Standard_Header
        (File        : in File_Type;
         User_Edited : in Boolean := False);

      procedure Emit_Source_Code
        (File : in File_Type);

      procedure Emit_Standard_Header
        (File        : in File_Type;
         User_Edited : in Boolean := False)
      is
      begin
         Put_Line (File, "----------------------------------------------");
         Put_Line (File, "--  This file has been generated automatically");
         Put_Line (File, "--  by AdaBroker (http://adabroker.eu.org/)");
         if not User_Edited then
            Put_Line (File, "--");
            Put_Line (File, "--  Do NOT hand-modify this file, as your");
            Put_Line (File, "--  changes will be lost when you re-run the");
            Put_Line (File, "--  IDL to Ada compiler.");
         end if;
         Put_Line (File, "----------------------------------------------");
         New_Line (File);
      end Emit_Standard_Header;

      procedure Emit_Source_Code
        (File : in File_Type)
      is
         Dep_Node : Dependency := Unit.Context_Clause;
      begin
         while Dep_Node /= null loop
            Put (File, "with " & Dep_Node.Library_Unit.all & ";");
            if Dep_Node.Use_It then
               Put_Line (File, " use " & Dep_Node.Library_Unit.all & ";");
            else
               New_Line (File);
            end if;
            case Dep_Node.Elab_Control is
               when Elaborate_All =>
                  Put_Line (File, "pragma Elaborate_All ("
                            & Dep_Node.Library_Unit.all & ");");
               when Elaborate =>
                  Put_Line (File, "pragma Elaborate ("
                            & Dep_Node.Library_Unit.all & ");");
               when None =>
                  null;
            end case;
            Dep_Node := Dep_Node.Next;
         end loop;

         if Unit.Context_Clause /= null then
            New_Line (File);
         end if;

         Put (File, "package ");
         if Unit.Kind = Unit_Body then
            Put (File, "body ");
         end if;
         Put_Line (File, Unit.Library_Unit_Name.all & " is");
         Put (File, To_String (Unit.Library_Item));

         if not Is_Generic_Instanciation then
            Put_Line (File, "end " & Unit.Library_Unit_Name.all & ";");
         end if;
      end Emit_Source_Code;

   begin
      if Unit.Empty then
         return;
      end if;

      if To_Stdout then
         Emit_Standard_Header (Current_Output);
         Emit_Source_Code (Current_Output);
      else
         declare
            File_Name : String
              := Ada_File_Name (Unit.Library_Unit_Name.all, Unit.Kind);
            File : File_Type;
         begin
            Create (File, Out_File, File_Name);
            Emit_Standard_Header (File);
            Emit_Source_Code (File);
            Close (File);
         end;
      end if;
   end Generate;

   procedure Free is
      new Ada.Unchecked_Deallocation (Dependency_Node, Dependency);

   procedure Finalize (Object : in out Dependency_Node);

   procedure Finalize (Object : in out Dependency_Node) is
   begin
      if Object.Next /= null then
         Finalize (Object.Next.all);
         Free (Object.Next);
      end if;
      Free (Object.Library_Unit);
   end Finalize;

   procedure Finalize (Object : in out Compilation_Unit) is
   begin
      if Object.Context_Clause /= null then
         Finalize (Object.Context_Clause.all);
         Free (Object.Context_Clause);
      end if;
   end Finalize;

end Ada_Be.Source_Streams;
